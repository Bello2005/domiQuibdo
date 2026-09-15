<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class AdminController extends Controller
{
    public function orders(Request $request): AnonymousResourceCollection
    {
        abort_unless($request->user()->hasRole(UserRole::Admin), 403);

        return OrderResource::collection(
            Order::with(['restaurant', 'user', 'repartidor'])->withCount('items')->latest()->limit(100)->get()
        );
    }
}
