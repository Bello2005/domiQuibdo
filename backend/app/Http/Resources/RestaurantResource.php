<?php

namespace App\Http\Resources;

use App\Models\Restaurant;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Restaurant */
class RestaurantResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'description' => $this->description,
            'category' => $this->category,
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            'address_text' => $this->address_text,
            'phone' => $this->phone,
            // La portada es la primera foto de la galería; si no hay, la URL fija de antes.
            'cover_image_url' => $this->whenLoaded('photos', fn () => $this->photos->first()?->url(), null) ?? $this->cover_image_url,
            'cover_thumb_url' => $this->whenLoaded('photos', fn () => $this->photos->first()?->thumbUrl(), null) ?? $this->cover_image_url,
            'photos' => RestaurantPhotoResource::collection($this->whenLoaded('photos')),
            'rating_avg' => $this->rating_avg,
            'delivery_time_min' => $this->delivery_time_min,
            'is_active' => $this->is_active,
            'menu_items' => MenuItemResource::collection($this->whenLoaded('menuItems')),
        ];
    }
}
