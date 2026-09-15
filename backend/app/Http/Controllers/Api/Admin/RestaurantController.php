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
        $data = $this->withDefaults($request->validated());
        $restaurant = Restaurant::create($data + ['is_active' => true]);

        return RestaurantResource::make($restaurant)->response()->setStatusCode(201);
    }

    public function update(RestaurantRequest $request, Restaurant $restaurant): RestaurantResource
    {
        $restaurant->update($this->withDefaults($request->validated()));

        return RestaurantResource::make($restaurant->load('menuItems'));
    }

    /**
     * rating_avg y delivery_time_min no aceptan NULL en la base de datos
     * (tienen valor por defecto): si vienen vacios, se omiten para usar el default.
     *
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function withDefaults(array $data): array
    {
        if (! array_key_exists('rating_avg', $data) || $data['rating_avg'] === null) {
            unset($data['rating_avg']);
        }
        if (! array_key_exists('delivery_time_min', $data) || $data['delivery_time_min'] === null) {
            unset($data['delivery_time_min']);
        }

        return $data;
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
