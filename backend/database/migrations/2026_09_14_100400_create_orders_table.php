<?php

use App\Enums\OrderStatus;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->foreignId('restaurant_id')->constrained()->restrictOnDelete();
            $table->foreignId('address_id')->constrained()->restrictOnDelete();
            $table->foreignId('repartidor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->enum('status', OrderStatus::values())->default(OrderStatus::Pendiente->value)->index();
            $table->string('verification_code', 4);
            $table->decimal('total', 10, 2);
            $table->decimal('delivery_fee', 10, 2)->default(0);
            $table->string('payment_method', 30);
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
