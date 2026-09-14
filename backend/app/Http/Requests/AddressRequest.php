<?php

namespace App\Http\Requests;

use App\Enums\AddressType;
use App\Models\CoverageZone;
use App\Services\CoverageService;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class AddressRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'coverage_zone_id' => ['required', 'integer', Rule::exists('coverage_zones', 'id')->where('is_active', true)],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'tipo' => ['required', Rule::enum(AddressType::class)],
            'detalle' => ['nullable', 'string', 'max:255'],
            'es_predeterminada' => ['sometimes', 'boolean'],
        ];
    }

    /**
     * El pin debe caer dentro del barrio seleccionado.
     */
    public function after(): array
    {
        return [
            function (Validator $validator) {
                if ($validator->errors()->isNotEmpty()) {
                    return;
                }

                $zone = CoverageZone::find($this->integer('coverage_zone_id'));
                $inside = CoverageService::contains($zone, (float) $this->input('latitude'), (float) $this->input('longitude'));

                if (! $inside) {
                    $validator->errors()->add('latitude', "El pin está fuera de la zona de cobertura de {$zone->name}.");
                }
            },
        ];
    }
}
