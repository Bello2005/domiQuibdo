<?php

namespace App\Http\Controllers\Api\Admin;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\OrderStatusRequest;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class OrderController extends Controller
{
    public function index(): AnonymousResourceCollection
    {
        return OrderResource::collection(
            Order::with(['restaurant', 'user', 'repartidor'])->withCount('items')->latest()->limit(100)->get()
        );
    }

    public function updateStatus(OrderStatusRequest $request, Order $order): OrderResource
    {
        $data = $request->validated();

        $order->status = OrderStatus::from($data['status']);
        if (array_key_exists('repartidor_id', $data)) {
            $order->repartidor_id = $data['repartidor_id'];
        }
        $order->save();

        return OrderResource::make($order->load(['restaurant', 'user', 'repartidor']));
    }
}
