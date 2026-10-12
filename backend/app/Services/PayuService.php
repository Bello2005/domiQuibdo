<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Models\Order;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Integración con PayU WebCheckout: arma el formulario firmado y valida lo que PayU reporta.
 * El estado del pago solo cambia con datos firmados por PayU (confirmación o página de respuesta).
 */
final class PayuService
{
    public function checkoutUrl(): string
    {
        return config('services.payu.checkout_url');
    }

    public static function newReference(Order $order): string
    {
        return 'DQ-'.$order->id.'-'.Str::upper(Str::random(6));
    }

    /**
     * Campos del formulario que se envía por POST a PayU.
     *
     * @return array<string, string>
     */
    public function checkoutFields(Order $order): array
    {
        $amount = number_format($order->total, 2, '.', '');
        $currency = config('services.payu.currency');

        return [
            'merchantId' => (string) config('services.payu.merchant_id'),
            'accountId' => (string) config('services.payu.account_id'),
            'description' => Str::limit("DomiQuibdó · Pedido #{$order->id} · {$order->restaurant->name}", 250, ''),
            'referenceCode' => $order->payment_reference,
            'amount' => $amount,
            'tax' => '0',
            'taxReturnBase' => '0',
            'currency' => $currency,
            'signature' => hash('sha256', $this->signatureBase([
                config('services.payu.merchant_id'), $order->payment_reference, $amount, $currency,
            ])),
            'algorithmSignature' => 'SHA256',
            'test' => config('services.payu.test') ? '1' : '0',
            'lng' => 'es',
            'buyerEmail' => $order->user->email,
            'buyerFullName' => $order->user->name,
            'telephone' => (string) $order->user->phone,
            'shippingAddress' => Str::limit($order->address->detalle ?: 'Quibdó, Chocó', 250, ''),
            'shippingCity' => 'Quibdó',
            'shippingCountry' => 'CO',
            ...$this->returnUrls(),
        ];
    }

    /**
     * URLs de regreso y de notificación. El firewall de PayU rechaza el formulario (403) si
     * apuntan a una IP privada o a http, así que en desarrollo local se omiten.
     *
     * @return array<string, string>
     */
    private function returnUrls(): array
    {
        $responseUrl = route('payments.payu.response');
        if (! str_starts_with($responseUrl, 'https://')) {
            return [];
        }

        return [
            'responseUrl' => $responseUrl,
            'confirmationUrl' => route('payments.payu.confirmation'),
        ];
    }

    /**
     * Firma de la confirmación (POST de PayU al servidor): merchant_id~reference_sale~value~currency~state_pol.
     *
     * @param  array<string, mixed>  $data
     */
    public function isValidConfirmation(array $data): bool
    {
        return $this->signatureMatches((string) ($data['sign'] ?? ''), [
            $data['merchant_id'] ?? '', $data['reference_sale'] ?? '',
            self::signatureValue((string) ($data['value'] ?? '')), $data['currency'] ?? '', $data['state_pol'] ?? '',
        ]);
    }

    /**
     * Firma de la página de respuesta (redirección del navegador): merchantId~referenceCode~TX_VALUE~currency~transactionState.
     *
     * @param  array<string, mixed>  $query
     */
    public function isValidResponse(array $query): bool
    {
        return $this->signatureMatches((string) ($query['signature'] ?? ''), [
            $query['merchantId'] ?? '', $query['referenceCode'] ?? '',
            self::signatureValue((string) ($query['TX_VALUE'] ?? '')), $query['currency'] ?? '', $query['transactionState'] ?? '',
        ]);
    }

    /**
     * Regla de PayU para el valor dentro de la firma: si el segundo decimal es cero se usa uno solo
     * (150.00 → 150.0, 150.20 → 150.2, 150.25 → 150.25).
     */
    public static function signatureValue(string $value): string
    {
        $formatted = number_format((float) $value, 2, '.', '');

        return str_ends_with($formatted, '0') ? substr($formatted, 0, -1) : $formatted;
    }

    /**
     * Aplica el estado reportado por PayU. Es idempotente: PayU puede reportar varias veces
     * (reintentos del comprador o de la notificación) y un pago aprobado ya no cambia.
     */
    public function applyState(Order $order, PaymentStatus $status, string $reportedValue, ?string $transactionId): void
    {
        if ($order->payment_status === PaymentStatus::Aprobado) {
            return;
        }

        if ($status === PaymentStatus::Aprobado && abs((float) $reportedValue - $order->total) > 0.01) {
            Log::warning('PayU reportó un monto distinto al del pedido', [
                'order_id' => $order->id, 'reported' => $reportedValue, 'total' => $order->total,
            ]);

            return;
        }

        $order->payment_status = $status;
        $order->payment_transaction_id = $transactionId ?: $order->payment_transaction_id;

        if ($status === PaymentStatus::Aprobado) {
            $order->paid_at = now();
        }

        // Un pago expirado no se puede reintentar: el pedido sin pagar se cancela.
        if ($status === PaymentStatus::Expirado && $order->status === OrderStatus::Pendiente) {
            $order->status = OrderStatus::Cancelado;
        }

        $order->save();
    }

    /**
     * @param  list<mixed>  $parts
     */
    private function signatureBase(array $parts): string
    {
        return implode('~', [config('services.payu.api_key'), ...$parts]);
    }

    /**
     * PayU firma con el algoritmo configurado en la cuenta (MD5 por defecto, SHA1 o SHA256).
     *
     * @param  list<mixed>  $parts
     */
    private function signatureMatches(string $signature, array $parts): bool
    {
        if ($signature === '') {
            return false;
        }

        $base = $this->signatureBase($parts);
        $signature = strtolower($signature);

        foreach (['md5', 'sha1', 'sha256'] as $algorithm) {
            if (hash_equals(hash($algorithm, $base), $signature)) {
                return true;
            }
        }

        return false;
    }
}
