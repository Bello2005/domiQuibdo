<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Catálogo (zonas, restaurantes y menús) en todos los entornos. Las cuentas de prueba
     * (contraseña "password") y su pedido solo existen en local y en los tests: nunca en producción.
     */
    public function run(): void
    {
        $withTestAccounts = app()->environment(['local', 'testing']);

        $this->call(array_values(array_filter([
            CoverageZoneSeeder::class,
            $withTestAccounts ? UserSeeder::class : null,
            RestaurantSeeder::class,
            $withTestAccounts ? DemoOrderSeeder::class : null,
            // Ventas pasadas para la demo de Finanzas; los tests arman sus propios pedidos.
            app()->environment('local') ? FinanceHistorySeeder::class : null,
        ])));
    }
}
