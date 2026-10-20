<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            // Tarifa de DomiQuibdó al cliente y costo de la pasarela (solo pagos en línea).
            $table->decimal('service_fee', 10, 2)->default(0)->after('delivery_fee');
            $table->decimal('payment_fee', 10, 2)->default(0)->after('service_fee');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['service_fee', 'payment_fee']);
        });
    }
};
