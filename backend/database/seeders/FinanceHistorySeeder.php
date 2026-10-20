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
use Illuminate\Support\Str;

class FinanceHistorySeeder extends Seeder
{
    /** Días de historial: alcanza para comparar el periodo de 90 días con algo. */
    private const DAYS = 120;

    /** Clientes de ejemplo para que el libro de movimientos no repita siempre el mismo nombre. */
    private const CUSTOMERS = [
        'Yesica Mosquera', 'Jhon Palacios', 'Leidy Córdoba', 'Wilmar Rentería',
        'Marelvis Asprilla', 'Duberney Perea', 'Katherine Murillo', 'Yeison Valencia',
    ];

    /**
     * Ventas pasadas de Pollos Nacho (solo en local) para que Finanzas tenga gráficas en la demo.
     * Los volúmenes por día siguen una semilla fija; los platos y clientes de cada pedido varían.
     */
    public function run(): void
    {
        mt_srand(2026);

        $restaurant = Restaurant::where('name', 'Pollos Nacho')->firstOrFail();
        $menu = $restaurant->menuItems()->orderBy('id')->get();
        $zone = CoverageZone::where('name', 'Centro')->firstOrFail();

        $addresses = collect(self::CUSTOMERS)->map(function (string $name, int $i) use ($zone) {
            $customer = User::forceCreate([
                'name' => $name,
                'email' => Str::slug($name, '.').'@demo.co',
                'phone' => '310'.str_pad((string) ($i * 1234567 % 10000000), 7, '0', STR_PAD_LEFT),
                'role' => UserRole::Cliente,
                'password' => Str::random(32),
            ]);

            return $customer->addresses()->create([
                'coverage_zone_id' => $zone->id,
                'latitude' => $zone->center_lat + (mt_rand(-20, 20) / 10000),
                'longitude' => $zone->center_lng + (mt_rand(-20, 20) / 10000),
                'tipo' => AddressType::Casa,
                'detalle' => 'Cliente frecuente.',
                'es_predeterminada' => true,
            ]);
        });

        $now = CarbonImmutable::now(config('domi.business_timezone'));
        $today = $now->startOfDay();

        for ($daysAgo = self::DAYS; $daysAgo >= 0; $daysAgo--) {
            $day = $today->subDays($daysAgo);
            // Más pedidos el fin de semana y una tendencia suave al alza.
            $base = $day->isWeekend() ? 7 : 4;
            $count = max(1, $base + mt_rand(-2, 3) + intdiv(self::DAYS - $daysAgo, 30));

            for ($n = 0; $n < $count; $n++) {
                $at = $day->setTime($this->peakHour(), mt_rand(0, 59));
                // Hoy solo hay ventas hasta la hora actual.
                if ($at->lt($now)) {
                    $this->sale($restaurant, $menu, $addresses->random(), $at);
                }
            }
        }
    }

    /** Horas de almuerzo y cena pesan más, como en un restaurante real. */
    private function peakHour(): int
    {
        $hours = [11, 12, 12, 12, 13, 13, 14, 15, 17, 18, 19, 19, 19, 20, 20, 21];

        return $hours[mt_rand(0, count($hours) - 1)];
    }

    /** @param  Collection<int, MenuItem>  $menu */
    private function sale(Restaurant $restaurant, Collection $menu, Address $address, CarbonImmutable $at): void
    {
        $lines = $menu->random(mt_rand(1, min(2, $menu->count())))->map(fn (MenuItem $item) => [
            'menu_item_id' => $item->id,
            'quantity' => $quantity = mt_rand(1, 4) === 4 ? 2 : 1,
            'unit_price' => $item->price,
            'subtotal' => round($item->price * $quantity, 2),
        ]);

        $fee = OrderService::deliveryFee($restaurant, $address);
        $isOnline = mt_rand(1, 100) <= 35;
        $status = mt_rand(1, 100) <= 6 ? OrderStatus::Cancelado : OrderStatus::Entregado;
        $createdAt = $at->utc();

        $order = Order::forceCreate([
            'user_id' => $address->user_id,
            'restaurant_id' => $restaurant->id,
            'address_id' => $address->id,
            'status' => $status,
            'verification_code' => (string) mt_rand(1000, 9999),
            'total' => $lines->sum('subtotal') + $fee,
            'delivery_fee' => $fee,
            'payment_method' => $isOnline ? 'payu' : 'efectivo',
            'payment_status' => $isOnline ? PaymentStatus::Aprobado : null,
            'paid_at' => $isOnline ? $createdAt : null,
            'created_at' => $createdAt,
            'updated_at' => $createdAt,
        ]);
        $order->items()->createMany($lines->all());
    }
}
