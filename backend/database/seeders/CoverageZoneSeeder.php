<?php

namespace Database\Seeders;

use App\Models\CoverageZone;
use Illuminate\Database\Seeder;

class CoverageZoneSeeder extends Seeder
{
    /**
     * Barrios de Quibdó con cobertura. Centros y radios APROXIMADOS (Sprint 0);
     * se deben ajustar con polígonos reales antes de producción.
     */
    public function run(): void
    {
        $zones = [
            ['Centro', 5.6935, -76.6600, 700],
            ['Cristo Rey', 5.6900, -76.6565, 400],
            ['Pandeyuca', 5.7010, -76.6590, 450],
            ['Kennedy', 5.6990, -76.6530, 500],
            ['La Esmeralda', 5.6970, -76.6480, 450],
            ['Yesca Grande', 5.6880, -76.6520, 500],
            ['Roma', 5.6845, -76.6560, 450],
            ['Niño Jesús', 5.6860, -76.6470, 500],
            ['Tomás Pérez', 5.6820, -76.6505, 450],
            ['Los Ángeles', 5.6920, -76.6425, 650],
            ['Jardín', 5.7040, -76.6490, 500],
            ['San Vicente', 5.7060, -76.6560, 500],
        ];

        foreach ($zones as [$name, $lat, $lng, $radius]) {
            CoverageZone::updateOrCreate(
                ['name' => $name],
                ['center_lat' => $lat, 'center_lng' => $lng, 'radius_m' => $radius, 'is_active' => true],
            );
        }
    }
}
