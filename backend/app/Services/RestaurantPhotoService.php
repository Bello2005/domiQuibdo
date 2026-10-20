<?php

namespace App\Services;

use App\Models\MenuItem;
use App\Models\Restaurant;
use App\Models\RestaurantPhoto;
use Illuminate\Filesystem\FilesystemAdapter;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use RuntimeException;

/**
 * Fotos que suben los restaurantes (galería del negocio y foto de cada plato).
 *
 * Cada imagen se guarda en dos tamaños WebP: una grande para la galería y una
 * miniatura para listas y menús, así la app no descarga más de lo que muestra.
 * El disco sale de PHOTOS_DISK (por defecto `public`, en el mismo servidor); para usar
 * un bucket S3/R2 basta con configurar ese disco, sin tocar el código.
 */
class RestaurantPhotoService
{
    public const MAX_PHOTOS = 12;

    private const LARGE_SIZE = 1600;

    private const THUMB_SIZE = 480;

    public static function disk(): FilesystemAdapter
    {
        return Storage::disk(config('filesystems.photos_disk'));
    }

    public function addPhoto(Restaurant $restaurant, UploadedFile $file): RestaurantPhoto
    {
        if ($restaurant->photos()->count() >= self::MAX_PHOTOS) {
            throw ValidationException::withMessages([
                'photo' => 'Máximo '.self::MAX_PHOTOS.' fotos por negocio. Borra alguna para subir otra.',
            ]);
        }

        [$path, $thumbPath] = $this->store($file, "restaurants/{$restaurant->id}");

        return $restaurant->photos()->create([
            'path' => $path,
            'thumb_path' => $thumbPath,
            'position' => (int) $restaurant->photos()->max('position') + 1,
        ]);
    }

    public function deletePhoto(RestaurantPhoto $photo): void
    {
        self::disk()->delete([$photo->path, $photo->thumb_path]);
        $photo->delete();
    }

    /**
     * Reordena la galería; la primera foto queda como portada.
     *
     * @param  list<int>  $photoIds
     */
    public function reorder(Restaurant $restaurant, array $photoIds): void
    {
        $owned = $restaurant->photos()->pluck('id')->all();
        if (array_diff($photoIds, $owned) || count($photoIds) !== count($owned)) {
            throw ValidationException::withMessages(['ids' => 'Envía todas las fotos del negocio, una sola vez.']);
        }

        DB::transaction(function () use ($photoIds) {
            foreach ($photoIds as $position => $id) {
                RestaurantPhoto::whereKey($id)->update(['position' => $position]);
            }
        });
    }

    public function setMenuItemPhoto(MenuItem $item, UploadedFile $file): MenuItem
    {
        $old = array_filter([$item->image_path, $item->image_thumb_path]);
        [$path, $thumbPath] = $this->store($file, "restaurants/{$item->restaurant_id}/menu");
        $item->update(['image_path' => $path, 'image_thumb_path' => $thumbPath]);
        self::disk()->delete($old);

        return $item;
    }

    public function removeMenuItemPhoto(MenuItem $item): MenuItem
    {
        self::disk()->delete(array_filter([$item->image_path, $item->image_thumb_path]));
        $item->update(['image_path' => null, 'image_thumb_path' => null]);

        return $item;
    }

    /**
     * Guarda la imagen en tamaño grande y miniatura (WebP) y devuelve ambas rutas.
     *
     * @return array{0: string, 1: string}
     */
    public function store(UploadedFile $file, string $directory): array
    {
        $image = $this->load($file);
        $name = Str::uuid()->toString();
        $path = "{$directory}/{$name}.webp";
        $thumbPath = "{$directory}/{$name}-thumb.webp";

        $disk = self::disk();
        $disk->put($path, $this->encode($image, self::LARGE_SIZE, 82));
        $disk->put($thumbPath, $this->encode($image, self::THUMB_SIZE, 76));
        imagedestroy($image);

        return [$path, $thumbPath];
    }

    private function load(UploadedFile $file): \GdImage
    {
        $image = @imagecreatefromstring((string) file_get_contents($file->getRealPath()));
        if (! $image instanceof \GdImage) {
            throw ValidationException::withMessages(['photo' => 'No se pudo leer la imagen. Usa JPG, PNG o WebP.']);
        }

        // Las fotos de celular vienen giradas según el EXIF; se enderezan antes de guardar.
        $orientation = function_exists('exif_read_data') && in_array($file->getMimeType(), ['image/jpeg', 'image/jpg'], true)
            ? (@exif_read_data($file->getRealPath())['Orientation'] ?? 1)
            : 1;
        $rotated = match ($orientation) {
            3 => imagerotate($image, 180, 0),
            6 => imagerotate($image, -90, 0),
            8 => imagerotate($image, 90, 0),
            default => $image,
        };
        if ($rotated !== $image && $rotated instanceof \GdImage) {
            imagedestroy($image);
            $image = $rotated;
        }

        return $image;
    }

    private function encode(\GdImage $image, int $maxSide, int $quality): string
    {
        $width = imagesx($image);
        $height = imagesy($image);
        $scale = min(1, $maxSide / max($width, $height));
        $resized = $image;
        if ($scale < 1) {
            $newWidth = max(1, (int) round($width * $scale));
            $newHeight = max(1, (int) round($height * $scale));
            $resized = imagecreatetruecolor($newWidth, $newHeight);
            imagealphablending($resized, false);
            imagesavealpha($resized, true);
            imagecopyresampled($resized, $image, 0, 0, 0, 0, $newWidth, $newHeight, $width, $height);
        }

        ob_start();
        $ok = imagewebp($resized, null, $quality);
        $data = (string) ob_get_clean();
        if ($resized !== $image) {
            imagedestroy($resized);
        }
        if (! $ok) {
            throw new RuntimeException('No se pudo codificar la imagen en WebP.');
        }

        return $data;
    }
}
