<?php

namespace Tests\Feature;

use App\Models\MenuItem;
use App\Models\Order;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OrderTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private function cliente(): User
    {
        return User::where('email', 'cliente@demo.co')->first();
    }

    private function menuOf(string $restaurant): MenuItem
    {
        return Restaurant::where('name', $restaurant)->first()->menuItems()->first();
    }

    public function test_total_is_computed_on_server_ignoring_client_prices(): void
    {
        $cliente = $this->cliente();
        Sanctum::actingAs($cliente);
        $item = $this->menuOf('Pollos Nacho');

        $response = $this->postJson('/api/orders', [
            'address_id' => $cliente->addresses()->value('id'),
            'items' => [['menu_item_id' => $item->id, 'quantity' => 2, 'unit_price' => 1]],
            'total' => 1,
            'payment_method' => 'efectivo',
        ])->assertCreated();

        $fee = $response->json('delivery_fee');
        $this->assertEquals($item->price * 2 + $fee, $response->json('total'));
        $this->assertGreaterThanOrEqual(3000, $fee);
        $this->assertMatchesRegularExpression('/^\d{4}$/', $response->json('verification_code'));
        $this->assertSame('pendiente', $response->json('status'));
        $this->assertSame(6, Order::find($response->json('id'))->routePoints()->count());
    }

    public function test_items_from_different_restaurants_are_rejected(): void
    {
        $cliente = $this->cliente();
        Sanctum::actingAs($cliente);

        $this->postJson('/api/orders', [
            'address_id' => $cliente->addresses()->value('id'),
            'items' => [
                ['menu_item_id' => $this->menuOf('Pollos Nacho')->id, 'quantity' => 1],
                ['menu_item_id' => $this->menuOf('Nativhos')->id, 'quantity' => 1],
            ],
            'payment_method' => 'efectivo',
        ])->assertUnprocessable()->assertJsonValidationErrors('items');
    }

    public function test_cannot_order_to_another_users_address(): void
    {
        $otro = User::factory()->create();
        Sanctum::actingAs($otro);

        $this->postJson('/api/orders', [
            'address_id' => $this->cliente()->addresses()->value('id'),
            'items' => [['menu_item_id' => $this->menuOf('Pollos Nacho')->id, 'quantity' => 1]],
            'payment_method' => 'efectivo',
        ])->assertUnprocessable()->assertJsonValidationErrors('address_id');
    }

    public function test_repartidor_cannot_place_orders(): void
    {
        Sanctum::actingAs(User::where('email', 'repartidor@demo.co')->first());

        $this->postJson('/api/orders', [
            'address_id' => 1,
            'items' => [['menu_item_id' => 1, 'quantity' => 1]],
            'payment_method' => 'efectivo',
        ])->assertForbidden();
    }

    public function test_other_client_cannot_view_order(): void
    {
        $order = $this->cliente()->orders()->first();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson("/api/orders/{$order->id}")->assertForbidden();
        $this->getJson("/api/orders/{$order->id}/route")->assertForbidden();
    }

    public function test_owner_sees_code_but_repartidor_does_not(): void
    {
        $order = $this->cliente()->orders()->first();

        Sanctum::actingAs($this->cliente());
        $this->getJson("/api/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('verification_code', $order->verification_code);

        Sanctum::actingAs(User::where('email', 'repartidor@demo.co')->first());
        $this->getJson("/api/orders/{$order->id}")
            ->assertOk()
            ->assertJsonMissingPath('verification_code')
            ->assertJsonPath('customer.name', 'Cliente Demo');
    }
}
