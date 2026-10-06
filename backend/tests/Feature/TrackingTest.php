<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TrackingTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private function order(): Order
    {
        return User::where('email', 'cliente@demo.co')->first()->orders()->first();
    }

    private function as(string $email): User
    {
        $user = User::where('email', $email)->first();
        Sanctum::actingAs($user);

        return $user;
    }

    private function ping(Order $order, array $overrides = [])
    {
        return $this->postJson("/api/driver/orders/{$order->id}/location", [
            'latitude' => 5.6950, 'longitude' => -76.6590, 'speed_mps' => 6, ...$overrides,
        ]);
    }

    public function test_driver_reports_location_and_customer_sees_it_with_eta(): void
    {
        $order = $this->order();
        $this->as('repartidor@demo.co');

        $this->ping($order)->assertCreated()->assertJsonPath('live', true);

        $this->as('cliente@demo.co');
        $this->getJson("/api/orders/{$order->id}/location")
            ->assertOk()
            ->assertJsonPath('live', true)
            ->assertJsonPath('latitude', 5.695)
            ->assertJsonStructure(['distance_m', 'eta_min', 'recorded_at']);
    }

    public function test_latest_location_wins(): void
    {
        $order = $this->order();
        $this->as('repartidor@demo.co');
        $this->ping($order, ['latitude' => 5.1])->assertCreated();
        $this->ping($order, ['latitude' => 5.2])->assertCreated();

        $this->as('cliente@demo.co');
        $this->getJson("/api/orders/{$order->id}/location")->assertJsonPath('latitude', 5.2);
    }

    public function test_stale_location_is_not_live(): void
    {
        $order = $this->order();
        $this->as('repartidor@demo.co');
        $this->ping($order)->assertCreated();
        $order->courierLocations()->update(['recorded_at' => now()->subMinutes(5)]);

        $this->as('cliente@demo.co');
        $this->getJson("/api/orders/{$order->id}/location")->assertJsonPath('live', false);
    }

    public function test_no_location_returns_empty_snapshot(): void
    {
        $order = $this->order();
        $this->as('cliente@demo.co');

        $this->getJson("/api/orders/{$order->id}/location")
            ->assertOk()->assertJsonPath('live', false)->assertJsonPath('latitude', null);
    }

    public function test_location_is_hidden_once_not_in_transit(): void
    {
        $order = $this->order();
        $this->as('repartidor@demo.co');
        $this->ping($order)->assertCreated();
        $order->update(['status' => OrderStatus::Entregado]);

        $this->as('cliente@demo.co');
        $this->getJson("/api/orders/{$order->id}/location")->assertJsonPath('latitude', null);
        $this->as('repartidor@demo.co');
        $this->ping($order)->assertUnprocessable();
    }

    public function test_only_assigned_driver_can_report(): void
    {
        $order = $this->order();
        $other = User::factory()->create();
        $other->role = \App\Enums\UserRole::Repartidor;
        $other->save();
        Sanctum::actingAs($other);

        $this->ping($order)->assertForbidden();

        $this->as('cliente@demo.co');
        $this->ping($order)->assertForbidden();
    }

    public function test_invalid_coordinates_are_rejected(): void
    {
        $order = $this->order();
        $this->as('repartidor@demo.co');

        $this->ping($order, ['latitude' => 120])->assertUnprocessable();
    }

    public function test_other_customers_cannot_see_the_location(): void
    {
        $order = $this->order();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson("/api/orders/{$order->id}/location")->assertForbidden();
    }
}
