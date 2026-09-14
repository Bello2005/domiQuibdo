<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreOrderRequest;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\OrderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class OrderController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        return OrderResource::collection(
            $request->user()->orders()->with('restaurant')->withCount('items')->latest()->limit(50)->get()
        );
    }

    public function store(StoreOrderRequest $request, OrderService $orders): JsonResponse
    {
        $order = $orders->place($request->user(), $request->validated());

        return OrderResource::make($order->load(Order::DETAIL_RELATIONS))->response()->setStatusCode(201);
    }

    public function show(Order $order): OrderResource
    {
        Gate::authorize('view', $order);

        return OrderResource::make($order->load(Order::DETAIL_RELATIONS));
    }

    public function route(Order $order): JsonResponse
    {
        Gate::authorize('view', $order);

        return response()->json(
            $order->routePoints()->get(['sequence', 'latitude', 'longitude'])
        );
    }
}
