<?php

namespace Database\Seeders;

use App\Models\Restaurant;
use Illuminate\Database\Seeder;

class RestaurantSeeder extends Seeder
{
    /**
     * Negocios reales de Quibdó (nombre, dirección y teléfono de fuentes públicas).
     * Coordenadas APROXIMADAS según la dirección. Menús y precios son inventados
     * para el proyecto académico y no representan la oferta real de cada negocio.
     */
    public function run(): void
    {
        foreach ($this->restaurants() as $data) {
            $menu = $data['menu'];
            unset($data['menu']);

            $restaurant = Restaurant::create($data);

            foreach ($menu as [$name, $description, $price]) {
                $restaurant->menuItems()->create([
                    'name' => $name,
                    'description' => $description,
                    'price' => $price,
                    'is_available' => true,
                ]);
            }
        }
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function restaurants(): array
    {
        return [
            [
                'name' => 'Al Aire Rooftop Quibdó',
                'description' => 'Restaurante de gama alta con terraza y vista sobre la ciudad.',
                'category' => 'Gama alta',
                'address_text' => 'Cl. 28 #1-70',
                'phone' => '+57 310 7632896',
                'latitude' => 5.6918, 'longitude' => -76.6612,
                'rating_avg' => 4.8, 'delivery_time_min' => 40,
                'menu' => [
                    ['Pargo rojo en salsa de coco', 'Pargo entero, arroz con coco y patacones.', 58000],
                    ['Ceviche de camarón', 'Camarón, limón, cebolla morada y cilantro.', 38000],
                    ['Lomo al vino tinto', 'Medallones de res con reducción de vino y puré rústico.', 62000],
                    ['Tabla de mariscos', 'Para compartir: camarón, calamar, pescado y salsas.', 89000],
                    ['Cóctel de borojó', 'Borojó, leche condensada y un toque de canela.', 22000],
                ],
            ],
            [
                'name' => 'Brisas Del Atrato Restaurante Bar',
                'description' => 'Comida chocoana a orillas del río Atrato.',
                'category' => 'Chocoana',
                'address_text' => 'Cra. 2n #34-1',
                'phone' => null,
                'latitude' => 5.6972, 'longitude' => -76.6605,
                'rating_avg' => 4.5, 'delivery_time_min' => 35,
                'menu' => [
                    ['Bocachico frito', 'Con patacón, arroz y ensalada.', 25000],
                    ['Sancocho de pescado', 'Pescado de río, plátano, yuca y hierbas de azotea.', 22000],
                    ['Arroz con coco y camarón', 'Arroz titoté con camarón salteado.', 28000],
                    ['Jugo de borojó', 'En leche o en agua.', 7000],
                ],
            ],
            [
                'name' => 'Restaurante Maria Mulata',
                'description' => 'Comida típica del Pacífico con opciones vegetarianas.',
                'category' => 'Típica',
                'address_text' => 'Cl. 25 #6-13',
                'phone' => '+57 311 7220156',
                'latitude' => 5.6898, 'longitude' => -76.6575,
                'rating_avg' => 4.7, 'delivery_time_min' => 30,
                'menu' => [
                    ['Bandeja chocoana', 'Pescado, arroz con coco, fríjol y patacón.', 24000],
                    ['Arroz atollado', 'Arroz cremoso con cerdo y longaniza.', 20000],
                    ['Bowl vegetariano', 'Plátano maduro, fríjol, aguacate y arroz integral.', 19000],
                    ['Empanadas de queso (3)', 'Masa de maíz, queso costeño.', 9000],
                    ['Limonada de coco', 'Refrescante y cremosa.', 8000],
                ],
            ],
            [
                'name' => 'Boga Restaurante',
                'description' => 'Comida chocoana y buffet, diagonal al aeropuerto El Caraño.',
                'category' => 'Chocoana',
                'address_text' => 'Barrio Los Ángeles, diag. aeropuerto El Caraño',
                'phone' => '+57 321 2754555',
                'latitude' => 5.6915, 'longitude' => -76.6430,
                'rating_avg' => 4.4, 'delivery_time_min' => 45,
                'menu' => [
                    ['Almuerzo buffet chocoano', 'Sopa, principio, proteína y jugo del día.', 28000],
                    ['Tollo ahumado guisado', 'Con arroz blanco y plátano.', 30000],
                    ['Queso costeño con patacón', 'Entrada para compartir.', 14000],
                    ['Chicha de maíz', 'Bebida tradicional.', 6000],
                ],
            ],
            [
                'name' => 'Al Carbón Parrilla Bar',
                'description' => 'Carnes a la parrilla y picadas.',
                'category' => 'Parrilla',
                'address_text' => 'Calle 31 Cra 2, esquina',
                'phone' => '+57 311 3296315',
                'latitude' => 5.6945, 'longitude' => -76.6603,
                'rating_avg' => 4.6, 'delivery_time_min' => 40,
                'menu' => [
                    ['Punta de anca 300 g', 'Con papa criolla y chimichurri.', 42000],
                    ['Costillas BBQ', 'Costillas de cerdo glaseadas.', 38000],
                    ['Chorizo con arepa', 'Chorizo a la brasa y arepa de maíz.', 16000],
                    ['Picada para 2', 'Res, cerdo, chorizo, maduro y papa.', 55000],
                    ['Cerveza nacional', 'Botella 330 ml.', 6000],
                ],
            ],
            [
                'name' => 'La paila de mi abuela',
                'description' => 'Comida típica del Chocó hecha como en casa.',
                'category' => 'Típica',
                'address_text' => 'Quibdó centro',
                'phone' => '+57 311 3261991',
                'latitude' => 5.6930, 'longitude' => -76.6592,
                'rating_avg' => 4.5, 'delivery_time_min' => 30,
                'menu' => [
                    ['Sopa de queso', 'Receta tradicional con plátano y queso.', 18000],
                    ['Arroz clavado', 'Arroz con queso y longaniza.', 22000],
                    ['Encocado de jaiba', 'Jaiba en leche de coco con arroz.', 30000],
                    ['Aguapanela con limón', 'Fría o caliente.', 4000],
                ],
            ],
            [
                'name' => 'Pollos Nacho',
                'description' => 'Pollo asado y frito.',
                'category' => 'Pollo',
                'address_text' => 'Cl. 31 #6-11',
                'phone' => '+57 310 7505209',
                'latitude' => 5.6942, 'longitude' => -76.6570,
                'rating_avg' => 4.3, 'delivery_time_min' => 25,
                'menu' => [
                    ['1/4 de pollo asado', 'Con papa salada y arepa.', 16000],
                    ['1/2 pollo asado', 'Con papa salada, arepa y ensalada.', 27000],
                    ['Pollo entero asado', 'Para la familia, con acompañantes.', 48000],
                    ['Alitas BBQ (8)', 'Con papas a la francesa.', 22000],
                    ['Gaseosa 1.5 L', 'Sabor a elección.', 7000],
                ],
            ],
            [
                'name' => 'Frisby CC El Caraño',
                'description' => 'Cadena nacional de pollo apanado.',
                'category' => 'Pollo',
                'address_text' => 'CC El Caraño',
                'phone' => '+57 301 3555555',
                'latitude' => 5.6908, 'longitude' => -76.6455,
                'rating_avg' => 4.2, 'delivery_time_min' => 30,
                'menu' => [
                    ['Combo 2 presas apanadas', 'Con papas y bebida.', 23900],
                    ['Balde 4 presas', 'Pollo apanado para compartir.', 36900],
                    ['Alitas apanadas', 'Con salsa a elección.', 17900],
                    ['Papas medianas', 'Papas a la francesa.', 7900],
                ],
            ],
            [
                'name' => 'Helados Makerule',
                'description' => 'Heladería artesanal con frutas exóticas del Chocó.',
                'category' => 'Heladería',
                'address_text' => 'Cl. 31 #3-07',
                'phone' => '+57 320 6157084',
                'latitude' => 5.6944, 'longitude' => -76.6596,
                'rating_avg' => 4.8, 'delivery_time_min' => 20,
                'menu' => [
                    ['Helado de borojó', 'Vaso de dos bolas.', 7000],
                    ['Helado de chontaduro', 'Vaso de dos bolas.', 7000],
                    ['Paleta de arazá', 'Fruta natural.', 5000],
                    ['Copa tropical', 'Tres sabores, fruta picada y crema.', 15000],
                    ['Malteada de coco', 'Con helado de coco.', 12000],
                ],
            ],
            [
                'name' => 'Nativhos',
                'description' => 'Heladería con sabores nativos: borojó y chontaduro.',
                'category' => 'Heladería',
                'address_text' => 'Quibdó centro',
                'phone' => null,
                'latitude' => 5.6926, 'longitude' => -76.6604,
                'rating_avg' => 4.6, 'delivery_time_min' => 20,
                'menu' => [
                    ['Helado de borojó', 'Cono sencillo.', 6500],
                    ['Chontaduro con miel', 'Helado de chontaduro y miel de caña.', 7000],
                    ['Sorbete de lulo', 'Sin lácteos.', 6000],
                    ['Banana split chocoano', 'Banano, tres helados nativos y salsa.', 14000],
                ],
            ],
            [
                'name' => 'Panadería Las Delicias Del Tambo',
                'description' => 'Panadería de barrio con productos del día.',
                'category' => 'Panadería',
                'address_text' => 'Cra. 22 #23-39',
                'phone' => null,
                'latitude' => 5.6880, 'longitude' => -76.6480,
                'rating_avg' => 4.4, 'delivery_time_min' => 25,
                'menu' => [
                    ['Pan de coco', 'Unidad.', 2500],
                    ['Pandebono', 'Unidad, recién horneado.', 2000],
                    ['Torta de plátano maduro', 'Porción.', 6000],
                    ['Mantecada', 'Porción.', 3000],
                    ['Café con leche', 'Vaso 9 oz.', 3500],
                ],
            ],
            [
                'name' => 'ChocQuiBurger Quibdó',
                'description' => 'Hamburguesas y comida rápida.',
                'category' => 'Comida rápida',
                'address_text' => 'Cra. 22 #20-134',
                'phone' => '+57 317 5831159',
                'latitude' => 5.6860, 'longitude' => -76.6485,
                'rating_avg' => 4.5, 'delivery_time_min' => 30,
                'menu' => [
                    ['Burger clásica', 'Carne 150 g, queso, tomate y salsas.', 22000],
                    ['Burger doble queso', 'Doble carne y doble queso.', 28000],
                    ['Perro caliente especial', 'Salchicha americana, queso y papita.', 16000],
                    ['Salchipapa', 'Para compartir.', 15000],
                    ['Papas a la francesa', 'Porción grande.', 8000],
                ],
            ],
        ];
    }
}
