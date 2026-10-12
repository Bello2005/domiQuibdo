<?php

namespace App\Services;

use App\Models\Order;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Recorrido por calles restaurante → dirección de entrega, calculado con un servidor OSRM.
 * Si el servicio no está configurado o no responde, se guarda la línea recta: nunca se inventa una ruta.
 */
final class DeliveryRouteService
{
    /** Máximo de puntos guardados por pedido (la geometría de OSRM puede traer cientos). */
    private const MAX_POINTS = 120;

    public function generate(Order $order): void
    {
        $from = [$order->restaurant->latitude, $order->restaurant->longitude];
        $to = [$order->address->latitude, $order->address->longitude];

        $points = $this->roadRoute($from, $to) ?? [$from, $to];

        $rows = [];
        foreach ($points as $i => [$latitude, $longitude]) {
            $rows[] = ['sequence' => $i + 1, 'latitude' => round($latitude, 7), 'longitude' => round($longitude, 7)];
        }

        $order->routePoints()->delete();
        $order->routePoints()->createMany($rows);
    }

    /**
     * @param  array{0: float, 1: float}  $from
     * @param  array{0: float, 1: float}  $to
     * @return list<array{0: float, 1: float}>|null
     */
    private function roadRoute(array $from, array $to): ?array
    {
        $baseUrl = config('domi.routing_url');
        if (! $baseUrl) {
            return null;
        }

        try {
            $response = Http::timeout(4)->get(sprintf(
                '%s/route/v1/driving/%F,%F;%F,%F',
                rtrim($baseUrl, '/'), $from[1], $from[0], $to[1], $to[0],
            ), ['overview' => 'full', 'geometries' => 'geojson']);

            $coordinates = $response->json('routes.0.geometry.coordinates');
            if (! $response->successful() || $response->json('code') !== 'Ok' || ! is_array($coordinates) || count($coordinates) < 2) {
                return null;
            }
        } catch (Throwable $e) {
            Log::warning('No se pudo calcular la ruta por calles', ['error' => $e->getMessage()]);

            return null;
        }

        // GeoJSON viene como [lng, lat].
        $points = array_map(fn (array $c) => [(float) $c[1], (float) $c[0]], $coordinates);

        return self::downsample($points, self::MAX_POINTS);
    }

    /**
     * Reduce la cantidad de puntos conservando siempre el primero y el último.
     *
     * @param  list<array{0: float, 1: float}>  $points
     * @return list<array{0: float, 1: float}>
     */
    private static function downsample(array $points, int $max): array
    {
        $count = count($points);
        if ($count <= $max) {
            return $points;
        }

        $result = [];
        for ($i = 0; $i < $max; $i++) {
            $result[] = $points[(int) round($i * ($count - 1) / ($max - 1))];
        }

        return $result;
    }
}
