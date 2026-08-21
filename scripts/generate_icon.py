#!/usr/bin/env python3
"""
Generate the RINGER GO BRRR app icon (1024x1024 PNG).

Dependencies: Pillow
    pip install Pillow

Produces:
    RingerGoBRRR/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
"""

import math
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("ERROR: Pillow not installed. Run: pip install Pillow")
    sys.exit(1)

SIZE = 1024
OUT_PATH = os.path.join(
    os.path.dirname(__file__),
    "..",
    "RingerGoBRRR",
    "Assets.xcassets",
    "AppIcon.appiconset",
    "AppIcon-1024.png",
)

# Brand colours
BG          = (11, 11, 15, 255)       # #0B0B0F
PURPLE      = (155, 92, 255, 255)     # #9B5CFF
PINK        = (255, 60, 172, 255)     # #FF3CAC
OFF_WHITE   = (245, 245, 245, 255)    # #F5F5F5


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(4))


def draw_gradient_rect(draw, x0, y0, x1, y1, c1, c2, steps=200):
    """Horizontal gradient fill."""
    for i in range(steps):
        t = i / steps
        c = lerp_color(c1, c2, t)
        lx = x0 + (x1 - x0) * (i / steps)
        rx = x0 + (x1 - x0) * ((i + 1) / steps)
        draw.rectangle([lx, y0, rx, y1], fill=c)


def main():
    img = Image.new("RGBA", (SIZE, SIZE), BG)
    draw = ImageDraw.Draw(img)

    cx, cy = SIZE // 2, SIZE // 2

    # ── Background radial glow (fake with concentric filled circles) ──────────
    for r in range(480, 0, -4):
        t = r / 480
        alpha = int(60 * (1 - t))
        c = lerp_color((*PURPLE[:3], alpha), (*PINK[:3], 0), t)
        draw.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            fill=(*c[:3], c[3]),
        )

    # ── Switch body ───────────────────────────────────────────────────────────
    sw_w, sw_h = 160, 340
    sw_x0 = cx - sw_w // 2
    sw_y0 = cy - sw_h // 2 - 40
    sw_x1 = sw_x0 + sw_w
    sw_y1 = sw_y0 + sw_h
    radius = sw_w // 2

    # Outer capsule (gradient)
    for i in range(sw_h):
        t = i / sw_h
        c = lerp_color(PURPLE, PINK, t)
        y = sw_y0 + i
        draw.rectangle([sw_x0 + 4, y, sw_x1 - 4, y + 1], fill=c)

    # Capsule mask (rounded ends)
    draw.rounded_rectangle([sw_x0, sw_y0, sw_x1, sw_y1], radius=radius, fill=None,
                            outline=OFF_WHITE, width=6)

    # Inner track
    inset = 18
    draw.rounded_rectangle(
        [sw_x0 + inset, sw_y0 + inset, sw_x1 - inset, sw_y1 - inset],
        radius=radius - inset,
        fill=BG,
    )

    # Thumb knob (positioned in upper half = RING mode position)
    knob_r = 52
    knob_cx = cx
    knob_cy = sw_y0 + sw_h // 4 + 20

    # Knob glow
    for gr in range(knob_r + 30, knob_r - 1, -2):
        t = (gr - knob_r) / 30
        alpha = int(180 * (1 - t))
        draw.ellipse(
            [knob_cx - gr, knob_cy - gr, knob_cx + gr, knob_cy + gr],
            fill=(*PURPLE[:3], alpha),
        )

    draw.ellipse(
        [knob_cx - knob_r, knob_cy - knob_r, knob_cx + knob_r, knob_cy + knob_r],
        fill=PURPLE,
    )
    # Knob shine
    draw.ellipse(
        [knob_cx - knob_r + 8, knob_cy - knob_r + 8,
         knob_cx - knob_r + 28, knob_cy - knob_r + 28],
        fill=(*OFF_WHITE[:3], 120),
    )

    # ── Motion lines (BRRR effect) ────────────────────────────────────────────
    line_x_start = sw_x1 + 20
    for i, (dy, length, alpha) in enumerate([
        (-60, 90,  220),
        (-30, 120, 180),
        (  0, 140, 200),
        ( 30, 120, 180),
        ( 60, 90,  220),
    ]):
        t = i / 4
        c = lerp_color((*PURPLE[:3], alpha), (*PINK[:3], alpha), t)
        lw = 6 - i % 2
        draw.line(
            [line_x_start, knob_cy + dy,
             line_x_start + length, knob_cy + dy],
            fill=c, width=lw,
        )
        # Mirror on left
        draw.line(
            [sw_x0 - 20, knob_cy + dy,
             sw_x0 - 20 - length, knob_cy + dy],
            fill=c, width=lw,
        )

    # ── "BRRR" text ───────────────────────────────────────────────────────────
    text = "BRRR"
    # Try to load a bold system font; fall back to default
    font = None
    font_size = 130
    for font_path in [
        "/System/Library/Fonts/Supplemental/Impact.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/Library/Fonts/Arial Bold.ttf",
    ]:
        if os.path.exists(font_path):
            try:
                font = ImageFont.truetype(font_path, font_size)
                break
            except Exception:
                pass

    if font is None:
        font = ImageFont.load_default()

    # Text position — below the switch
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = cx - tw // 2
    ty = sw_y1 + 30

    # Text gradient (draw each character with interpolated colour)
    for idx, char in enumerate(text):
        t = idx / max(len(text) - 1, 1)
        c = lerp_color(PURPLE, PINK, t)
        char_bbox = draw.textbbox((0, 0), text[:idx], font=font)
        char_offset = char_bbox[2] - char_bbox[0]
        draw.text((tx + char_offset, ty), char, font=font, fill=c)

    # ── Save ──────────────────────────────────────────────────────────────────
    os.makedirs(os.path.dirname(os.path.abspath(OUT_PATH)), exist_ok=True)
    img.save(OUT_PATH, "PNG")
    print(f"Icon saved → {OUT_PATH}")


if __name__ == "__main__":
    main()
