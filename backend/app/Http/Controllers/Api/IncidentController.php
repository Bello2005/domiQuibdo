<?php

namespace App\Http\Controllers\Api;

use App\Enums\IncidentStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\IncidentRequest;
use App\Http\Resources\IncidentResource;
use App\Models\Order;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Gate;

class IncidentController extends Controller
{
    /** SOS o reporte de problema sobre un pedido, hecho por quien participa en él. */
    public function store(IncidentRequest $request, Order $order): JsonResponse
    {
        Gate::authorize('view', $order);

        $incident = $order->incidents()->create([
            ...$request->validated(),
            'user_id' => $request->user()->id,
            'status' => IncidentStatus::Abierto,
        ]);

        return IncidentResource::make($incident->load('reporter'))->response()->setStatusCode(201);
    }
}
