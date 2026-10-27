#!/usr/bin/env python3
"""Generates the app icon at every size iOS needs.

Draws one 1024x1024 master (a skeuomorphic grid of app-icon squares behind
a magnifying glass, nodding at the site's own "pinstripe"/Cydia-era look
without copying any app's actual artwork) and downsamples it to every size
`CFBundleIcons`/`CFBundleIcons~ipad` in Info.plist names. Run from this
directory: `python3 make-icons.py`.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
HERE = Path(__file__).resolve().parent

# (basename, pixel size)
TARGETS = [
    ("AppIcon-20@1x", 20), ("AppIcon-20@2x", 40), ("AppIcon-20@3x", 60),
    ("AppIcon-29@1x", 29), ("AppIcon-29@2x", 58), ("AppIcon-29@3x", 87),
    ("AppIcon-40@1x", 40), ("AppIcon-40@2x", 80), ("AppIcon-40@3x", 120),
    ("AppIcon-60@2x", 120), ("AppIcon-60@3x", 180),
    ("AppIcon-76@1x", 76), ("AppIcon-76@2x", 152),
    ("AppIcon-83.5@2x", 167),
]


def lerp(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw_master() -> Image.Image:
    top = (58, 123, 213)      # iOS 6-era "Settings blue" gradient
    bottom = (16, 58, 128)
    img = Image.new("RGB", (SIZE, SIZE), bottom)
    px = img.load()
    for y in range(SIZE):
        color = lerp(top, bottom, y / (SIZE - 1))
        for x in range(SIZE):
            px[x, y] = color

    draw = ImageDraw.Draw(img, "RGBA")

    # A 3x3 grid of small rounded "app" squares - the archive's icon grid,
    # the same shape every card on the home screen draws.
    margin = 170
    gap = 46
    cell = (SIZE - 2 * margin - 2 * gap) // 3
    radius = int(cell * 0.2237)  # the modern squircle ratio, for the grid tiles
    for row in range(3):
        for col in range(3):
            x0 = margin + col * (cell + gap)
            y0 = margin + row * (cell + gap)
            shade = 235 - (row * 3 + col) * 6
            draw.rounded_rectangle(
                [x0, y0, x0 + cell, y0 + cell],
                radius=radius,
                fill=(shade, shade, shade, 235),
            )

    # A magnifying glass over the grid, for the one piece of interaction
    # the site's header actually shows (the search icon).
    cx, cy = SIZE * 0.68, SIZE * 0.68
    r = SIZE * 0.17
    ring_width = int(SIZE * 0.045)
    draw.ellipse(
        [cx - r, cy - r, cx + r, cy + r],
        outline=(255, 255, 255, 255),
        width=ring_width,
    )
    handle_len = SIZE * 0.17
    angle = math.radians(45)
    hx0 = cx + r * math.cos(angle)
    hy0 = cy + r * math.sin(angle)
    hx1 = hx0 + handle_len * math.cos(angle)
    hy1 = hy0 + handle_len * math.sin(angle)
    draw.line([hx0, hy0, hx1, hy1], fill=(255, 255, 255, 255), width=int(ring_width * 1.15))

    # A soft top gloss highlight - the skeuomorphic touch the site's own
    # "pinstripe" body class is going for.
    gloss = Image.new("L", (SIZE, SIZE), 0)
    gloss_draw = ImageDraw.Draw(gloss)
    gloss_draw.ellipse([-SIZE * 0.2, -SIZE * 0.65, SIZE * 1.2, SIZE * 0.55], fill=70)
    gloss = gloss.filter(ImageFilter.GaussianBlur(SIZE * 0.03))
    white = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255))
    img = Image.composite(white, img.convert("RGBA"), gloss)

    return img.convert("RGB")


def main() -> None:
    master = draw_master()
    master.save(HERE / "AppIcon.png")
    master.save(HERE / "AppIcon-source.png")
    for name, size in TARGETS:
        resized = master.resize((size, size), Image.LANCZOS)
        resized.save(HERE / f"{name}.png")
    print(f"Wrote AppIcon.png (1024) and {len(TARGETS)} sized icons to {HERE}")


if __name__ == "__main__":
    main()
