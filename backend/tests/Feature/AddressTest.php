<?php

namespace Tests\Feature;

use App\Models\CoverageZone;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AddressTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    public function test_pin_outside_selected_zone_is_rejected(): void
    {
        Sanctum::actingAs(User::where('email', 'cliente@demo.co')->first());
        $centro = CoverageZone::where('name', 'Centro')->first();

        $this->postJson('/api/addresses', [
            'coverage_zone_id' => $centro->id,
            'latitude' => 5.7400, // ~5 km al norte del centro
            'longitude' => -76.6600,
            'tipo' => 'casa',
        ])->assertUnprocessable()->assertJsonValidationErrors('latitude');
    }

    public function test_new_default_address_replaces_previous_default(): void
    {
        $cliente = User::where('email', 'cliente@demo.co')->first();
        Sanctum::actingAs($cliente);
        $kennedy = CoverageZone::where('name', 'Kennedy')->first();

        $this->postJson('/api/addresses', [
            'coverage_zone_id' => $kennedy->id,
            'latitude' => $kennedy->center_lat,
            'longitude' => $kennedy->center_lng,
            'tipo' => 'hotel',
            'detalle' => 'Habitación 204',
            'es_predeterminada' => true,
        ])->assertCreated()->assertJsonPath('zone.name', 'Kennedy');

        $this->assertSame(1, $cliente->addresses()->where('es_predeterminada', true)->count());
        $this->assertSame('hotel', $cliente->addresses()->where('es_predeterminada', true)->first()->tipo->value);
    }

    public function test_cannot_update_another_users_address(): void
    {
        $address = User::where('email', 'cliente@demo.co')->first()->addresses()->first();
        Sanctum::actingAs(User::factory()->create());

        $this->putJson("/api/addresses/{$address->id}", [
            'coverage_zone_id' => $address->coverage_zone_id,
            'latitude' => $address->latitude,
            'longitude' => $address->longitude,
            'tipo' => 'otro',
        ])->assertNotFound();
    }
}
