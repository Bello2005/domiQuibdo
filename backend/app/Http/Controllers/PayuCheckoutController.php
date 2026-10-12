<?php

namespace App\Http\Controllers;

use App\Enums\PaymentStatus;
use App\Models\Order;
use App\Services\PayuService;
use Illuminate\Http\Request;
use Illuminate\View\View;

/**
 * Páginas web del pago: la app abre el enlace firmado en el navegador, que envía el formulario
 * a PayU; al terminar, PayU redirige a la página de respuesta.
 */
class PayuCheckoutController extends Controller
{
    /** Formulario firmado que se envía solo a PayU (la ruta exige URL firmada por el backend). */
    public function checkout(Order $order, PayuService $payu): View
    {
        $order->load(['restaurant', 'user', 'address']);

        abort_unless(
            $order->isAwaitingPayment() && $order->status->isActive() && $order->payment_status !== PaymentStatus::Expirado,
            410,
            'Este pedido ya no tiene un pago pendiente.',
        );

        return view('payments.payu-checkout', [
            'order' => $order,
            'action' => $payu->checkoutUrl(),
            'fields' => $payu->checkoutFields($order),
        ]);
    }

    /**
     * Página a la que PayU devuelve al comprador. Si la firma es válida también actualiza el
     * estado, por si la confirmación servidor a servidor tarda o no llega.
     */
    public function response(Request $request, PayuService $payu): View
    {
        $query = $request->query();
        $valid = $payu->isValidResponse($query);
        $status = $valid ? PaymentStatus::fromPayuState((int) ($query['transactionState'] ?? 0)) : null;

        $order = $valid ? Order::where('payment_reference', $query['referenceCode'] ?? '')->first() : null;
        if ($order && $status) {
            $payu->applyState($order, $status, (string) $query['TX_VALUE'], $query['transactionId'] ?? null);
        }

        return view('payments.payu-result', [
            'valid' => $valid,
            'status' => $status,
            'order' => $order?->fresh(),
        ]);
    }
}
