<?php

namespace App\Policies;

use App\Enums\UserRole;
use App\Models\Restaurant;
use App\Models\User;

class RestaurantPolicy
{
    /** Solo el usuario dueño (rol restaurante) gestiona su negocio y su menú. */
    public function update(User $user, Restaurant $restaurant): bool
    {
        return $user->hasRole(UserRole::Restaurante) && $restaurant->user_id === $user->id;
    }

    /** Las fotos las gestiona el dueño del negocio o un administrador. */
    public function managePhotos(User $user, Restaurant $restaurant): bool
    {
        return $user->hasRole(UserRole::Admin) || $this->update($user, $restaurant);
    }
}
