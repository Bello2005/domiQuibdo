<?php

namespace App\Services;

use App\Models\Order;

/**
 * Sprint 0: genera una ruta simulada restaurante → dirección de entrega.
 * Se reemplaza por posiciones reales vía WebSocket (Reverb) sin tocar `orders`.
 */
final class MockRouteService
{
    /** Desvío lateral máximo, como fracción de la distancia total. */
    private const BEND = 0.12;

    public function generate(Order $order, int $points = 6): void
    {
        $restaurant = $order->restaurant;
        $address = $order->address;

        $fromLat = $restaurant->latitude;
        $fromLng = $restaurant->longitude;
        $dLat = $address->latitude - $fromLat;
        $dLng = $address->longitude - $fromLng;

        $rows = [];
        for ($i = 0; $i < $points; $i++) {
            $t = $i / ($points - 1);
            // Curva suave perpendicular a la recta para que no parezca una línea perfecta.
            $bend = sin(M_PI * $t) * self::BEND;

            $rows[] = [
                'sequence' => $i + 1,
                'latitude' => round($fromLat + $dLat * $t - $dLng * $bend, 7),
                'longitude' => round($fromLng + $dLng * $t + $dLat * $bend, 7),
            ];
        }

        $order->routePoints()->delete();
        $order->routePoints()->createMany($rows);
    }
}
