# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow"]
# ///
"""Writes palette.png: the gradient colormap the style samples by UV.

Run: `uv run styles/kenney_gradient/make_palette.py`. Each column is one swatch, each
swatch a vertical gradient from a light top to a deeper, bluer bottom. Edit the table and
re-run, or paint palette.png by hand in any image editor; the scene only needs the columns
to stay in the same order.
"""

from pathlib import Path

from PIL import Image

# name: (top colour, bottom colour), 0-255 sRGB
SWATCHES = {
    "lilac": ((222, 202, 240), (196, 168, 226)),
    "violet": ((176, 142, 222), (140, 108, 200)),
    "periwinkle": ((140, 134, 214), (106, 100, 190)),
    "teal": ((144, 218, 184), (92, 184, 152)),
    "orange": ((250, 186, 134), (238, 150, 110)),
    "peach": ((228, 168, 148), (204, 132, 124)),
    "ghost": ((255, 253, 255), (216, 196, 242)),
    "deep": ((110, 96, 176), (78, 66, 148)),
}
CELL_W = 16
HEIGHT = 64


def main() -> None:
    image = Image.new("RGB", (CELL_W * len(SWATCHES), HEIGHT))
    for index, (top, bottom) in enumerate(SWATCHES.values()):
        for y in range(HEIGHT):
            t = y / (HEIGHT - 1)
            colour = tuple(round(top[c] + (bottom[c] - top[c]) * t) for c in range(3))
            for x in range(CELL_W):
                image.putpixel((index * CELL_W + x, y), colour)
    image.save(Path(__file__).with_name("palette.png"))


if __name__ == "__main__":
    main()
