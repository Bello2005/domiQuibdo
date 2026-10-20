<?php

namespace Tests\Feature;

use App\Models\Restaurant;
use App\Models\RestaurantPhoto;
use App\Models\User;
use App\Services\RestaurantPhotoService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RestaurantPhotoTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    private function actingAsOwner(): Restaurant
    {
        Sanctum::actingAs(User::where('email', 'restaurante@demo.co')->first());

        return Restaurant::where('name', 'Pollos Nacho')->first();
    }

    private function upload(string $url, int $width = 2400, int $height = 1800): TestResponse
    {
        return $this->post($url, ['photo' => UploadedFile::fake()->image('foto.jpg', $width, $height)], ['Accept' => 'application/json']);
    }

    public function test_owner_uploads_photo_that_becomes_the_cover_in_two_sizes(): void
    {
        $restaurant = $this->actingAsOwner();

        $response = $this->upload("/api/restaurant/restaurants/{$restaurant->id}/photos")->assertCreated();

        $photo = RestaurantPhoto::findOrFail($response->json('id'));
        Storage::disk('public')->assertExists([$photo->path, $photo->thumb_path]);
        $this->assertSame(1600, getimagesizefromstring(Storage::disk('public')->get($photo->path))[0]);
        $this->assertSame(480, getimagesizefromstring(Storage::disk('public')->get($photo->thumb_path))[0]);

        $this->getJson("/api/restaurants/{$restaurant->id}")
            ->assertOk()
            ->assertJsonPath('cover_image_url', $photo->url())
            ->assertJsonPath('cover_thumb_url', $photo->thumbUrl())
            ->assertJsonCount(1, 'photos');
    }

    public function test_owner_cannot_touch_photos_of_another_restaurant_but_admin_can(): void
    {
        $this->actingAsOwner();
        $other = Restaurant::where('name', '!=', 'Pollos Nacho')->first();

        $this->upload("/api/restaurant/restaurants/{$other->id}/photos")->assertForbidden();

        Sanctum::actingAs(User::where('email', 'admin@demo.co')->first());
        $this->upload("/api/admin/restaurants/{$other->id}/photos")->assertCreated();
    }

    public function test_reorder_changes_the_cover_and_requires_every_photo(): void
    {
        $restaurant = $this->actingAsOwner();
        $first = $this->upload("/api/restaurant/restaurants/{$restaurant->id}/photos")->json('id');
        $second = $this->upload("/api/restaurant/restaurants/{$restaurant->id}/photos")->json('id');

        $this->putJson("/api/restaurant/restaurants/{$restaurant->id}/photos/order", ['ids' => [$second]])
            ->assertUnprocessable();

        $this->putJson("/api/restaurant/restaurants/{$restaurant->id}/photos/order", ['ids' => [$second, $first]])
            ->assertOk()
            ->assertJsonPath('0.id', $second);

        $this->getJson("/api/restaurants/{$restaurant->id}")
            ->assertJsonPath('cover_image_url', RestaurantPhoto::find($second)->url());
    }

    public function test_deleting_a_photo_removes_its_files(): void
    {
        $restaurant = $this->actingAsOwner();
        $photo = RestaurantPhoto::findOrFail(
            $this->upload("/api/restaurant/restaurants/{$restaurant->id}/photos")->json('id')
        );

        $this->deleteJson("/api/restaurant/photos/{$photo->id}")->assertNoContent();

        Storage::disk('public')->assertMissing([$photo->path, $photo->thumb_path]);
        $this->assertModelMissing($photo);
    }

    public function test_upload_rejects_non_images_and_respects_the_photo_limit(): void
    {
        $restaurant = $this->actingAsOwner();

        $this->post(
            "/api/restaurant/restaurants/{$restaurant->id}/photos",
            ['photo' => UploadedFile::fake()->create('menu.pdf', 100, 'application/pdf')],
            ['Accept' => 'application/json'],
        )->assertUnprocessable()->assertJsonValidationErrors('photo');

        for ($i = 0; $i < RestaurantPhotoService::MAX_PHOTOS; $i++) {
            $restaurant->photos()->create(['path' => "x/{$i}.webp", 'thumb_path' => "x/{$i}-thumb.webp", 'position' => $i]);
        }
        $this->upload("/api/restaurant/restaurants/{$restaurant->id}/photos")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('photo');
    }

    public function test_menu_item_photo_is_replaced_and_removed_with_its_files(): void
    {
        $restaurant = $this->actingAsOwner();
        $item = $restaurant->menuItems()->first();

        $this->upload("/api/restaurant/menu-items/{$item->id}/photo", 800, 800)->assertOk();
        $old = $item->fresh();

        $this->upload("/api/restaurant/menu-items/{$item->id}/photo", 800, 800)
            ->assertOk()
            ->assertJsonPath('image_url', Storage::disk('public')->url($item->fresh()->image_path));
        Storage::disk('public')->assertMissing([$old->image_path, $old->image_thumb_path]);

        $current = $item->fresh();
        $this->deleteJson("/api/restaurant/menu-items/{$item->id}/photo")
            ->assertOk()
            ->assertJsonPath('image_url', null);
        Storage::disk('public')->assertMissing([$current->image_path, $current->image_thumb_path]);
    }
}
