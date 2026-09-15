<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;

class ZoneRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'center_lat' => ['required', 'numeric', 'between:-90,90'],
            'center_lng' => ['required', 'numeric', 'between:-180,180'],
            'radius_m' => ['required', 'integer', 'min:50', 'max:20000'],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }
}
