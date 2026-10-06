<?php

namespace App\Http\Controllers\Api\Admin;

use App\Enums\IncidentStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\IncidentResource;
use App\Models\Incident;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class IncidentController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $incidents = Incident::with(['reporter', 'order.restaurant'])
            ->when($request->query('status'), fn ($q, $status) => $q->where('status', $status))
            ->orderByRaw("case when status = 'abierto' then 0 else 1 end")
            ->latest()
            ->limit(100)
            ->get();

        return IncidentResource::collection($incidents);
    }

    public function update(Request $request, Incident $incident): IncidentResource
    {
        $data = $request->validate(['status' => ['required', Rule::enum(IncidentStatus::class)]]);

        $incident->status = IncidentStatus::from($data['status']);
        $incident->resolved_at = $incident->status === IncidentStatus::Atendido ? now() : null;
        $incident->save();

        return IncidentResource::make($incident->load(['reporter', 'order.restaurant']));
    }
}
