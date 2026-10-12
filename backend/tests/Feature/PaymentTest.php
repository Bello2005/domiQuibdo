<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Models\Order;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PaymentTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private const API_KEY = '4Vj8eK4rloUd272L48hsrarnUA';

    private const MERCHANT_ID = '508029';

    private function cliente(): User
    {
        return User::where('email', 'cliente@demo.co')->first();
    }

    private function placePayuOrder(): Order
    {
        $cliente = $this->cliente();
        Sanctum::actingAs($cliente);

        $id = $this->postJson('/api/orders', [
            'address_id' => $cliente->addresses()->value('id'),
            'items' => [['menu_item_id' => Restaurant::where('name', 'Pollos Nacho')->first()->menuItems()->value('id'), 'quantity' => 1]],
            'payment_method' => 'payu',
        ])->assertCreated()->assertJsonPath('payment_status', 'pendiente')->json('id');

        return Order::find($id);
    }

    /**
     * POST de confirmación tal como lo envía PayU (firma MD5, su algoritmo por defecto).
     *
     * @param  array<string, string>  $overrides
     */
    private function confirm(Order $order, int $state, array $overrides = [])
    {
        $value = $overrides['value'] ?? number_format($order->total, 2, '.', '');
        $signedValue = str_ends_with($value, '0') ? substr($value, 0, -1) : $value;

        return $this->post('/api/payments/payu/confirmation', [
            'merchant_id' => self::MERCHANT_ID,
            'reference_sale' => $order->payment_reference,
            'value' => $value,
            'currency' => 'COP',
            'state_pol' => (string) $state,
            'transaction_id' => 'tx-'.$state,
            'sign' => md5(implode('~', [self::API_KEY, self::MERCHANT_ID, $order->payment_reference, $signedValue, 'COP', $state])),
            ...$overrides,
        ]);
    }

    private function actingAsRestaurant(): void
    {
        Sanctum::actingAs(User::where('email', 'restaurante@demo.co')->first());
    }

    public function test_customer_gets_signed_checkout_with_valid_payu_form(): void
    {
        $order = $this->placePayuOrder();
        $this->assertMatchesRegularExpression('/^DQ-'.$order->id.'-[A-Z0-9]{6}$/', $order->payment_reference);

        $url = $this->getJson("/api/orders/{$order->id}/payment")->assertOk()->json('checkout_url');
        $this->assertNotNull($url);

        $amount = number_format($order->total, 2, '.', '');
        $this->get($url)
            ->assertOk()
            ->assertSee('https://sandbox.checkout.payulatam.com/ppp-web-gateway-payu/', false)
            ->assertSee('name="referenceCode" value="'.$order->payment_reference.'"', false)
            ->assertSee('name="amount" value="'.$amount.'"', false)
            ->assertSee(hash('sha256', implode('~', [self::API_KEY, self::MERCHANT_ID, $order->payment_reference, $amount, 'COP'])), false);
    }

    public function test_checkout_includes_return_urls_on_public_https(): void
    {
        $order = $this->placePayuOrder();

        // Las URLs se arman con el host de la petición, como en producción detrás de nginx con HTTPS.
        $this->get($this->getJson("https://api.domiquibdo.test/api/orders/{$order->id}/payment")->json('checkout_url'))
            ->assertOk()
            ->assertSee('name="responseUrl" value="https://api.domiquibdo.test/pagos/payu/respuesta"', false)
            ->assertSee('name="confirmationUrl" value="https://api.domiquibdo.test/api/payments/payu/confirmation"', false);
    }

    /** El firewall de PayU rechaza URLs http o de IP privada: en local no se envían. */
    public function test_checkout_omits_return_urls_on_local_http(): void
    {
        $order = $this->placePayuOrder();

        $this->get($this->getJson("/api/orders/{$order->id}/payment")->json('checkout_url'))
            ->assertOk()
            ->assertDontSee('name="responseUrl"', false)
            ->assertDontSee('name="confirmationUrl"', false);
    }

    public function test_checkout_page_requires_backend_signature(): void
    {
        $order = $this->placePayuOrder();

        $this->get("/pagos/payu/{$order->id}")->assertForbidden();
    }

    public function test_other_customer_cannot_get_payment_link(): void
    {
        $order = $this->placePayuOrder();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson("/api/orders/{$order->id}/payment")->assertForbidden();
    }

    public function test_unpaid_order_cannot_be_confirmed_by_restaurant_until_approved(): void
    {
        $order = $this->placePayuOrder();
        $this->actingAsRestaurant();

        $this->postJson("/api/restaurant/orders/{$order->id}/advance")->assertUnprocessable();
        $this->assertSame(OrderStatus::Pendiente, $order->fresh()->status);

        $this->confirm($order, 4)->assertOk();

        $this->postJson("/api/restaurant/orders/{$order->id}/advance")->assertOk()->assertJsonPath('status', 'confirmado');
    }

    public function test_approved_confirmation_marks_order_paid(): void
    {
        $order = $this->placePayuOrder();

        $this->confirm($order, 4)->assertOk();

        $order->refresh();
        $this->assertSame(PaymentStatus::Aprobado, $order->payment_status);
        $this->assertNotNull($order->paid_at);
        $this->assertSame('tx-4', $order->payment_transaction_id);

        Sanctum::actingAs($this->cliente());
        $this->getJson("/api/orders/{$order->id}/payment")->assertOk()->assertJsonPath('checkout_url', null);
    }

    public function test_confirmation_with_invalid_signature_is_rejected(): void
    {
        $order = $this->placePayuOrder();

        $this->confirm($order, 4, ['sign' => md5('falsa')])->assertForbidden();

        $this->assertSame(PaymentStatus::Pendiente, $order->fresh()->payment_status);
    }

    public function test_tampered_value_does_not_approve_payment(): void
    {
        $order = $this->placePayuOrder();

        // Firma válida pero por un monto menor al del pedido.
        $this->confirm($order, 4, ['value' => '1000.00'])->assertOk();

        $this->assertSame(PaymentStatus::Pendiente, $order->fresh()->payment_status);
    }

    public function test_rejected_attempt_can_be_retried_and_approved(): void
    {
        $order = $this->placePayuOrder();

        $this->confirm($order, 6)->assertOk();
        $this->assertSame(PaymentStatus::Rechazado, $order->fresh()->payment_status);
        $this->assertSame(OrderStatus::Pendiente, $order->fresh()->status);

        $this->confirm($order, 4)->assertOk();
        $this->assertSame(PaymentStatus::Aprobado, $order->fresh()->payment_status);
    }

    public function test_later_reports_do_not_undo_an_approved_payment(): void
    {
        $order = $this->placePayuOrder();

        $this->confirm($order, 4)->assertOk();
        $this->confirm($order, 6)->assertOk();

        $this->assertSame(PaymentStatus::Aprobado, $order->fresh()->payment_status);
    }

    public function test_expired_payment_cancels_the_order(): void
    {
        $order = $this->placePayuOrder();

        $this->confirm($order, 5)->assertOk();

        $order->refresh();
        $this->assertSame(PaymentStatus::Expirado, $order->payment_status);
        $this->assertSame(OrderStatus::Cancelado, $order->status);
    }

    public function test_signed_response_page_updates_payment(): void
    {
        $order = $this->placePayuOrder();
        $value = number_format($order->total, 2, '.', '');

        $this->get('/pagos/payu/respuesta?'.http_build_query([
            'merchantId' => self::MERCHANT_ID,
            'referenceCode' => $order->payment_reference,
            'TX_VALUE' => $value,
            'currency' => 'COP',
            'transactionState' => 4,
            'transactionId' => 'tx-web',
            'signature' => md5(implode('~', [self::API_KEY, self::MERCHANT_ID, $order->payment_reference, substr($value, 0, -1), 'COP', 4])),
        ]))->assertOk()->assertSee('¡Pago aprobado!');

        $this->assertSame(PaymentStatus::Aprobado, $order->fresh()->payment_status);
    }

    public function test_unsigned_response_page_does_not_change_payment(): void
    {
        $order = $this->placePayuOrder();

        $this->get('/pagos/payu/respuesta?'.http_build_query([
            'merchantId' => self::MERCHANT_ID,
            'referenceCode' => $order->payment_reference,
            'TX_VALUE' => '1.00',
            'currency' => 'COP',
            'transactionState' => 4,
            'signature' => 'abc',
        ]))->assertOk()->assertSee('No pudimos verificar el pago');

        $this->assertSame(PaymentStatus::Pendiente, $order->fresh()->payment_status);
    }

    public function test_drivers_are_not_offered_unpaid_orders(): void
    {
        $order = $this->placePayuOrder();
        Sanctum::actingAs(User::where('email', 'repartidor@demo.co')->first());

        $this->assertNotContains($order->id, $this->getJson('/api/driver/orders')->assertOk()->json('*.id'));
        $this->postJson("/api/driver/orders/{$order->id}/advance")->assertUnprocessable();
    }

    public function test_customer_cannot_cancel_after_paying(): void
    {
        $order = $this->placePayuOrder();
        $this->confirm($order, 4)->assertOk();
        Sanctum::actingAs($this->cliente());

        $this->postJson("/api/orders/{$order->id}/cancel")->assertForbidden();
    }
}
