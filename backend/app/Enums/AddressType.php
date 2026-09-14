<?php

namespace App\Enums;

enum AddressType: string
{
    case Casa = 'casa';
    case Apartamento = 'apartamento';
    case Hotel = 'hotel';
    case Residencia = 'residencia';
    case Oficina = 'oficina';
    case Otro = 'otro';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
