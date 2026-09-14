<?php

return [

    /*
    | Modo demo: habilita /api/demo/* para avanzar estados de un pedido desde
    | la cuenta del cliente durante la presentación. Nunca activar en producción.
    */
    'demo' => (bool) env('APP_DEMO', false),

    'demo_driver_email' => env('DEMO_DRIVER_EMAIL', 'repartidor@demo.co'),

    'payment_methods' => ['efectivo', 'transferencia', 'nequi'],

];
