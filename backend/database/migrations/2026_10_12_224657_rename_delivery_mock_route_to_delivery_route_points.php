<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * La ruta ya no es simulada: guarda el recorrido por calles restaurante → entrega.
     */
    public function up(): void
    {
        Schema::rename('delivery_mock_route', 'delivery_route_points');
    }

    public function down(): void
    {
        Schema::rename('delivery_route_points', 'delivery_mock_route');
    }
};
