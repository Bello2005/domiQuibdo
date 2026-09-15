<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\RestaurantRequest;
use App\Http\Resources\RestaurantResource;
use App\Models\Restaurant;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class RestaurantController extends Controller
{
    public function index(): AnonymousResourceCollection
    {
        return RestaurantResource::collection(
            Restaurant::with('menuItems')->orderBy('name')->get()
        );
    }

    public function store(RestaurantRequest $request): JsonResponse
    {
        $restaurant = Restaurant::create($request->validated() + ['is_active' => true]);

        return RestaurantResource::make($restaurant)->response()->setStatusCode(201);
    }

    public function update(RestaurantRequest $request, Restaurant $restaurant): RestaurantResource
    {
        $restaurant->update($request->validated());

        return RestaurantResource::make($restaurant->load('menuItems'));
    }

    public function destroy(Restaurant $restaurant): JsonResponse
    {
        try {
            $restaurant->delete();
        } catch (QueryException) {
            abort(422, 'No se puede eliminar: tiene pedidos asociados.');
        }

        return response()->json(status: 204);
    }
}
