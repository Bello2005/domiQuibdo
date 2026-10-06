<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Models\CourierLocation;
use App\Models\Order;

/**
 * Posición en vivo del repartidor y ETA. El ETA se calcula con la distancia real al destino
 * y la velocidad reportada (o una velocidad urbana en moto si el GPS no la entrega).
 */
final class TrackingService
{
    /** Una posición más vieja que esto se considera "sin señal". */
    public const LIVE_WINDOW_SECONDS = 90;

    private const DEFAULT_SPEED_MPS = 5.5; // ~20 km/h en ciudad

    private const MIN_SPEED_MPS = 2.0;

    /**
     * @return array<string, mixed>
     */
    public function snapshot(Order $order): array
    {
        $empty = [
            'live' => false, 'latitude' => null, 'longitude' => null, 'heading' => null,
            'speed_mps' => null, 'recorded_at' => null, 'distance_m' => null, 'eta_min' => null,
        ];

        // Fuera de "en camino" no se expone la ubicación del repartidor (privacidad).
        if ($order->status !== OrderStatus::EnCamino) {
            return $empty;
        }

        /** @var CourierLocation|null $last */
        $last = $order->courierLocations()->latest('recorded_at')->latest('id')->first();
        if (! $last) {
            return $empty;
        }

        $address = $order->address;
        $distance = CoverageService::distanceMeters($last->latitude, $last->longitude, $address->latitude, $address->longitude);
        $speed = max(self::MIN_SPEED_MPS, $last->speed_mps ?: self::DEFAULT_SPEED_MPS);

        return [
            'live' => $last->recorded_at->diffInSeconds(now(), true) <= self::LIVE_WINDOW_SECONDS,
            'latitude' => $last->latitude,
            'longitude' => $last->longitude,
            'heading' => $last->heading,
            'speed_mps' => $last->speed_mps,
            'recorded_at' => $last->recorded_at->toIso8601String(),
            'distance_m' => (int) round($distance),
            'eta_min' => max(1, (int) ceil($distance / $speed / 60)),
        ];
    }
}
