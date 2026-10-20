<?php

namespace App\Models;

use App\Services\RestaurantPhotoService;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Foto de la galería de un restaurante; la de menor `position` es la portada. */
#[Fillable(['path', 'thumb_path', 'position'])]
class RestaurantPhoto extends Model
{
    protected function casts(): array
    {
        return [
            'restaurant_id' => 'integer',
            'position' => 'integer',
        ];
    }

    /** @return BelongsTo<Restaurant, $this> */
    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class);
    }

    public function url(): string
    {
        return RestaurantPhotoService::disk()->url($this->path);
    }

    public function thumbUrl(): string
    {
        return RestaurantPhotoService::disk()->url($this->thumb_path);
    }
}
