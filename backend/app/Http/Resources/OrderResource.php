<?php

namespace App\Http\Resources;

use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Order */
class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $isOwner = $request->user()?->id === $this->user_id;

        return [
            'id' => $this->id,
            'status' => $this->status->value,
            'status_label' => $this->status->label(),
            'subtotal' => $this->foodSubtotal(),
            'delivery_fee' => $this->delivery_fee,
            'service_fee' => $this->service_fee,
            'payment_fee' => $this->payment_fee,
            'total' => $this->total,
            'payment_method' => $this->payment_method,
            'payment_status' => $this->payment_status?->value,
            'payment_status_label' => $this->payment_status?->label(),
            'paid_at' => $this->paid_at?->toIso8601String(),
            'notes' => $this->notes,
            // Seguridad: solo el cliente dueño ve el código; el repartidor debe pedírselo en la puerta.
            'verification_code' => $this->when($isOwner, fn () => $this->verification_code),
            'created_at' => $this->created_at?->toIso8601String(),
            'restaurant' => RestaurantResource::make($this->whenLoaded('restaurant')),
            'address' => AddressResource::make($this->whenLoaded('address')),
            'items' => OrderItemResource::collection($this->whenLoaded('items')),
            'items_count' => $this->whenCounted('items'),
            'repartidor_id' => $this->repartidor_id,
            'repartidor' => $this->whenLoaded('repartidor', fn () => [
                'name' => $this->repartidor->name,
                'phone' => $this->repartidor->phone,
            ]),
            'customer' => $this->when(! $isOwner && $this->relationLoaded('user'), fn () => [
                'name' => $this->user->name,
                'phone' => $this->user->phone,
            ]),
        ];
    }
}
