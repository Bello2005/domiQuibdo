<?php

namespace App\Http\Resources;

use App\Models\MenuItem;
use App\Services\RestaurantPhotoService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin MenuItem */
class MenuItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'restaurant_id' => $this->restaurant_id,
            'name' => $this->name,
            'description' => $this->description,
            'price' => $this->price,
            // Foto subida por el restaurante; si no hay, la URL externa (si existe).
            'image_url' => $this->image_path ? RestaurantPhotoService::disk()->url($this->image_path) : $this->image_url,
            'image_thumb_url' => $this->image_thumb_path ? RestaurantPhotoService::disk()->url($this->image_thumb_path) : $this->image_url,
            'is_available' => $this->is_available,
        ];
    }
}
