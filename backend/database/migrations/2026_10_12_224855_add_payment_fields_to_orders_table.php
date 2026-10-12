<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Pago en línea con PayU. Los pedidos en efectivo dejan estos campos en null.
     */
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->string('payment_status', 20)->nullable()->after('payment_method')->index();
            $table->string('payment_reference', 64)->nullable()->unique()->after('payment_status');
            $table->string('payment_transaction_id', 64)->nullable()->after('payment_reference');
            $table->timestamp('paid_at')->nullable()->after('payment_transaction_id');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['payment_status', 'payment_reference', 'payment_transaction_id', 'paid_at']);
        });
    }
};
