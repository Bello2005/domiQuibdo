<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Solo para la presentación: permite al cliente avanzar su propio pedido
 * sin cambiar de cuenta. Desactivado salvo APP_DEMO=true.
 */
class DemoController extends Controller
{
    public function advance(Request $request, Order $order): OrderResource
    {
        abort_unless(config('domi.demo'), 404);
        abort_unless($order->user_id === $request->user()->id, 403);

        $next = $order->status->next();
        if ($next === null || $next === OrderStatus::Entregado) {
            throw ValidationException::withMessages([
                'status' => 'La entrega solo se confirma con el código, desde la cuenta del repartidor.',
            ]);
        }

        if ($next === OrderStatus::EnCamino) {
            $order->repartidor_id ??= User::where('email', config('domi.demo_driver_email'))->value('id');
        }

        $order->status = $next;
        $order->save();

        return OrderResource::make($order->load(Order::DETAIL_RELATIONS));
    }
}
