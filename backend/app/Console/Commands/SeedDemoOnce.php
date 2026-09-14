<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;

class SeedDemoOnce extends Command
{
    protected $signature = 'demo:seed-once';

    protected $description = 'Corre los seeders de demo solo si todavia no se han ejecutado';

    public function handle(): int
    {
        if (User::where('email', 'cliente@demo.co')->exists()) {
            $this->info('Los datos demo ya existen, no se vuelve a sembrar.');

            return self::SUCCESS;
        }

        $this->call('db:seed', ['--force' => true]);

        return self::SUCCESS;
    }
}
