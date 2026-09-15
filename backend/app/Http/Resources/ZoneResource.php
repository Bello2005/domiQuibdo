<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\CoverageZone */
class ZoneResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'center_lat' => $this->center_lat,
            'center_lng' => $this->center_lng,
            'radius_m' => $this->radius_m,
            'is_active' => $this->is_active,
        ];
    }
}
