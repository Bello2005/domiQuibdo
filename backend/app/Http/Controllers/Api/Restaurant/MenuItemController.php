<?php

namespace App\Http\Controllers\Api\Restaurant;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\MenuItemRequest;
use App\Http\Resources\MenuItemResource;
use App\Models\MenuItem;
use App\Models\Restaurant;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Gate;

class MenuItemController extends Controller
{
    public function store(MenuItemRequest $request, Restaurant $restaurant): JsonResponse
    {
        Gate::authorize('update', $restaurant);

        $item = $restaurant->menuItems()->create($request->validated() + ['is_available' => true]);

        return MenuItemResource::make($item)->response()->setStatusCode(201);
    }

    public function update(MenuItemRequest $request, MenuItem $menuItem): MenuItemResource
    {
        Gate::authorize('update', $menuItem->restaurant);

        $menuItem->update($request->validated());

        return MenuItemResource::make($menuItem);
    }

    public function destroy(MenuItem $menuItem): JsonResponse
    {
        Gate::authorize('update', $menuItem->restaurant);

        $menuItem->delete();

        return response()->json(status: 204);
    }
}
