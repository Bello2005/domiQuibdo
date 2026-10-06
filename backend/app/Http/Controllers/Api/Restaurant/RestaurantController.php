<?php

namespace App\Http\Controllers\Api\Restaurant;

use App\Http\Controllers\Controller;
use App\Http\Resources\RestaurantResource;
use App\Models\Restaurant;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class RestaurantController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        return RestaurantResource::collection(
            $request->user()->restaurants()->with('menuItems')->orderBy('name')->get()
        );
    }

    /** El dueño solo puede abrir/cerrar su negocio; el resto de datos los edita el admin. */
    public function update(Request $request, Restaurant $restaurant): RestaurantResource
    {
        Gate::authorize('update', $restaurant);

        $data = $request->validate([
            'is_active' => ['required', 'boolean'],
            'delivery_time_min' => ['sometimes', 'integer', 'min:5', 'max:240'],
        ]);
        $restaurant->update($data);

        return RestaurantResource::make($restaurant->load('menuItems'));
    }
}
