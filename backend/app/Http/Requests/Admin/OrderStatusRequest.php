<?php

namespace App\Http\Requests\Admin;

use App\Enums\OrderStatus;
use App\Enums\UserRole;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class OrderStatusRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'status' => ['required', Rule::enum(OrderStatus::class)],
            'repartidor_id' => ['nullable', 'integer', Rule::exists('users', 'id')->where('role', UserRole::Repartidor->value)],
        ];
    }
}
