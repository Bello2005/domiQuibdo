"""Genera el ícono de DomiQuibdó para Android, la app web, el admin y la app Flutter.

La fuente es `branding/logo-source.png` (el logo hecho en Microsoft Designer:
cuadro redondeado verde con la Q, el repartidor y el pin). El script:

1. Mide el degradado verde del fondo y separa la figura blanca/naranja en una
   capa transparente (`glyph`), quitando el verde de los bordes suavizados.
2. Recompone el ícono sobre un degradado limpio con esquinas propias, y saca la
   figura sola para las capas del ícono adaptativo de Android.

Para cambiar el logo basta con reemplazar `logo-source.png` y volver a correr:

    python3 branding/generate_icons.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "branding/logo-source.png"

# Degradado del fondo (medido en la fuente): arriba-izquierda → abajo-derecha.
GRAD_START = (38, 101, 59)  # #26653B
GRAD_END = (2, 62, 35)  # #023E23

# Lienzo del ícono adaptativo (108dp): la figura debe caber en el círculo
# seguro de radio 33dp; se deja un poco de aire.
SAFE_RADIUS = 31.5 / 108
# Proporción de la figura dentro del ícono cuadrado completo (como en la fuente).
ICON_GLYPH_HEIGHT = 0.70


def extract_glyph() -> Image.Image:
    """Figura de la fuente sobre fondo transparente, recortada a su contenido."""
    src = np.asarray(Image.open(SOURCE).convert("RGB")).astype(np.float64)
    h, w, _ = src.shape

    # Píxeles de fondo: verdes oscuros dentro del cuadro redondeado.
    r, g, b = src[..., 0], src[..., 1], src[..., 2]
    is_bg = (g > r + 30) & (r < 80)
    ys, xs = np.nonzero(is_bg)
    # Ajuste lineal del degradado: canal = a + b·x + c·y.
    design = np.column_stack([np.ones_like(xs), xs, ys]).astype(np.float64)
    yy, xx = np.mgrid[0:h, 0:w]
    bg = np.empty_like(src)
    for ch in range(3):
        coef, *_ = np.linalg.lstsq(design, src[ys, xs, ch], rcond=None)
        bg[..., ch] = coef[0] + coef[1] * xx + coef[2] * yy

    # El rojo separa bien: fondo ≈ 0-40, blanco y naranja ≈ 240-255.
    alpha = np.clip((r - bg[..., 0]) / (245 - bg[..., 0]), 0, 1)
    # Solo dentro del cuadro: fuera hay blanco puro que no es parte del logo.
    inside = np.zeros((h, w), bool)
    by, bx = np.nonzero(src.sum(2) < 600)
    pad = 140  # evita las esquinas redondeadas y el borde blanco de la fuente
    inside[by.min() + pad:by.max() - pad, bx.min() + pad:bx.max() - pad] = True
    alpha[~inside] = 0
    alpha[alpha < 0.04] = 0

    # Color sin el verde mezclado en los bordes: C = (P - (1-α)·bg) / α.
    safe = np.maximum(alpha, 1e-3)[..., None]
    color = np.clip((src - (1 - alpha[..., None]) * bg) / safe, 0, 255)
    rgba = np.dstack([color, alpha * 255]).astype(np.uint8)
    glyph = Image.fromarray(rgba)
    return glyph.crop(glyph.getbbox())


def gradient_square(px: int, radius: float) -> Image.Image:
    t = np.add.outer(np.arange(px), np.arange(px)) / (2 * (px - 1))
    rgb = np.stack([GRAD_START[c] + (GRAD_END[c] - GRAD_START[c]) * t for c in range(3)], -1)
    img = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
    if radius:
        mask = Image.new("L", (px * 4, px * 4), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, px * 4 - 1, px * 4 - 1], radius=int(px * 4 * radius), fill=255)
        img.putalpha(mask.resize((px, px), Image.LANCZOS))
    return img


def scaled(glyph: Image.Image, height: int) -> Image.Image:
    w = round(glyph.width * height / glyph.height)
    return glyph.resize((w, height), Image.LANCZOS)


def place_center(canvas: Image.Image, g: Image.Image, offset=(0, 0)) -> Image.Image:
    x = (canvas.width - g.width) // 2 + offset[0]
    y = (canvas.height - g.height) // 2 + offset[1]
    canvas.alpha_composite(g, (x, y))
    return canvas


def icon(glyph: Image.Image, px: int, radius: float = 0.22) -> Image.Image:
    """Ícono cuadrado completo: degradado + figura (Play Store, web, legacy)."""
    return place_center(gradient_square(px, radius), scaled(glyph, round(px * ICON_GLYPH_HEIGHT)))


def adaptive_glyph_height(glyph: Image.Image) -> float:
    """Alto de la figura (en fracción del lienzo) para que quepa en el círculo seguro."""
    a = np.asarray(glyph)[..., 3] > 20
    ys, xs = np.nonzero(a)
    cx, cy = glyph.width / 2, glyph.height / 2
    max_r = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2).max()
    return SAFE_RADIUS * glyph.height / max_r


def foreground(glyph: Image.Image, px: int, mono: bool = False) -> Image.Image:
    g = scaled(glyph, round(px * adaptive_glyph_height(glyph)))
    if mono:
        white = Image.new("RGBA", g.size, (255, 255, 255, 255))
        white.putalpha(g.getchannel("A"))
        g = white
    return place_center(Image.new("RGBA", (px, px), (0, 0, 0, 0)), g)


def save(img: Image.Image, rel: str) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print(f"  {rel}  ({img.width}px)")


def main() -> None:
    glyph = extract_glyph()
    save(glyph, "branding/logo-glyph.png")

    res = "app/android/app/src/main/res"
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    print("Android")
    for name, f in densities.items():
        save(foreground(glyph, round(108 * f)), f"{res}/mipmap-{name}/ic_launcher_foreground.png")
        save(foreground(glyph, round(108 * f), mono=True), f"{res}/mipmap-{name}/ic_launcher_monochrome.png")
        save(icon(glyph, round(48 * f)), f"{res}/mipmap-{name}/ic_launcher.png")
        save(icon(glyph, round(48 * f), radius=0.5), f"{res}/mipmap-{name}/ic_launcher_round.png")

    print("Play Store / logo maestro")
    save(icon(glyph, 512, radius=0), "branding/playstore-icon-512.png")
    save(icon(glyph, 1024), "branding/logo.png")

    print("App Flutter (cabecera de marca)")
    save(icon(glyph, 256), "app/assets/branding/logo.png")

    print("Web (app Flutter)")
    save(icon(glyph, 32), "app/web/favicon.png")
    save(icon(glyph, 192), "app/web/icons/Icon-192.png")
    save(icon(glyph, 512), "app/web/icons/Icon-512.png")
    for px in (192, 512):
        m = gradient_square(px, 0)
        place_center(m, scaled(glyph, round(px * 0.62)))  # zona segura maskable: 80 %
        save(m, f"app/web/icons/Icon-maskable-{px}.png")

    print("Admin")
    save(icon(glyph, 48), "admin/public/favicon.png")
    save(icon(glyph, 192), "admin/public/logo.png")


if __name__ == "__main__":
    main()
