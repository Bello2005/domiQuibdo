<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\CourierLocationRequest;
use App\Models\Order;
use App\Services\CoverageService;
use App\Services\TrackingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;

class LocationController extends Controller
{
    /** El repartidor asignado reporta su posición mientras el pedido va en camino. */
    public function store(CourierLocationRequest $request, Order $order, TrackingService $tracking): JsonResponse
    {
        // La policy deja pasar al repartidor asignado o, si nadie lo tiene, a cualquiera.
        Gate::authorize('deliver', $order);

        if ($order->status !== OrderStatus::EnCamino) {
            throw ValidationException::withMessages(['status' => 'Solo se reporta la ubicación mientras el pedido va en camino.']);
        }

        if (! CoverageService::insideServiceArea((float) $request->validated('latitude'), (float) $request->validated('longitude'))) {
            throw ValidationException::withMessages([
                'latitude' => 'Estás fuera de la zona de servicio de Quibdó: no puedes tomar este pedido.',
            ]);
        }

        // El restaurante entrega el pedido sin asignarlo: el primer repartidor que reporta se lo queda.
        if ($order->repartidor_id === null) {
            $order->update(['repartidor_id' => $request->user()->id]);
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
