<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Incident */
class IncidentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'order_id' => $this->order_id,
            'type' => $this->type->value,
            'status' => $this->status->value,
            'message' => $this->message,
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            'created_at' => $this->created_at?->toIso8601String(),
            'resolved_at' => $this->resolved_at?->toIso8601String(),
            'reporter' => $this->whenLoaded('reporter', fn () => [
                'name' => $this->reporter->name,
                'phone' => $this->reporter->phone,
                'role' => $this->reporter->role->value,
            ]),
            'order' => $this->whenLoaded('order', fn () => [
                'id' => $this->order->id,
                'status' => $this->order->status->value,
                'restaurant' => $this->order->relationLoaded('restaurant') ? $this->order->restaurant?->name : null,
            ]),
        ];
    }
}
