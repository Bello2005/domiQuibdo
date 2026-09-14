<?php

namespace App\Models;

use App\Enums\OrderStatus;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable([
    'restaurant_id', 'address_id', 'repartidor_id', 'status', 'verification_code',
    'total', 'delivery_fee', 'payment_method', 'notes',
])]
// El código nunca se serializa por defecto; OrderResource lo expone solo al cliente dueño.
#[Hidden(['verification_code'])]
class Order extends Model
{
    public const DETAIL_RELATIONS = ['restaurant', 'address.zone', 'items.menuItem', 'repartidor', 'user'];

    protected function casts(): array
    {
        return [
            'user_id' => 'integer',
            'repartidor_id' => 'integer',
            'status' => OrderStatus::class,
            'total' => 'float',
            'delivery_fee' => 'float',
        ];
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** @return BelongsTo<User, $this> */
    public function repartidor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'repartidor_id');
    }

    /** @return BelongsTo<Restaurant, $this> */
    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class);
    }

    /** @return BelongsTo<Address, $this> */
    public function address(): BelongsTo
    {
        return $this->belongsTo(Address::class);
    }

    /** @return HasMany<OrderItem, $this> */
    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    /** @return HasMany<DeliveryMockRoutePoint, $this> */
    public function routePoints(): HasMany
    {
        return $this->hasMany(DeliveryMockRoutePoint::class)->orderBy('sequence');
    }
}
