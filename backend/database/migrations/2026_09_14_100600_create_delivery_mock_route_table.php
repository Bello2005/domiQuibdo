<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Solo Sprint 0: puntos para simular el GPS del repartidor.
     */
    public function up(): void
    {
        Schema::create('delivery_mock_route', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained()->cascadeOnDelete();
            $table->unsignedSmallInteger('sequence');
            $table->decimal('latitude', 10, 7);
            $table->decimal('longitude', 10, 7);
            $table->unique(['order_id', 'sequence']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('delivery_mock_route');
    }
};
