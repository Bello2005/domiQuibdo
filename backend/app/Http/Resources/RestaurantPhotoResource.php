<?php

namespace App\Http\Resources;

use App\Models\RestaurantPhoto;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin RestaurantPhoto */
class RestaurantPhotoResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'url' => $this->url(),
            'thumb_url' => $this->thumbUrl(),
            'position' => $this->position,
        ];
    }
}
