<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\MenuItemRequest;
use App\Http\Resources\MenuItemResource;
use App\Models\MenuItem;
use App\Models\Restaurant;
use Illuminate\Http\JsonResponse;

class MenuItemController extends Controller
{
    public function store(MenuItemRequest $request, Restaurant $restaurant): JsonResponse
    {
        $item = $restaurant->menuItems()->create($request->validated() + ['is_available' => true]);

        return MenuItemResource::make($item)->response()->setStatusCode(201);
    }

    public function update(MenuItemRequest $request, MenuItem $menuItem): MenuItemResource
    {
        $menuItem->update($request->validated());

        return MenuItemResource::make($menuItem);
    }

    public function destroy(MenuItem $menuItem): JsonResponse
    {
        $menuItem->delete();

        return response()->json(status: 204);
    }
}
