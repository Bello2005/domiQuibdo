<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['name', 'center_lat', 'center_lng', 'radius_m', 'is_active'])]
class CoverageZone extends Model
{
    protected function casts(): array
    {
        return [
            'center_lat' => 'float',
            'center_lng' => 'float',
            'radius_m' => 'integer',
            'is_active' => 'boolean',
        ];
    }
}
