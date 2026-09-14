<?php

namespace App\Models;

use App\Enums\AddressType;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['coverage_zone_id', 'latitude', 'longitude', 'tipo', 'detalle', 'es_predeterminada'])]
class Address extends Model
{
    protected function casts(): array
    {
        return [
            'user_id' => 'integer',
            'coverage_zone_id' => 'integer',
            'latitude' => 'float',
            'longitude' => 'float',
            'tipo' => AddressType::class,
            'es_predeterminada' => 'boolean',
        ];
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** @return BelongsTo<CoverageZone, $this> */
    public function zone(): BelongsTo
    {
        return $this->belongsTo(CoverageZone::class, 'coverage_zone_id');
    }

    /** @return HasMany<Order, $this> */
    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }
}
