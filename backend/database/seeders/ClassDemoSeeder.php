<?php

namespace Database\Seeders;

use App\Enums\AddressType;
use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Enums\UserRole;
use App\Models\Address;
use App\Models\CoverageZone;
use App\Models\MenuItem;
use App\Models\Order;
use App\Models\Restaurant;
use App\Models\User;
use App\Services\OrderService;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * Datos para la demo de clase: una cuenta por restaurante, clientes de ejemplo y su historial
 * de pedidos en fechas fijas (misma semilla), para que Finanzas tenga gráficas en todos los
 * negocios. No se corre en DatabaseSeeder; se ejecuta a mano y se puede repetir:
 *
 *     php artisan db:seed --class=ClassDemoSeeder
 *
 * Al repetirlo, borra y regenera solo los pedidos de los clientes de este seeder.
 */
class ClassDemoSeeder extends Seeder
{
    /** Todas las cuentas de la demo usan la misma clave que las cuentas de prueba del login. */
    public const PASSWORD = 'password';

    /** Días de historial: cubre el periodo de 90 días y parte del anterior para comparar. */
    private const DAYS = 120;

    /**
     * Dueño de cada restaurante y cuántos pedidos tiene en un día normal (popularidad).
     * Pollos Nacho conserva la cuenta de prueba del login (restaurante@demo.co).
     *
     * @var array<string, array{0: string, 1: string, 2: int}>
     */
    public const RESTAURANTS = [
        'Al Aire Rooftop Quibdó' => ['alaire@demo.co', 'Carolina Rivas', 2],
        'Brisas Del Atrato Restaurante Bar' => ['brisas@demo.co', 'Hernán Moreno', 3],
        'Restaurante Maria Mulata' => ['mariamulata@demo.co', 'María Mosquera', 2],
        'Boga Restaurante' => ['boga@demo.co', 'Andrés Lozano', 2],
        'Al Carbón Parrilla Bar' => ['alcarbon@demo.co', 'Fredy Cuesta', 3],
        'La paila de mi abuela' => ['lapaila@demo.co', 'Ana Lucía Palacios', 3],
        'Pollos Nacho' => ['restaurante@demo.co', 'Restaurante Demo', 6],
        'Frisby CC El Caraño' => ['frisby@demo.co', 'Laura Hinestroza', 5],
        'Helados Makerule' => ['makerule@demo.co', 'Diana Valoyes', 4],
        'Nativhos' => ['nativhos@demo.co', 'Kevin Asprilla', 2],
        'Panadería Las Delicias Del Tambo' => ['delicias@demo.co', 'Rosa Emilia Ibargüen', 3],
        'ChocQuiBurger Quibdó' => ['chocquiburger@demo.co', 'Jair Mena', 5],
    ];

    /** @var array<string, array{0: string, 1: string}> correo => [nombre, barrio] */
    public const CUSTOMERS = [
        'yesica.mosquera@demo.co' => ['Yesica Mosquera', 'Centro'],
        'jhon.palacios@demo.co' => ['Jhon Palacios', 'Cristo Rey'],
        'leidy.cordoba@demo.co' => ['Leidy Córdoba', 'Pandeyuca'],
        'wilmar.renteria@demo.co' => ['Wilmar Rentería', 'Kennedy'],
        'marelvis.asprilla@demo.co' => ['Marelvis Asprilla', 'La Esmeralda'],
        'duberney.perea@demo.co' => ['Duberney Perea', 'Yesca Grande'],
        'katherine.murillo@demo.co' => ['Katherine Murillo', 'Roma'],
        'yeison.valencia@demo.co' => ['Yeison Valencia', 'Niño Jesús'],
        'sandra.lemos@demo.co' => ['Sandra Lemos', 'Tomás Pérez'],
        'cristian.mena@demo.co' => ['Cristian Mena', 'Los Ángeles'],
        'paola.cuesta@demo.co' => ['Paola Cuesta', 'Jardín'],
        'robinson.ibarguen@demo.co' => ['Robinson Ibargüen', 'San Vicente'],
    ];

    public function run(): void
    {
        mt_srand(20261020);
        $password = Hash::make(self::PASSWORD);

        DB::transaction(function () use ($password) {
            $this->owners($password);
            $addresses = $this->customers($password);
            $courier = User::where('email', 'repartidor@demo.co')->first();

            Order::whereIn('user_id', $addresses->pluck('user_id'))->delete();

            foreach (self::RESTAURANTS as $name => [, , $perDay]) {
                $restaurant = Restaurant::where('name', $name)->first();
                $menu = $restaurant?->menuItems()->where('is_available', true)->orderBy('id')->get();
                if ($restaurant && $menu->isNotEmpty()) {
                    $this->history($restaurant, $menu, $addresses, $perDay, $courier);
                }
            }
        });
    }

    private function owners(string $password): void
    {
        foreach (self::RESTAURANTS as $restaurant => [$email, $name]) {
            $owner = $this->account($email, $name, UserRole::Restaurante, $password);
            Restaurant::where('name', $restaurant)->update(['user_id' => $owner->id]);
        }
    }

    /** @return \Illuminate\Support\Collection<int, Address> una dirección por cliente */
    private function customers(string $password): \Illuminate\Support\Collection
    {
        return collect(self::CUSTOMERS)->map(function (array $data, string $email) use ($password) {
            [$name, $zoneName] = $data;
            $customer = $this->account($email, $name, UserRole::Cliente, $password);
            $zone = CoverageZone::where('name', $zoneName)->first() ?? CoverageZone::firstOrFail();

            return $customer->addresses()->firstOrCreate(
                ['tipo' => AddressType::Casa],
                [
                    'coverage_zone_id' => $zone->id,
                    'latitude' => $zone->center_lat + mt_rand(-15, 15) / 10000,
                    'longitude' => $zone->center_lng + mt_rand(-15, 15) / 10000,
                    'detalle' => "Barrio {$zone->name}.",
                    'es_predeterminada' => true,
                ],
            );
        })->values();
    }

    /**
     * Pedidos de los últimos días: más los fines de semana y en almuerzo y cena, con una leve
     * subida en el último mes. Hoy quedan algunos en curso para ver la pestaña de Pedidos.
     *
     * @param  Collection<int, MenuItem>  $menu
     * @param  \Illuminate\Support\Collection<int, Address>  $addresses
     */
    private function history(Restaurant $restaurant, Collection $menu, $addresses, int $perDay, ?User $courier): void
    {
        $now = CarbonImmutable::now(config('domi.business_timezone'));
        $today = $now->startOfDay();

        for ($daysAgo = self::DAYS; $daysAgo >= 0; $daysAgo--) {
            $day = $today->subDays($daysAgo);
            $count = $perDay + ($day->isWeekend() ? 2 : 0) + mt_rand(-1, 2) + ($daysAgo < 30 ? 1 : 0);

            for ($n = 0; $n < max(0, $count); $n++) {
                $at = $day->setTime($this->peakHour(), mt_rand(0, 59));
                if ($at->gte($now)) {
                    continue;
                }
                $status = match (true) {
                    $daysAgo === 0 && $now->diffInMinutes($at, true) < 90 => [
                        OrderStatus::Pendiente, OrderStatus::Confirmado, OrderStatus::Preparando, OrderStatus::EnCamino,
                    ][mt_rand(0, 3)],
                    mt_rand(1, 100) <= 6 => OrderStatus::Cancelado,
                    default => OrderStatus::Entregado,
                };
                $this->order($restaurant, $menu, $addresses->random(), $at, $status, $courier);
            }
        }
    }

    /** @param  Collection<int, MenuItem>  $menu */
    private function order(Restaurant $restaurant, Collection $menu, Address $address, CarbonImmutable $at, OrderStatus $status, ?User $courier): void
    {
        $lines = $menu->random(mt_rand(1, min(3, $menu->count())))->map(fn (MenuItem $item) => [
            'menu_item_id' => $item->id,
            'quantity' => $quantity = mt_rand(1, 5) === 5 ? 2 : 1,
            'unit_price' => $item->price,
            'subtotal' => round($item->price * $quantity, 2),
        ]);

        $isOnline = mt_rand(1, 100) <= 40;
        $method = $isOnline ? 'payu' : 'efectivo';
        $deliveryFee = OrderService::deliveryFee($restaurant, $address);
        $serviceFee = OrderService::serviceFee();
        $base = $lines->sum('subtotal') + $deliveryFee + $serviceFee;
        $paymentFee = OrderService::paymentFee($base, $method);
        $createdAt = $at->utc();
        $withCourier = in_array($status, [OrderStatus::EnCamino, OrderStatus::Entregado], true);

        $order = Order::forceCreate([
            'user_id' => $address->user_id,
            'restaurant_id' => $restaurant->id,
            'address_id' => $address->id,
            'repartidor_id' => $withCourier ? $courier?->id : null,
            'status' => $status,
            'verification_code' => (string) mt_rand(1000, 9999),
            'total' => $base + $paymentFee,
            'delivery_fee' => $deliveryFee,
            'service_fee' => $serviceFee,
            'payment_fee' => $paymentFee,
            'payment_method' => $method,
            'payment_status' => $isOnline ? PaymentStatus::Aprobado : null,
            'paid_at' => $isOnline ? $createdAt : null,
            'created_at' => $createdAt,
            'updated_at' => $createdAt->addMinutes(mt_rand(25, 55)),
        ]);
        $order->items()->createMany($lines->all());
    }

    /** Almuerzo y cena pesan más, como en un restaurante real. */
    private function peakHour(): int
    {
        $hours = [8, 10, 11, 12, 12, 12, 13, 13, 14, 15, 17, 18, 19, 19, 19, 20, 20, 21];

        return $hours[mt_rand(0, count($hours) - 1)];
    }

    /** Crea o actualiza la cuenta (el rol no es asignable en masa, por eso forceFill). */
    private function account(string $email, string $name, UserRole $role, string $password): User
    {
        $user = User::firstOrNew(['email' => $email]);
        $user->forceFill(['name' => $name, 'phone' => $this->phone($email), 'role' => $role, 'password' => $password])->save();

        return $user;
    }

    /** Teléfono estable por correo, para que repetir el seeder no lo cambie. */
    private function phone(string $email): string
    {
        return '31'.str_pad((string) (crc32($email) % 100000000), 8, '0', STR_PAD_LEFT);
    }
}
