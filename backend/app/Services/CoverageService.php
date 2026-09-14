<?php

namespace App\Services;

use App\Models\CoverageZone;

/**
 * Validación de cobertura por barrio. Hoy cada zona es un círculo (centro + radio);
 * cuando se active PostGIS se puede reemplazar por ST_Contains sobre polígonos.
 */
final class CoverageService
{
    private const EARTH_RADIUS_M = 6_371_000;

    public static function distanceMeters(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);

        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        return self::EARTH_RADIUS_M * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }

    public static function contains(CoverageZone $zone, float $lat, float $lng): bool
    {
        return self::distanceMeters($zone->center_lat, $zone->center_lng, $lat, $lng) <= $zone->radius_m;
    }
}
