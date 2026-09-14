<?php

namespace Database\Seeders;

use App\Enums\AddressType;
use App\Enums\UserRole;
use App\Models\CoverageZone;
use App\Models\User;
use Illuminate\Database\Seeder;

class UserSeeder extends Seeder
{
    /**
     * Cuentas de demostración. Contraseña para todas: "password".
     */
    public function run(): void
    {
        $accounts = [
            ['Cliente Demo', 'cliente@demo.co', '3001112233', UserRole::Cliente],
            ['Repartidor Demo', 'repartidor@demo.co', '3004445566', UserRole::Repartidor],
            ['Restaurante Demo', 'restaurante@demo.co', '3007778899', UserRole::Restaurante],
            ['Admin Demo', 'admin@demo.co', '3000000000', UserRole::Admin],
        ];

        foreach ($accounts as [$name, $email, $phone, $role]) {
            User::forceCreate([
                'name' => $name,
                'email' => $email,
                'phone' => $phone,
                'role' => $role,
                'password' => 'password',
                'email_verified_at' => now(),
            ]);
        }

        User::where('email', 'cliente@demo.co')->first()->addresses()->create([
            'coverage_zone_id' => CoverageZone::where('name', 'Centro')->value('id'),
            'latitude' => 5.6948,
            'longitude' => -76.6588,
            'tipo' => AddressType::Casa,
            'detalle' => 'Casa de dos pisos, portón verde. Cerca al parque Centenario.',
            'es_predeterminada' => true,
        ]);
    }
}
