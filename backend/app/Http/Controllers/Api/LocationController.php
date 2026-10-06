<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\CourierLocationRequest;
use App\Models\Order;
use App\Services\TrackingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;

class LocationController extends Controller
{
    /** El repartidor asignado reporta su posición mientras el pedido va en camino. */
    public function store(CourierLocationRequest $request, Order $order, TrackingService $tracking): JsonResponse
    {
        Gate::authorize('deliver', $order);
        abort_unless($order->repartidor_id === $request->user()->id, 403);

        if ($order->status !== OrderStatus::EnCamino) {
            throw ValidationException::withMessages(['status' => 'Solo se reporta la ubicación mientras el pedido va en camino.']);
        }

        $order->courierLocations()->create([
            ...$request->validated(),
            'user_id' => $request->user()->id,
            'recorded_at' => now(),
        ]);

        return response()->json($tracking->snapshot($order->load('address')), 201);
    }

    /** Última posición conocida + ETA. Visible para quienes pueden ver el pedido. */
    public function show(Order $order, TrackingService $tracking): JsonResponse
    {
        Gate::authorize('view', $order);

        return response()->json($tracking->snapshot($order->load('address')));
    }
}
