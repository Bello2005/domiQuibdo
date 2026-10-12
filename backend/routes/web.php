<?php

use App\Http\Controllers\PayuCheckoutController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('pagos/payu/respuesta', [PayuCheckoutController::class, 'response'])->name('payments.payu.response');
Route::get('pagos/payu/{order}', [PayuCheckoutController::class, 'checkout'])
    ->whereNumber('order')
    ->middleware('signed')
    ->name('payments.payu.checkout');
