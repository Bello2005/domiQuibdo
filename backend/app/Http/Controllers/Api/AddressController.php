<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\AddressRequest;
use App\Http\Resources\AddressResource;
use App\Models\Address;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;

class AddressController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        return AddressResource::collection(
            $request->user()->addresses()->with('zone')
                ->orderByDesc('es_predeterminada')->latest()->get()
        );
    }

    public function store(AddressRequest $request): JsonResponse
    {
        $user = $request->user();

        $address = DB::transaction(function () use ($request, $user) {
            $makeDefault = $request->boolean('es_predeterminada') || ! $user->addresses()->exists();
            $this->clearDefaultIf($makeDefault, $user);

            return $user->addresses()->create([...$request->validated(), 'es_predeterminada' => $makeDefault]);
        });

        return AddressResource::make($address->load('zone'))->response()->setStatusCode(201);
    }

    public function update(AddressRequest $request, Address $address): AddressResource
    {
        $user = $request->user();
        abort_unless($address->user_id === $user->id, 404);

        DB::transaction(function () use ($request, $user, $address) {
            $this->clearDefaultIf($request->boolean('es_predeterminada'), $user);
            $address->update($request->validated());
        });

        return AddressResource::make($address->load('zone'));
    }

    public function destroy(Request $request, Address $address): JsonResponse|Response
    {
        abort_unless($address->user_id === $request->user()->id, 404);

        if ($address->orders()->exists()) {
            return response()->json(['message' => 'No puedes eliminar una dirección con pedidos asociados.'], 409);
        }

        $address->delete();

        return response()->noContent();
    }

    private function clearDefaultIf(bool $condition, User $user): void
    {
        if ($condition) {
            $user->addresses()->update(['es_predeterminada' => false]);
        }
    }
}
