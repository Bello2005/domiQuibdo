<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RestaurantOwnerTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private function owner(): User
    {
        $owner = User::where('email', 'restaurante@demo.co')->first();
        Sanctum::actingAs($owner);

        return $owner;
    }

    private function ownRestaurant(): Restaurant
    {
        return Restaurant::where('name', 'Pollos Nacho')->first();
    }

    private function otherRestaurant(): Restaurant
    {
        return Restaurant::where('name', '!=', 'Pollos Nacho')->first();
    }

    public function test_non_restaurant_roles_are_forbidden(): void
    {
        Sanctum::actingAs(User::where('email', 'cliente@demo.co')->first());

        $this->getJson('/api/restaurant/orders')->assertForbidden();
        $this->getJson('/api/restaurant/restaurants')->assertForbidden();
    }

    public function test_owner_only_sees_orders_of_own_restaurant(): void
    {
        $this->owner();

        $this->getJson('/api/restaurant/orders')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.restaurant.id', $this->ownRestaurant()->id);

        $this->getJson('/api/restaurant/restaurants')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.id', $this->ownRestaurant()->id);
    }

    public function test_owner_can_advance_and_cancel_own_order_but_not_deliver(): void
    {
        $this->owner();
        $order = Order::first();
        $order->update(['status' => OrderStatus::Pendiente]);

        $this->postJson("/api/restaurant/orders/{$order->id}/advance")->assertOk()->assertJsonPath('status', 'confirmado');
        $this->postJson("/api/restaurant/orders/{$order->id}/advance")->assertOk()->assertJsonPath('status', 'preparando');
        $this->postJson("/api/restaurant/orders/{$order->id}/advance")->assertOk()->assertJsonPath('status', 'en_camino');
        $this->postJson("/api/restaurant/orders/{$order->id}/advance")->assertUnprocessable();
        $this->postJson("/api/restaurant/orders/{$order->id}/cancel")->assertUnprocessable();

        $order->update(['status' => OrderStatus::Preparando]);
        $this->postJson("/api/restaurant/orders/{$order->id}/cancel")->assertOk()->assertJsonPath('status', 'cancelado');
    }

    public function test_owner_cannot_touch_orders_of_another_restaurant(): void
    {
        $this->owner();
        $order = Order::first();
        $order->update(['restaurant_id' => $this->otherRestaurant()->id, 'status' => OrderStatus::Pendiente]);

        $this->postJson("/api/restaurant/orders/{$order->id}/advance")->assertForbidden();
        $this->postJson("/api/restaurant/orders/{$order->id}/cancel")->assertForbidden();
        $this->assertSame(OrderStatus::Pendiente, $order->fresh()->status);
    }

    public function test_owner_manages_menu_of_own_restaurant_only(): void
    {
        $this->owner();
        $own = $this->ownRestaurant();

        $id = $this->postJson("/api/restaurant/restaurants/{$own->id}/menu-items", ['name' => 'Sancocho', 'price' => 15000])
            ->assertCreated()->json('id');
        $this->putJson("/api/restaurant/menu-items/{$id}", ['name' => 'Sancocho', 'price' => 16000, 'is_available' => false])
            ->assertOk()->assertJsonPath('is_available', false);
        $this->deleteJson("/api/restaurant/menu-items/{$id}")->assertNoContent();

        $other = $this->otherRestaurant();
        $foreign = $other->menuItems()->first();
        $this->postJson("/api/restaurant/restaurants/{$other->id}/menu-items", ['name' => 'X', 'price' => 1])->assertForbidden();
        $this->putJson("/api/restaurant/menu-items/{$foreign->id}", ['name' => 'X', 'price' => 1])->assertForbidden();
        $this->deleteJson("/api/restaurant/menu-items/{$foreign->id}")->assertForbidden();
    }

    public function test_owner_can_close_own_restaurant_only(): void
    {
        $this->owner();

        $this->putJson("/api/restaurant/restaurants/{$this->ownRestaurant()->id}", ['is_active' => false])
            ->assertOk()->assertJsonPath('is_active', false);
        $this->putJson("/api/restaurant/restaurants/{$this->otherRestaurant()->id}", ['is_active' => false])
            ->assertForbidden();
    }

    public function test_owner_does_not_see_the_verification_code(): void
    {
        $this->owner();

        $this->getJson('/api/restaurant/orders')->assertJsonMissingPath('0.verification_code');
    }
}
