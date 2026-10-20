<?php

namespace App\Http\Controllers\Api\Restaurant;

use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\RestaurantFinanceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class FinanceController extends Controller
{
    /** Ventas, comisión, ganancia neta y movimientos de los restaurantes del dueño. */
    public function index(Request $request, RestaurantFinanceService $finances): JsonResponse
    {
        $request->validate(['days' => ['sometimes', 'integer', 'in:7,30,90']]);
        $days = $request->integer('days', 30);

        return response()->json(
            $finances->report($request->user()->restaurants()->pluck('id'), $days)
        );
    }

    /** Datos del comprobante de un pedido; la app arma el PDF descargable. */
    public function receipt(Request $request, Order $order): JsonResponse
    {
        Gate::authorize('manage', $order);

        $order->load(Order::DETAIL_RELATIONS);

        return response()->json([
            'receipt_number' => RestaurantFinanceService::receiptNumber($order),
            'issued_at' => now()->toIso8601String(),
            'restaurant' => [
                'name' => $order->restaurant->name,
                'address' => $order->restaurant->address_text,
                'phone' => $order->restaurant->phone,
            ],
            'breakdown' => RestaurantFinanceService::breakdown($order),
            'order' => OrderResource::make($order)->resolve($request),
        ]);
    }
}
