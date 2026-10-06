<?php

namespace App\Enums;

enum IncidentType: string
{
    case Sos = 'sos';
    case Problema = 'problema';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
