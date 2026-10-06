<?php

namespace App\Http\Middleware;

use App\Enums\UserRole;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureRestaurante
{
    public function handle(Request $request, Closure $next): Response
    {
        abort_unless($request->user()?->hasRole(UserRole::Restaurante), 403);

        return $next($request);
    }
}
