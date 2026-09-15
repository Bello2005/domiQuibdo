<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;

class RestaurantRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'category' => ['required', 'string', 'max:255'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'address_text' => ['required', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:30'],
            'cover_image_url' => ['nullable', 'url', 'max:2048'],
            'rating_avg' => ['nullable', 'numeric', 'between:0,5'],
            'delivery_time_min' => ['nullable', 'integer', 'min:0', 'max:180'],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }
}
