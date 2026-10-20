<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RestaurantFinanceTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private function owner(): User
    {
        $owner = User::where('email', 'restaurante@demo.co')->first();
        Sanctum::actingAs($owner);

        return $owner;
    }

    /** El pedido demo (de Pollos Nacho) como venta entregada de comida por `$subtotal`. */
    private function deliveredOrder(float $subtotal, string $paymentMethod = 'efectivo'): Order
    {
        $order = Order::first();
        $order->update([
            'status' => OrderStatus::Entregado,
            'total' => $subtotal + $order->delivery_fee + $order->service_fee + $order->payment_fee,
            'payment_method' => $paymentMethod,
        ]);

        return $order;
    }

    public function test_restaurant_keeps_its_whole_menu_price_by_default(): void
    {
        $this->owner();
        $this->deliveredOrder(40000);

        $this->getJson('/api/restaurant/finances?days=7')
            ->assertOk()
            ->assertJsonPath('commission_rate', 0)
            ->assertJsonPath('summary.gross_sales', 40000)
            ->assertJsonPath('summary.commission', 0)
            ->assertJsonPath('summary.net_earnings', 40000);
    }

    public function test_report_counts_only_delivered_sales_and_applies_commission(): void
    {
        config(['domi.commission_rate' => 0.10]);
        $this->owner();
        $order = $this->deliveredOrder(40000);
        $cancelled = $order->replicate();
        $cancelled->status = OrderStatus::Cancelado;
        $cancelled->save();

        $this->getJson('/api/restaurant/finances?days=7')
            ->assertOk()
            ->assertJsonPath('period.days', 7)
            ->assertJsonCount(7, 'daily')
            ->assertJsonCount(24, 'hourly')
            ->assertJsonPath('summary.orders', 1)
            ->assertJsonPath('summary.gross_sales', 40000)
            ->assertJsonPath('summary.commission', 4000)
            ->assertJsonPath('summary.net_earnings', 36000)
            ->assertJsonPath('summary.cancelled_orders', 1)
            ->assertJsonPath('payment_methods.0.method', 'efectivo')
            ->assertJsonPath('payment_methods.0.amount', 40000)
            ->assertJsonCount(2, 'movements')
            ->assertJsonPath('movements.0.receipt_number', 'DQ-'.str_pad((string) $cancelled->id, 6, '0', STR_PAD_LEFT))
            ->assertJsonPath('movements.0.net', 0);
    }

    public function test_previous_period_is_reported_apart(): void
    {
        $this->owner();
        $order = $this->deliveredOrder(20000);
        $order->forceFill(['created_at' => now()->subDays(10)])->save();

        $this->getJson('/api/restaurant/finances?days=7')
            ->assertOk()
            ->assertJsonPath('summary.orders', 0)
            ->assertJsonPath('previous.orders', 1)
            ->assertJsonPath('previous.gross_sales', 20000);
    }

    public function test_owner_never_sees_sales_of_another_restaurant(): void
    {
        $this->owner();
        $order = $this->deliveredOrder(50000);
        $order->update(['restaurant_id' => Restaurant::where('name', '!=', 'Pollos Nacho')->value('id')]);

        $this->getJson('/api/restaurant/finances')
            ->assertOk()
            ->assertJsonPath('period.days', 30)
            ->assertJsonPath('summary.orders', 0)
            ->assertJsonCount(0, 'movements');
    }

    public function test_period_must_be_one_of_the_offered_ranges(): void
    {
        $this->owner();

        $this->getJson('/api/restaurant/finances?days=365')->assertUnprocessable();
    }

    public function test_receipt_includes_breakdown_for_own_order_only(): void
    {
        config(['domi.commission_rate' => 0.10]);
        $this->owner();
        $order = $this->deliveredOrder(30000, 'payu');

        $this->getJson("/api/restaurant/orders/{$order->id}/receipt")
            ->assertOk()
            ->assertJsonPath('receipt_number', 'DQ-'.str_pad((string) $order->id, 6, '0', STR_PAD_LEFT))
            ->assertJsonPath('restaurant.name', 'Pollos Nacho')
            ->assertJsonPath('breakdown.subtotal', 30000)
            ->assertJsonPath('breakdown.commission', 3000)
            ->assertJsonPath('breakdown.net', 27000)
            ->assertJsonPath('order.id', $order->id)
            ->assertJsonMissingPath('order.verification_code');

        $order->update(['restaurant_id' => Restaurant::where('name', '!=', 'Pollos Nacho')->value('id')]);
        $this->getJson("/api/restaurant/orders/{$order->id}/receipt")->assertForbidden();
    }

    public function test_other_roles_cannot_read_finances(): void
    {
        Sanctum::actingAs(User::where('email', 'cliente@demo.co')->first());

        $this->getJson('/api/restaurant/finances')->assertForbidden();
    }
}
