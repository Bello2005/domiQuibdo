<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_register_always_creates_cliente_even_if_role_is_sent(): void
    {
        $response = $this->postJson('/api/auth/register', [
            'name' => 'Ana Palacios',
            'email' => 'Ana@Example.com',
            'phone' => '3001234567',
            'password' => 'secreto123',
            'password_confirmation' => 'secreto123',
            'role' => 'admin',
        ]);

        $response->assertCreated()
            ->assertJsonPath('user.role', 'cliente')
            ->assertJsonStructure(['token', 'user' => ['id', 'name', 'email', 'phone', 'role']]);

        $this->assertSame(UserRole::Cliente, User::where('email', 'ana@example.com')->first()->role);
    }

    public function test_login_with_wrong_password_is_rejected(): void
    {
        $user = User::factory()->create();

        $this->postJson('/api/auth/login', ['email' => $user->email, 'password' => 'incorrecta'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');
    }

    public function test_login_returns_token_that_authenticates(): void
    {
        $user = User::factory()->create();

        $token = $this->postJson('/api/auth/login', ['email' => $user->email, 'password' => 'password'])
            ->assertOk()
            ->json('token');

        $this->withToken($token)->getJson('/api/me')->assertOk()->assertJsonPath('email', $user->email);
    }

    public function test_protected_routes_require_authentication(): void
    {
        $this->getJson('/api/restaurants')->assertUnauthorized();
    }
}
