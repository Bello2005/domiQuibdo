<?php

namespace App\Enums;

enum IncidentStatus: string
{
    case Abierto = 'abierto';
    case Atendido = 'atendido';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
