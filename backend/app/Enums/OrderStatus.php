<?php

namespace App\Enums;

enum OrderStatus: string
{
    case Pendiente = 'pendiente';
    case Confirmado = 'confirmado';
    case Preparando = 'preparando';
    case EnCamino = 'en_camino';
    case Entregado = 'entregado';
    case Cancelado = 'cancelado';

    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    /**
     * Siguiente estado válido en el flujo normal del pedido.
     */
    public function next(): ?self
    {
        return match ($this) {
            self::Pendiente => self::Confirmado,
            self::Confirmado => self::Preparando,
            self::Preparando => self::EnCamino,
            self::EnCamino => self::Entregado,
            default => null,
        };
    }

    public function isActive(): bool
    {
        return ! in_array($this, [self::Entregado, self::Cancelado], true);
    }

    public function label(): string
    {
        return match ($this) {
            self::Pendiente => 'Pendiente',
            self::Confirmado => 'Confirmado',
            self::Preparando => 'Preparando',
            self::EnCamino => 'En camino',
            self::Entregado => 'Entregado',
            self::Cancelado => 'Cancelado',
        };
    }
}
