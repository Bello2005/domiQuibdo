<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Models\Incident;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class IncidentAndCancelTest extends TestCase
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

    public function test_customer_and_driver_can_raise_sos(): void
    {
        $order = $this->order();

        $this->as('cliente@demo.co');
        $this->postJson("/api/orders/{$order->id}/incidents", [
            'type' => 'sos', 'latitude' => 5.69, 'longitude' => -76.65, 'message' => 'Me siento inseguro',
        ])->assertCreated()->assertJsonPath('status', 'abierto')->assertJsonPath('reporter.role', 'cliente');

        $this->as('repartidor@demo.co');
        $this->postJson("/api/orders/{$order->id}/incidents", ['type' => 'problema'])
            ->assertCreated()->assertJsonPath('reporter.role', 'repartidor');

        $this->assertSame(2, Incident::count());
    }

    public function test_incident_requires_valid_type_and_participation(): void
    {
        $order = $this->order();

        $this->as('cliente@demo.co');
        $this->postJson("/api/orders/{$order->id}/incidents", ['type' => 'otro'])->assertUnprocessable();
        $this->postJson("/api/orders/{$order->id}/incidents", ['type' => 'sos', 'latitude' => 5.6])->assertUnprocessable();

        Sanctum::actingAs(User::factory()->create());
        $this->postJson("/api/orders/{$order->id}/incidents", ['type' => 'sos'])->assertForbidden();
    }

    public function test_admin_lists_and_resolves_incidents(): void
    {
        $order = $this->order();
        $this->as('cliente@demo.co');
        $id = $this->postJson("/api/orders/{$order->id}/incidents", ['type' => 'sos'])->json('id');

        $this->as('cliente@demo.co');
        $this->getJson('/api/admin/incidents')->assertForbidden();

        $this->as('admin@demo.co');
        $this->getJson('/api/admin/incidents?status=abierto')
            ->assertOk()->assertJsonCount(1)->assertJsonPath('0.order.restaurant', 'Pollos Nacho');

        $this->putJson("/api/admin/incidents/{$id}", ['status' => 'atendido'])
            ->assertOk()->assertJsonPath('status', 'atendido');
        $this->assertNotNull(Incident::find($id)->resolved_at);
        $this->getJson('/api/admin/incidents?status=abierto')->assertJsonCount(0);
    }

    public function test_customer_can_cancel_only_while_pending(): void
    {
        $order = $this->order();
        $this->as('cliente@demo.co');

        $this->postJson("/api/orders/{$order->id}/cancel")->assertForbidden();

        $order->update(['status' => OrderStatus::Pendiente]);
        $this->postJson("/api/orders/{$order->id}/cancel")->assertOk()->assertJsonPath('status', 'cancelado');
    }

    public function test_other_customer_cannot_cancel(): void
    {
        $order = $this->order();
        $order->update(['status' => OrderStatus::Pendiente]);
        Sanctum::actingAs(User::factory()->create());

        $this->postJson("/api/orders/{$order->id}/cancel")->assertForbidden();
        $this->assertSame(OrderStatus::Pendiente, $order->fresh()->status);
    }

    public function test_seed_command_links_restaurant_owner_on_existing_database(): void
    {
        \App\Models\Restaurant::where('name', 'Pollos Nacho')->update(['user_id' => null]);

        $this->artisan('demo:seed-once')->assertSuccessful();

        $owner = User::where('email', 'restaurante@demo.co')->value('id');
        $this->assertSame($owner, \App\Models\Restaurant::where('name', 'Pollos Nacho')->value('user_id'));
    }
}
