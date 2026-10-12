@extends('payments.layout')

@php
    use App\Enums\PaymentStatus;

    [$badgeClass, $icon, $title, $message] = match (true) {
        ! $valid => ['bad', '!', 'No pudimos verificar el pago', 'La respuesta no viene firmada por PayU. Revisa el estado del pedido en la app.'],
        $status === PaymentStatus::Aprobado => ['ok', '✓', '¡Pago aprobado!', 'El restaurante ya puede preparar tu pedido.'],
        $status === PaymentStatus::Pendiente => ['wait', '…', 'Pago en proceso', 'PayU está confirmando tu pago. Te avisaremos en la app.'],
        $status === PaymentStatus::Expirado => ['bad', '×', 'El pago expiró', 'El pedido se canceló. Puedes hacer uno nuevo desde la app.'],
        default => ['bad', '×', 'Pago rechazado', 'Puedes intentar de nuevo desde el pedido en la app.'],
    };
@endphp

@section('title', $title)

@section('content')
    <div class="badge {{ $badgeClass }}">{{ $icon }}</div>
    <h1>{{ $title }}</h1>
    <p>{{ $message }}</p>
    @if ($order)
        <p><strong>Pedido #{{ $order->id }}</strong> · $ {{ number_format($order->total, 0, ',', '.') }} COP</p>
    @endif
    <p class="muted">Ya puedes cerrar esta ventana y volver a DomiQuibdó.</p>
@endsection
