<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\ZoneRequest;
use App\Http\Resources\ZoneResource;
use App\Models\CoverageZone;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ZoneController extends Controller
{
    public function index(): AnonymousResourceCollection
    {
        return ZoneResource::collection(CoverageZone::orderBy('name')->get());
    }

    public function store(ZoneRequest $request): JsonResponse
    {
        $zone = CoverageZone::create($request->validated() + ['is_active' => true]);

        return ZoneResource::make($zone)->response()->setStatusCode(201);
    }

    public function update(ZoneRequest $request, CoverageZone $zone): ZoneResource
    {
        $zone->update($request->validated());

        return ZoneResource::make($zone);
    }

    public function destroy(CoverageZone $zone): JsonResponse
    {
        try {
            $zone->delete();
        } catch (QueryException) {
            abort(422, 'No se puede eliminar: hay direcciones registradas en esta zona.');
        }

        return response()->json(status: 204);
    }
}
