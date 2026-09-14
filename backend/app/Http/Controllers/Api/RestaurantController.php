<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\RestaurantResource;
use App\Models\Restaurant;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class RestaurantController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $restaurants = Restaurant::where('is_active', true)
            ->when($request->filled('category'), fn ($q) => $q->where('category', $request->string('category')))
            ->when($request->filled('q'), fn ($q) => $q->where('name', 'ilike', '%'.$request->string('q').'%'))
            ->orderByDesc('rating_avg')
            ->get();

        return RestaurantResource::collection($restaurants);
    }

    public function categories(): JsonResponse
    {
        return response()->json(
            Restaurant::where('is_active', true)->distinct()->orderBy('category')->pluck('category')
        );
    }

    public function show(Restaurant $restaurant): RestaurantResource
    {
        abort_unless($restaurant->is_active, 404);

        return RestaurantResource::make(
            $restaurant->load(['menuItems' => fn ($q) => $q->where('is_available', true)->orderBy('id')])
        );
    }
}
