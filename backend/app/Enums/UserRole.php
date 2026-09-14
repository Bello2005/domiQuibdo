<?php

namespace App\Enums;

enum UserRole: string
{
    case Cliente = 'cliente';
    case Restaurante = 'restaurante';
    case Repartidor = 'repartidor';
    case Admin = 'admin';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
