<?php

namespace Database\Seeders;

use App\Enums\OrderStatus;
use App\Models\Restaurant;
use App\Models\User;
use App\Services\OrderService;
use Illuminate\Database\Seeder;

class DemoOrderSeeder extends Seeder
{
    /**
     * Un pedido ya "en camino" para abrir el tracking de inmediato en la demo.
     */
    public function run(OrderService $orders): void
    {
        $cliente = User::where('email', 'cliente@demo.co')->firstOrFail();
        $repartidor = User::where('email', 'repartidor@demo.co')->firstOrFail();
        $menu = Restaurant::where('name', 'Pollos Nacho')->firstOrFail()->menuItems()->orderBy('id')->take(2)->get();

        $order = $orders->place($cliente, [
            'address_id' => $cliente->addresses()->value('id'),
            'items' => $menu->map(fn ($item) => ['menu_item_id' => $item->id, 'quantity' => 1])->all(),
            'payment_method' => 'efectivo',
            'notes' => 'Pedido de demostración.',
        ]);

        $order->update(['status' => OrderStatus::EnCamino, 'repartidor_id' => $repartidor->id]);
    }
}
