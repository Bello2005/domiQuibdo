<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderItem;
use Carbon\CarbonImmutable;
use Illuminate\Support\Collection;

/**
 * Contabilidad del restaurante a partir de sus pedidos.
 *
 * - Venta: pedido entregado. Lo cancelado se reporta aparte y no suma.
 * - Venta bruta: comida (total sin domicilio). El domicilio es del repartidor.
 * - Comisión: porcentaje de DomiQuibdó sobre la venta bruta (`domi.commission_rate`).
 * - Ganancia neta: venta bruta − comisión.
 *
 * Los días y horas se agrupan en la zona horaria del negocio, no en UTC.
 */
final class RestaurantFinanceService
{
    /** Movimientos máximos que se devuelven en el libro del periodo. */
    private const MOVEMENTS_LIMIT = 100;

    public static function commissionRate(): float
    {
        return (float) config('domi.commission_rate');
    }

    /**
     * Desglose contable de un pedido. Solo un pedido entregado genera venta.
     *
     * @return array{subtotal: float, delivery_fee: float, total: float, commission_rate: float, commission: float, net: float, counts_as_sale: bool}
     */
    public static function breakdown(Order $order): array
    {
        $subtotal = round($order->total - $order->delivery_fee, 2);
        $isSale = $order->status === OrderStatus::Entregado;
        $commission = $isSale ? round($subtotal * self::commissionRate(), 2) : 0.0;

        return [
            'subtotal' => $subtotal,
            'delivery_fee' => $order->delivery_fee,
            'total' => $order->total,
            'commission_rate' => self::commissionRate(),
            'commission' => $commission,
            'net' => $isSale ? round($subtotal - $commission, 2) : 0.0,
            'counts_as_sale' => $isSale,
        ];
    }

    /** Número de comprobante estable y legible: DQ-000123. */
    public static function receiptNumber(Order $order): string
    {
        return 'DQ-'.str_pad((string) $order->id, 6, '0', STR_PAD_LEFT);
    }

    /**
     * Reporte de los últimos `$days` días (incluido hoy) comparado con el periodo anterior.
     *
     * @param  Collection<int, int>  $restaurantIds
     * @return array<string, mixed>
     */
    public function report(Collection $restaurantIds, int $days): array
    {
        $timezone = config('domi.business_timezone');
        $to = CarbonImmutable::now($timezone)->endOfDay();
        $from = $to->subDays($days - 1)->startOfDay();
        $previousFrom = $from->subDays($days);

        $orders = Order::with(['items.menuItem', 'user'])
            ->whereIn('restaurant_id', $restaurantIds)
            ->whereIn('status', [OrderStatus::Entregado, OrderStatus::Cancelado])
            ->whereBetween('created_at', [$previousFrom->utc(), $to->utc()])
            ->latest()
            ->get()
            ->each(fn (Order $order) => $order->setAttribute('local_at', $order->created_at->setTimezone($timezone)));

        [$current, $previous] = $orders->partition(fn (Order $order) => $order->local_at->gte($from));
        $sales = $current->where('status', OrderStatus::Entregado);

        return [
            'period' => [
                'days' => $days,
                'from' => $from->toDateString(),
                'to' => $to->toDateString(),
                'timezone' => $timezone,
            ],
            'commission_rate' => self::commissionRate(),
            'summary' => $this->summary($current),
            'previous' => $this->summary($previous),
            'daily' => $this->daily($sales, $from, $days),
            'hourly' => $this->hourly($sales),
            'payment_methods' => $this->paymentMethods($sales),
            'top_dishes' => $this->topDishes($sales),
            'movements' => $current->take(self::MOVEMENTS_LIMIT)->map(fn (Order $order) => [
                'order_id' => $order->id,
                'receipt_number' => self::receiptNumber($order),
                'created_at' => $order->created_at->toIso8601String(),
                'customer' => $order->user?->name,
                'status' => $order->status->value,
                'status_label' => $order->status->label(),
                'payment_method' => $order->payment_method,
                'items_count' => $order->items->sum('quantity'),
                ...self::breakdown($order),
            ])->values()->all(),
        ];
    }

    /**
     * @param  Collection<int, Order>  $orders
     * @return array<string, float|int>
     */
    private function summary(Collection $orders): array
    {
        $sales = $orders->where('status', OrderStatus::Entregado);
        $cancelled = $orders->where('status', OrderStatus::Cancelado);
        $breakdowns = $sales->map(fn (Order $order) => self::breakdown($order));
        $gross = round($breakdowns->sum('subtotal'), 2);

        return [
            'gross_sales' => $gross,
            'commission' => round($breakdowns->sum('commission'), 2),
            'net_earnings' => round($breakdowns->sum('net'), 2),
            'orders' => $sales->count(),
            'avg_ticket' => $sales->isEmpty() ? 0.0 : round($gross / $sales->count(), 2),
            'items_sold' => (int) $sales->sum(fn (Order $order) => $order->items->sum('quantity')),
            'delivery_fees' => round($sales->sum('delivery_fee'), 2),
            'cancelled_orders' => $cancelled->count(),
            'cancelled_amount' => round($cancelled->sum(fn (Order $order) => $order->total - $order->delivery_fee), 2),
        ];
    }

    /**
     * Una fila por día del periodo, también los días sin ventas (la gráfica no salta fechas).
     *
     * @param  Collection<int, Order>  $sales
     * @return list<array{date: string, gross: float, net: float, orders: int}>
     */
    private function daily(Collection $sales, CarbonImmutable $from, int $days): array
    {
        $byDay = $sales->groupBy(fn (Order $order) => $order->local_at->toDateString());

        return collect(range(0, $days - 1))->map(function (int $offset) use ($from, $byDay) {
            $date = $from->addDays($offset)->toDateString();
            $breakdowns = collect($byDay->get($date, []))->map(fn (Order $order) => self::breakdown($order));

            return [
                'date' => $date,
                'gross' => round($breakdowns->sum('subtotal'), 2),
                'net' => round($breakdowns->sum('net'), 2),
                'orders' => $breakdowns->count(),
            ];
        })->all();
    }

    /**
     * @param  Collection<int, Order>  $sales
     * @return list<array{hour: int, orders: int, gross: float}>
     */
    private function hourly(Collection $sales): array
    {
        $byHour = $sales->groupBy(fn (Order $order) => $order->local_at->hour);

        return collect(range(0, 23))->map(fn (int $hour) => [
            'hour' => $hour,
            'orders' => count($byHour->get($hour, [])),
            'gross' => round(collect($byHour->get($hour, []))->sum(fn (Order $order) => $order->total - $order->delivery_fee), 2),
        ])->all();
    }

    /**
     * @param  Collection<int, Order>  $sales
     * @return list<array{method: string, orders: int, amount: float}>
     */
    private function paymentMethods(Collection $sales): array
    {
        return collect(config('domi.payment_methods'))->map(fn (string $method) => [
            'method' => $method,
            'orders' => $sales->where('payment_method', $method)->count(),
            'amount' => round($sales->where('payment_method', $method)->sum(fn (Order $order) => $order->total - $order->delivery_fee), 2),
        ])->all();
    }

    /**
     * @param  Collection<int, Order>  $sales
     * @return list<array{name: string, quantity: int, revenue: float}>
     */
    private function topDishes(Collection $sales): array
    {
        return $sales->flatMap(fn (Order $order) => $order->items)
            ->groupBy('menu_item_id')
            ->map(fn (Collection $lines) => [
                'name' => $lines->first()->menuItem?->name ?? 'Plato eliminado',
                'quantity' => (int) $lines->sum('quantity'),
                'revenue' => round($lines->sum(fn (OrderItem $line) => $line->subtotal), 2),
            ])
            ->sortByDesc('revenue')
            ->take(5)
            ->values()
            ->all();
    }
}
