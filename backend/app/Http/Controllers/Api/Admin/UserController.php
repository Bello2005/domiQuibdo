<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\UserRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Hash;

class UserController extends Controller
{
    public function index(): AnonymousResourceCollection
    {
        return UserResource::collection(User::orderBy('name')->get());
    }

    /**
     * Unico lugar donde un rol puede asignarse directamente: el registro publico
     * (AuthController::register) siempre fuerza rol cliente, esto es intencional.
     */
    public function store(UserRequest $request): JsonResponse
    {
        $data = $request->validated();
        $data['password'] = Hash::make($data['password']);

        $user = User::forceCreate($data + ['email_verified_at' => now()]);

        return UserResource::make($user)->response()->setStatusCode(201);
    }

    public function update(UserRequest $request, User $user): UserResource
    {
        $data = $request->validated();
        $data['password'] = filled($data['password'] ?? null) ? Hash::make($data['password']) : $user->password;

        $user->forceFill($data)->save();

        return UserResource::make($user);
    }

    public function destroy(Request $request, User $user): JsonResponse
    {
        abort_if($request->user()->id === $user->id, 422, 'No puedes eliminar tu propia cuenta.');

        try {
            $user->delete();
        } catch (QueryException) {
            abort(422, 'No se puede eliminar: el usuario tiene pedidos asociados.');
        }

        return response()->json(status: 204);
    }
}
