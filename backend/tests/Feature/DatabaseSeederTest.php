<?php

namespace Tests\Feature;

use App\Models\Restaurant;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DatabaseSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_production_seed_adds_catalog_without_test_accounts(): void
    {
        $this->app['env'] = 'production';
        $usersBefore = User::count();
        $restaurantsBefore = Restaurant::count();

        $this->runDatabaseSeeder();

        $this->assertSame($usersBefore, User::count());
        $this->assertGreaterThan($restaurantsBefore, Restaurant::count());
    }

    /** Sin pasar por `db:seed`, que en producción pide confirmación interactiva. */
    private function runDatabaseSeeder(): void
    {
        $this->app->make(DatabaseSeeder::class)->setContainer($this->app)->__invoke();
    }
}
