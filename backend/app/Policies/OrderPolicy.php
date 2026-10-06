<?php

namespace App\Policies;

use App\Enums\OrderStatus;
use App\Enums\UserRole;
use App\Models\Order;
use App\Models\User;

class OrderPolicy
{
    public function view(User $user, Order $order): bool
    {
        return $user->id === $order->user_id
            || $user->hasRole(UserRole::Admin)
            || $this->manage($user, $order)
            || $this->deliver($user, $order);
    }

    public function create(User $user): bool
    {
        return $user->hasRole(UserRole::Cliente);
    }

    /**
     * Un repartidor puede gestionar pedidos libres o los que ya tiene asignados.
     */
    public function deliver(User $user, Order $order): bool
    {
        return $user->hasRole(UserRole::Repartidor)
            && ($order->repartidor_id === null || $order->repartidor_id === $user->id);
    }

    /** El restaurante dueño gestiona los pedidos de su negocio. */
    public function manage(User $user, Order $order): bool
    {
        return $user->hasRole(UserRole::Restaurante)
            && $order->restaurant()->where('user_id', $user->id)->exists();
    }

    /** El cliente solo cancela mientras el restaurante no haya confirmado el pedido. */
    public function cancel(User $user, Order $order): bool
    {
        return $user->id === $order->user_id && $order->status === OrderStatus::Pendiente;
    }
}
