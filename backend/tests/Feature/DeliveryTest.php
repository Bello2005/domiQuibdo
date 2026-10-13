<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DeliveryTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    /** Pedido sembrado por DemoOrderSeeder: en camino y asignado al repartidor demo. */
    private function order(): Order
    {
        return User::where('email', 'cliente@demo.co')->first()->orders()->first();
    }

    private function actingAsDriver(): User
    {
        $driver = User::where('email', 'repartidor@demo.co')->first();
        Sanctum::actingAs($driver);

        return $driver;
    }

    /** Pone la última posición del repartidor a `$meters` metros (al norte) de la dirección de entrega. */
    private function courierNearAddress(Order $order, int $meters = 20, ?int $secondsAgo = 0): void
    {
        $address = $order->address;

        $order->courierLocations()->create([
            'user_id' => $order->repartidor_id,
            'latitude' => $address->latitude + $meters / 111_000,
            'longitude' => $address->longitude,
            'recorded_at' => now()->subSeconds($secondsAgo),
        ]);
    }

    private function wrongCode(Order $order): string
    {
        return $order->verification_code === '0000' ? '1111' : '0000';
    }

    public function test_driver_cannot_mark_delivered_without_code(): void
    {
        $order = $this->order();
        $this->actingAsDriver();

        $this->postJson("/api/driver/orders/{$order->id}/advance")->assertUnprocessable();
        $this->assertSame(OrderStatus::EnCamino, $order->fresh()->status);
    }

    public function test_wrong_code_is_rejected(): void
    {
        $order = $this->order();
        $this->actingAsDriver();
        $this->courierNearAddress($order);

        $this->postJson("/api/driver/orders/{$order->id}/deliver", ['code' => $this->wrongCode($order)])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('code');

        $this->assertSame(OrderStatus::EnCamino, $order->fresh()->status);
    }

    public function test_code_attempts_are_rate_limited(): void
    {
        $order = $this->order();
        $this->actingAsDriver();
        $this->courierNearAddress($order);

        for ($i = 0; $i < 5; $i++) {
            $this->postJson("/api/driver/orders/{$order->id}/deliver", ['code' => $this->wrongCode($order)])
                ->assertUnprocessable();
        }

        $this->postJson("/api/driver/orders/{$order->id}/deliver", ['code' => $order->verification_code])
            ->assertTooManyRequests();
    }

    public function test_correct_code_marks_order_delivered(): void
    {
        $order = $this->order();
        $driver = $this->actingAsDriver();
        $this->courierNearAddress($order);

        $this->postJson("/api/driver/orders/{$order->id}/deliver", ['code' => $order->verification_code])
            ->assertOk()
            ->assertJsonPath('status', 'entregado');

        $this->assertSame(OrderStatus::Entregado, $order->fresh()->status);
        $this->assertSame($driver->id, $order->fresh()->repartidor_id);
    }

    public function test_code_is_not_accepted_while_courier_is_far_from_the_address(): void
    {
        $order = $this->order();
        $this->actingAsDriver();
        $this->courierNearAddress($order, meters: 800);

        $this->postJson("/api/driver/orders/{$order->id}/deliver", ['code' => $order->verification_code])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('code');

        $this->assertSame(OrderStatus::EnCamino, $order->fresh()->status);
    }

    public function test_code_is_not_accepted_without_a_recent_courier_position(): void
    {
        $order = $this->order();
        $this->actingAsDriver();

        $this->postJson("/api/driver/orders/{$order->id}/deliver", ['code' => $order->verification_code])
            ->assertUnprocessable();

        $this->courierNearAddress($order, secondsAgo: 600);
        $this->postJson("/api/driver/orders/{$order->id}/deliver", ['code' => $order->verification_code])
            ->assertUnprocessable();
    }

    public function test_driver_cannot_take_an_unassigned_order_from_outside_quibdo(): void
    {
        $order = $this->order();
        $order->update(['repartidor_id' => null, 'status' => OrderStatus::Preparando]);
        $this->actingAsDriver();

        $this->postJson("/api/driver/orders/{$order->id}/advance")->assertUnprocessable()->assertJsonValidationErrors('latitude');
        $this->postJson("/api/driver/orders/{$order->id}/advance", ['latitude' => 39.9042, 'longitude' => 116.4074])
            ->assertUnprocessable();

        $this->assertNull($order->fresh()->repartidor_id);

        $this->postJson("/api/driver/orders/{$order->id}/advance", ['latitude' => 5.6948, 'longitude' => -76.6588])
            ->assertOk()
            ->assertJsonPath('status', 'en_camino');
    }

    public function test_cliente_cannot_use_driver_endpoints(): void
    {
        $order = $this->order();
        Sanctum::actingAs(User::where('email', 'cliente@demo.co')->first());

        $this->postJson("/api/driver/orders/{$order->id}/deliver", ['code' => $order->verification_code])
            ->assertForbidden();
        $this->getJson('/api/driver/orders')->assertForbidden();
    }

    /** Regresión: los envíos de GPS no deben gastar los intentos del código de entrega. */
    public function test_location_reports_do_not_consume_delivery_attempts(): void
    {
        $order = $this->order();
        $this->actingAsDriver();

        for ($i = 0; $i < 10; $i++) {
            $this->postJson("/api/driver/orders/{$order->id}/location", ['latitude' => 5.6950, 'longitude' => -76.6590])
                ->assertCreated();
        }

        $this->postJson("/api/driver/orders/{$order->id}/deliver", ['code' => $order->verification_code])
            ->assertOk()
            ->assertJsonPath('status', 'entregado');
    }

    public function test_unauthenticated_api_requests_get_json_401(): void
    {
        $this->get('/api/orders')->assertUnauthorized()->assertJsonStructure(['message']);
    }
}
