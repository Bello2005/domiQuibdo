<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Models\Address;
use App\Models\MenuItem;
use App\Models\Order;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class OrderService
{
    public function __construct(private readonly MockRouteService $routes) {}

    /**
     * Crea un pedido. Precios y total se calculan aquí desde la base de datos:
     * nunca se confía en montos enviados por el cliente.
     *
     * @param  array{address_id:int, items:list<array{menu_item_id:int, quantity:int}>, payment_method:string, notes?:string|null}  $data
     */
    public function place(User $user, array $data): Order
    {
        $address = $user->addresses()->find($data['address_id']);
        if (! $address) {
            throw ValidationException::withMessages(['address_id' => 'La dirección no pertenece a tu cuenta.']);
        }

        $quantities = collect($data['items'])
            ->mapWithKeys(fn (array $line) => [(int) $line['menu_item_id'] => (int) $line['quantity']]);

        $menuItems = MenuItem::with('restaurant')
            ->whereIn('id', $quantities->keys())
            ->where('is_available', true)
            ->get();

        if ($menuItems->count() !== $quantities->count()) {
            throw ValidationException::withMessages(['items' => 'Algunos productos ya no están disponibles.']);
        }
        if ($menuItems->pluck('restaurant_id')->unique()->count() > 1) {
            throw ValidationException::withMessages(['items' => 'Todos los productos deben ser del mismo restaurante.']);
        }

        $restaurant = $menuItems->first()->restaurant;
        if (! $restaurant->is_active) {
            throw ValidationException::withMessages(['items' => 'El restaurante no está recibiendo pedidos.']);
        }

        return DB::transaction(function () use ($user, $data, $address, $restaurant, $menuItems, $quantities) {
            $lines = $menuItems->map(fn (MenuItem $item) => [
                'menu_item_id' => $item->id,
                'quantity' => $quantities[$item->id],
                'unit_price' => $item->price,
                'subtotal' => round($item->price * $quantities[$item->id], 2),
            ]);

            $fee = self::deliveryFee($restaurant, $address);

            $order = $user->orders()->create([
                'restaurant_id' => $restaurant->id,
                'address_id' => $address->id,
                'status' => OrderStatus::Pendiente,
                'verification_code' => self::newVerificationCode(),
                'total' => $lines->sum('subtotal') + $fee,
                'delivery_fee' => $fee,
                'payment_method' => $data['payment_method'],
                'notes' => $data['notes'] ?? null,
            ]);

            $order->items()->createMany($lines->all());
            $this->routes->generate($order);

            return $order;
        });
    }

    /** Código de 4 dígitos que el cliente entrega al repartidor al recibir. */
    public static function newVerificationCode(): string
    {
        return str_pad((string) random_int(0, 9999), 4, '0', STR_PAD_LEFT);
    }

    /** Tarifa base + valor por km, redondeada a múltiplos de 500 COP. */
    public static function deliveryFee(Restaurant $restaurant, Address $address): float
    {
        $km = CoverageService::distanceMeters(
            $restaurant->latitude, $restaurant->longitude, $address->latitude, $address->longitude,
        ) / 1000;

        return (float) max(3000, ceil((2000 + $km * 1500) / 500) * 500);
    }
}
