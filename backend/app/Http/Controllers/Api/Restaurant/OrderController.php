<?php

namespace App\Http\Controllers\Api\Restaurant;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;

class OrderController extends Controller
{
    /** Estados que el restaurante controla; de "en camino" en adelante lo maneja el repartidor. */
    private const KITCHEN_STATUSES = [OrderStatus::Pendiente, OrderStatus::Confirmado];

    public function index(Request $request): AnonymousResourceCollection
    {
        $orders = Order::with(['restaurant', 'address.zone', 'items.menuItem', 'user', 'repartidor'])
            ->whereIn('restaurant_id', $request->user()->restaurants()->select('id'))
            ->when($request->query('status'), fn ($q, $status) => $q->where('status', $status))
            ->latest()
            ->limit(50)
            ->get();

        return OrderResource::collection($orders);
    }

    /** Pendiente → confirmado → preparando → en camino (el restaurante entrega al repartidor). */
    public function advance(Request $request, Order $order): OrderResource
    {
        Gate::authorize('manage', $order);

        $next = $order->status->next();
        if ($next === null || $next === OrderStatus::Entregado) {
            throw ValidationException::withMessages(['status' => 'Este pedido ya no se puede avanzar.']);
        }

        $order->status = $next;
        $order->save();

        return OrderResource::make($order->load(Order::DETAIL_RELATIONS));
    }

    public function cancel(Request $request, Order $order): OrderResource
    {
        Gate::authorize('manage', $order);

        if (! in_array($order->status, [...self::KITCHEN_STATUSES, OrderStatus::Preparando], true)) {
            throw ValidationException::withMessages(['status' => 'Solo se puede cancelar antes de que el pedido salga a entrega.']);
        }

        $order->status = OrderStatus::Cancelado;
        $order->save();

        return OrderResource::make($order->load(Order::DETAIL_RELATIONS));
    }
}
