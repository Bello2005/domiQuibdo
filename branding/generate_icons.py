"""Genera el ícono de DomiQuibdó (la "Q" con el pin) para Android, web y admin.

Toda la geometría vive aquí, en el lienzo de 108x108 de los íconos adaptativos
de Android (zona segura: círculo de radio 33 en el centro). De ahí salen los
SVG maestros y todos los PNG, así que para ajustar el ícono basta con tocar las
constantes y volver a correr:

    python3 branding/generate_icons.py
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

SELVA = "#1B5E3F"
BOROJO = "#E07A2E"
WHITE = "#FFFFFF"

# Geometría en unidades del lienzo de 108.
CX, CY = 54.0, 50.0
RING_OUTER, RING_INNER = 24.6, 14.7
PIN_CX, PIN_CY = CX + 10.1, CY + 15.2
PIN_R, PIN_L = 9.4, 17.4  # radio de la cabeza y distancia centro → punta
PIN_STROKE = 3.4  # grosor del borde blanco del pin
MOAT = 2.2  # separación verde entre el pin y el aro de la Q
DOT_R = 3.4

SS = 4  # sobremuestreo para bordes suaves


def _offset_pin(t: float) -> tuple[float, float]:
    """Radio y largo de la gota desplazada `t` hacia afuera (t<0 hacia adentro)."""
    cos_phi = PIN_R / PIN_L
    return PIN_R + t, PIN_L + t / cos_phi


def _pin_points(r: float, length: float, steps: int = 96) -> list[tuple[float, float]]:
    """Contorno de la gota: punta abajo, cabeza circular arriba."""
    phi = math.acos(r / length)  # ángulo del punto tangente medido desde abajo
    pts = [(PIN_CX, PIN_CY + length)]
    # Arco por arriba, de la tangente derecha a la izquierda.
    start = math.pi / 2 - phi
    end = math.pi / 2 + phi - 2 * math.pi
    for i in range(steps + 1):
        a = start + (end - start) * i / steps
        pts.append((PIN_CX + r * math.cos(a), PIN_CY + r * math.sin(a)))
    return pts


def _pin_path(r: float, length: float) -> str:
    phi = math.acos(r / length)
    lx, ly = PIN_CX - r * math.sin(phi), PIN_CY + r * math.cos(phi)
    rx, ry = PIN_CX + r * math.sin(phi), ly
    return (
        f"M{PIN_CX:.2f} {PIN_CY + length:.2f}L{rx:.2f} {ry:.2f}"
        f"A{r:.2f} {r:.2f} 0 1 0 {lx:.2f} {ly:.2f}Z"
    )


# ---------------------------------------------------------------- SVG

def glyph_svg(mono: bool = False) -> str:
    """Capas del glifo (sin fondo). En mono el interior del pin queda vacío."""
    hole = "#000" if mono else SELVA
    dot = WHITE if mono else BOROJO
    ring_r = (RING_OUTER + RING_INNER) / 2
    ring_w = RING_OUTER - RING_INNER
    moat_r, moat_l = _offset_pin(MOAT)
    in_r, in_l = _offset_pin(-PIN_STROKE)
    return (
        '<mask id="q" maskUnits="userSpaceOnUse" x="0" y="0" width="108" height="108"><rect width="108" height="108" fill="#fff"/>'
        f'<path d="{_pin_path(moat_r, moat_l)}" fill="#000"/></mask>'
        f'<circle cx="{CX}" cy="{CY}" r="{ring_r:.2f}" fill="none" stroke="{WHITE}" '
        f'stroke-width="{ring_w:.2f}" mask="url(#q)"/>'
        + (
            '<mask id="p" maskUnits="userSpaceOnUse" x="0" y="0" width="108" height="108"><rect width="108" height="108" fill="#fff"/>'
            f'<path d="{_pin_path(in_r, in_l)}" fill="#000"/></mask>'
            f'<path d="{_pin_path(PIN_R, PIN_L)}" fill="{WHITE}" mask="url(#p)"/>'
            if mono
            else f'<path d="{_pin_path(PIN_R, PIN_L)}" fill="{WHITE}"/>'
            f'<path d="{_pin_path(in_r, in_l)}" fill="{hole}"/>'
        )
        + f'<circle cx="{PIN_CX:.2f}" cy="{PIN_CY:.2f}" r="{DOT_R}" fill="{dot}"/>'
    )


def icon_svg(crop: float = 72, radius: float = 0.22) -> str:
    """Ícono cuadrado con esquinas redondeadas, recortado al centro `crop`."""
    o = (108 - crop) / 2
    rx = crop * radius
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{o} {o} {crop} {crop}">'
        f'<rect x="{o}" y="{o}" width="{crop}" height="{crop}" rx="{rx:.2f}" fill="{SELVA}"/>'
        f"{glyph_svg()}</svg>\n"
    )


# ---------------------------------------------------------------- PNG

def _draw_glyph(img: Image.Image, scale: float, ox: float, mono: bool = False) -> None:
    """Dibuja el glifo sobre `img` (ya sobremuestreada). `ox` = origen en unidades."""

    def p(x: float, y: float) -> tuple[float, float]:
        return ((x - ox) * scale, (y - ox) * scale)

    def circle(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill) -> None:
        x0, y0 = p(cx - r, cy - r)
        x1, y1 = p(cx + r, cy + r)
        d.ellipse([x0, y0, x1, y1], fill=fill)

    def pin(d: ImageDraw.ImageDraw, r: float, length: float, fill) -> None:
        d.polygon([p(x, y) for x, y in _pin_points(r, length)], fill=fill)

    size = img.size
    # Aro de la Q con el foso alrededor del pin, como máscara alfa.
    ring = Image.new("L", size, 0)
    d = ImageDraw.Draw(ring)
    circle(d, CX, CY, RING_OUTER, 255)
    circle(d, CX, CY, RING_INNER, 0)
    pin(d, *_offset_pin(MOAT), 0)

    # Pin: borde blanco, interior hueco/verde y punto.
    pin_mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(pin_mask)
    pin(d, PIN_R, PIN_L, 255)
    in_r, in_l = _offset_pin(-PIN_STROKE)
    pin(d, in_r, in_l, 0)

    dot_mask = Image.new("L", size, 0)
    circle(ImageDraw.Draw(dot_mask), PIN_CX, PIN_CY, DOT_R, 255)

    img.paste(WHITE, (0, 0), ring)
    img.paste(WHITE, (0, 0), pin_mask)
    img.paste(WHITE if mono else BOROJO, (0, 0), dot_mask)


def render(px: int, *, crop: float = 108, background: bool = True,
           radius: float = 0.0, mono: bool = False) -> Image.Image:
    big = px * SS
    scale = big / crop
    ox = (108 - crop) / 2
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    if background:
        bg = Image.new("L", (big, big), 0)
        ImageDraw.Draw(bg).rounded_rectangle(
            [0, 0, big - 1, big - 1], radius=int(big * radius), fill=255
        )
        img.paste(SELVA, (0, 0), bg)
    _draw_glyph(img, scale, ox, mono=mono)
    return img.resize((px, px), Image.LANCZOS)


def save(img: Image.Image, rel: str) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print(f"  {rel}  ({img.size[0]}px)")


def main() -> None:
    res = "app/android/app/src/main/res"
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

    print("Android")
    for name, f in densities.items():
        # Capas del ícono adaptativo (lienzo completo de 108dp).
        save(render(round(108 * f), background=False), f"{res}/mipmap-{name}/ic_launcher_foreground.png")
        save(render(round(108 * f), background=False, mono=True), f"{res}/mipmap-{name}/ic_launcher_monochrome.png")
        # Íconos clásicos (Android 7 y anteriores): 48dp, recortados a lo visible.
        save(render(round(48 * f), crop=72, radius=0.22), f"{res}/mipmap-{name}/ic_launcher.png")
        round_img = render(round(48 * f), crop=72, radius=0.5)
        save(round_img, f"{res}/mipmap-{name}/ic_launcher_round.png")

    print("Play Store")
    save(render(512, crop=72), "branding/playstore-icon-512.png")

    print("Web (app Flutter)")
    save(render(32, crop=72, radius=0.22), "app/web/favicon.png")
    save(render(192, crop=72, radius=0.22), "app/web/icons/Icon-192.png")
    save(render(512, crop=72, radius=0.22), "app/web/icons/Icon-512.png")
    save(render(192), "app/web/icons/Icon-maskable-192.png")
    save(render(512), "app/web/icons/Icon-maskable-512.png")

    print("SVG")
    svg = icon_svg()
    for rel in ("branding/icon.svg", "app/web/favicon.svg", "admin/public/favicon.svg"):
        (ROOT / rel).write_text(svg)
        print(f"  {rel}")
    (ROOT / "branding/icon-monochrome.svg").write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">'
        f"{glyph_svg(mono=True)}</svg>\n"
    )
    print("  branding/icon-monochrome.svg")


if __name__ == "__main__":
    main()
