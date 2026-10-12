<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Resend, Postmark, AWS, and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    /*
    | PayU Latam (WebCheckout). Los valores por defecto son las credenciales PÚBLICAS de sandbox
    | de PayU para Colombia: no mueven dinero real. En producción se reemplazan por las de la cuenta.
    */
    'payu' => [
        'merchant_id' => env('PAYU_MERCHANT_ID', '508029'),
        'account_id' => env('PAYU_ACCOUNT_ID', '512321'),
        'api_key' => env('PAYU_API_KEY', '4Vj8eK4rloUd272L48hsrarnUA'),
        'test' => (bool) env('PAYU_TEST', true),
        'checkout_url' => env('PAYU_CHECKOUT_URL', 'https://sandbox.checkout.payulatam.com/ppp-web-gateway-payu/'),
        'currency' => 'COP',
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

];
