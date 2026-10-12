<?php

return [

    /* Efectivo contra entrega o pago en línea con PayU (tarjeta, PSE, Nequi, etc.). */
    'payment_methods' => ['efectivo', 'payu'],

    /*
    | Servidor OSRM para la ruta por calles restaurante → entrega. Vacío = línea recta.
    | El servidor público de demostración sirve para pruebas; en uso real conviene uno propio.
    */
    'routing_url' => env('ROUTING_URL', 'https://router.project-osrm.org'),

];
