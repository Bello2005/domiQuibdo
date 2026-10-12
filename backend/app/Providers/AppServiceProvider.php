<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        JsonResource::withoutWrapping();

        RateLimiter::for('login', fn (Request $request) => Limit::perMinute(10)
            ->by(mb_strtolower((string) $request->input('email')).'|'.$request->ip()));

        // Cada límite tiene su propio contador. Con `throttle:N,1` todos comparten el del usuario y
        // los envíos de GPS del repartidor agotaban los 5 intentos del código de entrega.
        RateLimiter::for('delivery-code', fn (Request $request) => Limit::perMinute(5)
            ->by($request->user()?->id.'|'.self::routeOrderId($request)));

        RateLimiter::for('courier-location', fn (Request $request) => Limit::perMinute(60)
            ->by((string) $request->user()?->id));

        RateLimiter::for('incidents', fn (Request $request) => Limit::perMinute(6)
            ->by((string) $request->user()?->id));

        RateLimiter::for('payment-webhook', fn (Request $request) => Limit::perMinute(120)
            ->by((string) $request->ip()));
    }

    /** El throttle corre antes del route model binding: `order` puede llegar como id o como modelo. */
    private static function routeOrderId(Request $request): string
    {
        $order = $request->route('order');

        return (string) (is_object($order) ? $order->getKey() : $order);
    }
}
