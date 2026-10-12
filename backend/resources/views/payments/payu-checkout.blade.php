@extends('payments.layout')

@section('title', 'Pagar pedido')

@section('content')
    <div class="badge">$</div>
    <h1>Pedido #{{ $order->id }}</h1>
    <p>{{ $order->restaurant->name }}</p>
    <div class="amount">$ {{ number_format($order->total, 0, ',', '.') }} COP</div>

    <form id="payu" method="post" action="{{ $action }}">
        @foreach ($fields as $name => $value)
            <input type="hidden" name="{{ $name }}" value="{{ $value }}">
        @endforeach
        <button type="submit">Ir a pagar con PayU</button>
    </form>

    <p class="muted">Te llevamos a la pasarela segura de PayU (tarjeta, PSE, Nequi y más).</p>

    <script>document.getElementById('payu').submit();</script>
@endsection
