<?php

namespace App\Http\Controllers\Api;

use App\Enums\PaymentStatus;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Services\PayuService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\URL;
use Illuminate\Validation\ValidationException;

class PaymentController extends Controller
{
    /** Minutos de validez del enlace firmado que abre el checkout de PayU. */
    private const CHECKOUT_LINK_MINUTES = 30;

    /**
     * Estado del pago y, si falta pagar, el enlace al checkout de PayU (solo el cliente dueño).
     */
    public function show(Request $request, Order $order): JsonResponse
    {
        abort_unless($request->user()->id === $order->user_id, 403);

        if ($order->payment_method !== 'payu') {
            throw ValidationException::withMessages(['payment' => 'Este pedido se paga en efectivo al recibirlo.']);
        }

        $canPay = $order->isAwaitingPayment() && $order->status->isActive()
            && $order->payment_status !== PaymentStatus::Expirado;

        return response()->json([
            'payment_status' => $order->payment_status?->value,
            'payment_status_label' => $order->payment_status?->label(),
            'checkout_url' => $canPay
                ? URL::temporarySignedRoute('payments.payu.checkout', now()->addMinutes(self::CHECKOUT_LINK_MINUTES), ['order' => $order->id])
                : null,
        ]);
    }

    /**
     * Notificación servidor a servidor de PayU (confirmationUrl). Es la fuente confiable del estado.
     */
    public function payuConfirmation(Request $request, PayuService $payu): Response
    {
        $data = $request->all();

        if (! $payu->isValidConfirmation($data)) {
            Log::warning('Confirmación de PayU con firma inválida', ['reference' => $data['reference_sale'] ?? null]);

            return response('Firma inválida', 403);
        }

        $order = Order::where('payment_reference', $data['reference_sale'])->first();
        $status = PaymentStatus::fromPayuState((int) $data['state_pol']);

        if ($order && $status) {
            $payu->applyState($order, $status, (string) $data['value'], $data['transaction_id'] ?? null);
        }

        return response('OK');
    }
}
