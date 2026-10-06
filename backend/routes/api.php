<?php

use App\Http\Controllers\Api\AddressController;
use App\Http\Controllers\Api\Admin\MenuItemController as AdminMenuItemController;
use App\Http\Controllers\Api\Admin\OrderController as AdminOrderController;
use App\Http\Controllers\Api\Admin\RestaurantController as AdminRestaurantController;
use App\Http\Controllers\Api\Admin\UserController as AdminUserController;
use App\Http\Controllers\Api\Admin\ZoneController as AdminZoneController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\Admin\IncidentController as AdminIncidentController;
use App\Http\Controllers\Api\DemoController;
use App\Http\Controllers\Api\DriverController;
use App\Http\Controllers\Api\IncidentController;
use App\Http\Controllers\Api\LocationController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\RestaurantController;
use App\Http\Controllers\Api\Restaurant\MenuItemController as OwnerMenuItemController;
use App\Http\Controllers\Api\Restaurant\OrderController as OwnerOrderController;
use App\Http\Controllers\Api\Restaurant\RestaurantController as OwnerRestaurantController;
use App\Http\Controllers\Api\ZoneController;
use Illuminate\Support\Facades\Route;

Route::prefix('auth')->middleware('throttle:login')->group(function () {
    Route::post('register', [AuthController::class, 'register']);
    Route::post('login', [AuthController::class, 'login']);
});

Route::middleware('auth:sanctum')->group(function () {
    Route::post('auth/logout', [AuthController::class, 'logout']);
    Route::get('me', [AuthController::class, 'me']);

    Route::get('zones', [ZoneController::class, 'index']);
    Route::apiResource('addresses', AddressController::class)->except('show');

    Route::get('restaurants/categories', [RestaurantController::class, 'categories']);
    Route::get('restaurants', [RestaurantController::class, 'index']);
    Route::get('restaurants/{restaurant}', [RestaurantController::class, 'show']);

    Route::get('orders', [OrderController::class, 'index']);
    Route::post('orders', [OrderController::class, 'store']);
    Route::get('orders/{order}', [OrderController::class, 'show']);
    Route::get('orders/{order}/route', [OrderController::class, 'route']);
    Route::post('orders/{order}/cancel', [OrderController::class, 'cancel']);
    Route::get('orders/{order}/location', [LocationController::class, 'show']);
    // SOS / reportes: límite bajo para que no se use para inundar a soporte.
    Route::post('orders/{order}/incidents', [IncidentController::class, 'store'])->middleware('throttle:6,1');

    Route::prefix('driver')->group(function () {
        Route::get('orders', [DriverController::class, 'index']);
        Route::post('orders/{order}/advance', [DriverController::class, 'advance']);
        // Máx. 5 intentos por minuto: evita adivinar el código de 4 dígitos por fuerza bruta.
        // El GPS reporta cada pocos segundos; 60/min deja margen sin permitir abuso.
        Route::post('orders/{order}/location', [LocationController::class, 'store'])->middleware('throttle:60,1');
        Route::post('orders/{order}/deliver', [DriverController::class, 'deliver'])->middleware('throttle:5,1');
    });

    Route::prefix('restaurant')->middleware('restaurante')->group(function () {
        Route::get('restaurants', [OwnerRestaurantController::class, 'index']);
        Route::put('restaurants/{restaurant}', [OwnerRestaurantController::class, 'update']);

        Route::post('restaurants/{restaurant}/menu-items', [OwnerMenuItemController::class, 'store']);
        Route::put('menu-items/{menuItem}', [OwnerMenuItemController::class, 'update']);
        Route::delete('menu-items/{menuItem}', [OwnerMenuItemController::class, 'destroy']);

        Route::get('orders', [OwnerOrderController::class, 'index']);
        Route::post('orders/{order}/advance', [OwnerOrderController::class, 'advance']);
        Route::post('orders/{order}/cancel', [OwnerOrderController::class, 'cancel']);
    });

    Route::post('demo/orders/{order}/advance', [DemoController::class, 'advance']);

    Route::prefix('admin')->middleware('admin')->group(function () {
        Route::get('orders', [AdminOrderController::class, 'index']);
        Route::put('orders/{order}/status', [AdminOrderController::class, 'updateStatus']);

        Route::get('incidents', [AdminIncidentController::class, 'index']);
        Route::put('incidents/{incident}', [AdminIncidentController::class, 'update']);

        Route::get('zones', [AdminZoneController::class, 'index']);
        Route::post('zones', [AdminZoneController::class, 'store']);
        Route::put('zones/{zone}', [AdminZoneController::class, 'update']);
        Route::delete('zones/{zone}', [AdminZoneController::class, 'destroy']);

        Route::get('restaurants', [AdminRestaurantController::class, 'index']);
        Route::post('restaurants', [AdminRestaurantController::class, 'store']);
        Route::put('restaurants/{restaurant}', [AdminRestaurantController::class, 'update']);
        Route::delete('restaurants/{restaurant}', [AdminRestaurantController::class, 'destroy']);

        Route::post('restaurants/{restaurant}/menu-items', [AdminMenuItemController::class, 'store']);
        Route::put('menu-items/{menuItem}', [AdminMenuItemController::class, 'update']);
        Route::delete('menu-items/{menuItem}', [AdminMenuItemController::class, 'destroy']);

        Route::get('users', [AdminUserController::class, 'index']);
        Route::post('users', [AdminUserController::class, 'store']);
        Route::put('users/{user}', [AdminUserController::class, 'update']);
        Route::delete('users/{user}', [AdminUserController::class, 'destroy']);
    });
});
