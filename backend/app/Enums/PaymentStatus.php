<?php

namespace App\Enums;

/**
 * Estado del pago en línea (PayU). Los pedidos en efectivo no tienen estado de pago.
 */
enum PaymentStatus: string
{
    case Pendiente = 'pendiente';
    case Aprobado = 'aprobado';
    case Rechazado = 'rechazado';
    case Expirado = 'expirado';

    /**
     * Traduce el `state_pol` / `transactionState` de PayU (4 aprobada, 6 rechazada, 5 expirada, 7 pendiente).
     */
    public static function fromPayuState(int $state): ?self
    {
        return match ($state) {
            4 => self::Aprobado,
            6 => self::Rechazado,
            5 => self::Expirado,
            7 => self::Pendiente,
            default => null,
        };
    }

    public function label(): string
    {
        return match ($this) {
            self::Pendiente => 'Pago pendiente',
            self::Aprobado => 'Pagado',
            self::Rechazado => 'Pago rechazado',
            self::Expirado => 'Pago expirado',
        };
    }
}
