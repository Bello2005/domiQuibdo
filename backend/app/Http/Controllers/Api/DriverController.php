<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;

class DriverController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $driver = $request->user();
        abort_unless($driver->hasRole(UserRole::Repartidor), 403);

        $orders = Order::with(['restaurant', 'address.zone', 'user'])
            ->where(fn ($q) => $q
                ->where('repartidor_id', $driver->id)
                ->orWhere(fn ($q) => $q
                    ->whereNull('repartidor_id')
                    ->whereNotIn('status', [OrderStatus::Entregado, OrderStatus::Cancelado])))
            ->latest()
            ->limit(30)
            ->get();

        return OrderResource::collection($orders);
    }

    public function advance(Request $request, Order $order): OrderResource
    {
        Gate::authorize('deliver', $order);

        $next = $order->status->next();
        if ($next === null || $next === OrderStatus::Entregado) {
            throw ValidationException::withMessages([
                'status' => 'Para marcar el pedido como entregado debes validar el código del cliente.',
            ]);
        }

        $order->repartidor_id ??= $request->user()->id;
        $order->status = $next;
        $order->save();

        return OrderResource::make($order->load(Order::DETAIL_RELATIONS));
    }

    public function deliver(Request $request, Order $order): OrderResource
    {
        Gate::authorize('deliver', $order);

        $data = $request->validate(['code' => ['required', 'digits:4']]);

        if ($order->status !== OrderStatus::EnCamino) {
            throw ValidationException::withMessages(['code' => 'El pedido debe estar en camino para entregarse.']);
        }

        if (! hash_equals($order->verification_code, $data['code'])) {
            throw ValidationException::withMessages(['code' => 'Código incorrecto. Pídele al cliente el código de su app.']);
        }

        $order->repartidor_id ??= $request->user()->id;
        $order->status = OrderStatus::Entregado;
        $order->save();

        return OrderResource::make($order->load(Order::DETAIL_RELATIONS));
    }
}
