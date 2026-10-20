<?php

return [

    /*
    | Zona de servicio: solo repartidores dentro de este círculo pueden tomar pedidos o compartir ubicación.
    | Por defecto, Quibdó (centro de la ciudad y 15 km a la redonda).
    */
    'service_area' => [
        'lat' => (float) env('SERVICE_AREA_LAT', 5.6935),
        'lng' => (float) env('SERVICE_AREA_LNG', -76.6600),
        'radius_km' => (float) env('SERVICE_AREA_RADIUS_KM', 15),
    ],

    /* Metros máximos entre el repartidor y la dirección para poder validar el código de entrega. */
    'delivery_radius_m' => (int) env('DELIVERY_RADIUS_M', 100),

    /* Efectivo contra entrega o pago en línea con PayU (tarjeta, PSE, Nequi, etc.). */
    'payment_methods' => ['efectivo', 'payu'],

    /*
    | Servidor OSRM para la ruta por calles restaurante → entrega. Vacío = línea recta.
    | El servidor público de demostración sirve para pruebas; en uso real conviene uno propio.
    */
    'routing_url' => env('ROUTING_URL', 'https://router.project-osrm.org'),

    /*
    | Comisión de DomiQuibdó sobre la venta de comida (sin el domicilio, que es del repartidor).
    | Con ella se calcula la ganancia neta del restaurante en Finanzas y en los comprobantes.
    */
    'commission_rate' => (float) env('PLATFORM_COMMISSION_RATE', 0.10),

    /* Zona horaria del negocio: los reportes agrupan ventas por día y hora local. */
    'business_timezone' => env('BUSINESS_TIMEZONE', 'America/Bogota'),

];
