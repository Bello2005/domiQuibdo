<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\PhotoUploadRequest;
use App\Http\Resources\MenuItemResource;
use App\Http\Resources\RestaurantPhotoResource;
use App\Models\MenuItem;
use App\Models\Restaurant;
use App\Models\RestaurantPhoto;
use App\Services\RestaurantPhotoService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

/** Fotos del negocio y de sus platos; lo usan el dueño (/restaurant) y el admin (/admin). */
class RestaurantPhotoController extends Controller
{
    public function __construct(private RestaurantPhotoService $photos) {}

    public function store(PhotoUploadRequest $request, Restaurant $restaurant): JsonResponse
    {
        Gate::authorize('managePhotos', $restaurant);

        $photo = $this->photos->addPhoto($restaurant, $request->file('photo'));

        return RestaurantPhotoResource::make($photo)->response()->setStatusCode(201);
    }

    public function reorder(Request $request, Restaurant $restaurant): AnonymousResourceCollection
    {
        Gate::authorize('managePhotos', $restaurant);

        $data = $request->validate([
            'ids' => ['required', 'array'],
            'ids.*' => ['integer', 'distinct'],
        ]);
        $this->photos->reorder($restaurant, array_map('intval', $data['ids']));

        return RestaurantPhotoResource::collection($restaurant->photos()->get());
    }

    public function destroy(RestaurantPhoto $photo): JsonResponse
    {
        Gate::authorize('managePhotos', $photo->restaurant);

        $this->photos->deletePhoto($photo);

        return response()->json(status: 204);
    }

    public function storeMenuItemPhoto(PhotoUploadRequest $request, MenuItem $menuItem): MenuItemResource
    {
        Gate::authorize('managePhotos', $menuItem->restaurant);

        return MenuItemResource::make($this->photos->setMenuItemPhoto($menuItem, $request->file('photo')));
    }

    public function destroyMenuItemPhoto(MenuItem $menuItem): MenuItemResource
    {
        Gate::authorize('managePhotos', $menuItem->restaurant);

        return MenuItemResource::make($this->photos->removeMenuItemPhoto($menuItem));
    }
}
