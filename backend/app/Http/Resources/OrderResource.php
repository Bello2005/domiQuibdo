<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Order */
class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $isOwner = $request->user()?->id === $this->user_id;

        return [
            'id' => $this->id,
            'status' => $this->status->value,
            'status_label' => $this->status->label(),
            'subtotal' => $this->total - $this->delivery_fee,
            'delivery_fee' => $this->delivery_fee,
            'total' => $this->total,
            'payment_method' => $this->payment_method,
            'notes' => $this->notes,
            // Seguridad: solo el cliente dueño ve el código; el repartidor debe pedírselo en la puerta.
            'verification_code' => $this->when($isOwner, fn () => $this->verification_code),
            'created_at' => $this->created_at?->toIso8601String(),
            'restaurant' => RestaurantResource::make($this->whenLoaded('restaurant')),
            'address' => AddressResource::make($this->whenLoaded('address')),
            'items' => OrderItemResource::collection($this->whenLoaded('items')),
            'items_count' => $this->whenCounted('items'),
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
