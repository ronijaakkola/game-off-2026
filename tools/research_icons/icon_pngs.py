# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow"]
# ///
"""Makes the research tiles' icon files from the renders of `render_icons.py`.

  uv run tools/research_icons/icon_pngs.py <renders> [icon ...]

For each render (all in <renders> when none are named): a white edge round the shape, as a
sticker's, cropped square to it, then every size in SIZES, shrunk with a good filter and
lightly sharpened, plus a white silhouette at each size for a hidden tile. They go to
game/research/icons/rendered/ as <icon>_<size>.png and <icon>_silhouette_<size>.png.
"""

import sys
from pathlib import Path

from PIL import Image, ImageFilter

OUT = Path(__file__).resolve().parents[2] / "game/research/icons/rendered"
# Pixels per side, one file each: the tile draws the icon at 36 px times the UI's scale and
# picks the size nearest above it, so it barely scales and stays crisp (RenderedIcon).
SIZES = (36, 54, 60, 72, 80, 108, 144)
# The white edge's width in render pixels. A render shrinks about 13 times to 36 px, so
# this comes to about 1.3 px there: still a solid line rather than broken dots.
EDGE = 17
EDGE_COLOR = (245, 242, 255)


def main() -> None:
    renders = Path(sys.argv[1])
    names = sys.argv[2:] or sorted(path.stem for path in renders.glob("*.png"))
    OUT.mkdir(parents=True, exist_ok=True)
    for name in names:
        make(renders / f"{name}.png", name)


def make(render: Path, name: str) -> None:
    raw = Image.open(render).convert("RGBA")
    shape = raw.getchannel("A").point(lambda v: 255 if v > 20 else 0)
    grown = (
        shape.filter(ImageFilter.MaxFilter(EDGE * 2 + 1))
        .filter(ImageFilter.GaussianBlur(1))
        .point(lambda v: 255 if v > 128 else 0)
    )
    edge = Image.new("RGBA", raw.size, (*EDGE_COLOR, 0))
    edge.putalpha(grown)
    # Square round the edged shape plus a little, so the art fills the tile.
    box = grown.getbbox()
    side = max(box[2] - box[0], box[3] - box[1]) + 8
    cx, cy = (box[0] + box[2]) // 2, (box[1] + box[3]) // 2
    crop = (cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2)
    art = Image.alpha_composite(edge, raw).crop(crop)
    silhouette = Image.new("RGBA", raw.size, (255, 255, 255, 0))
    silhouette.putalpha(shape)
    silhouette = silhouette.crop(crop)
    for size in SIZES:
        # A light sharpen after the shrink, which softens edges; stronger leaves dark halos.
        small = art.resize((size, size), Image.LANCZOS)
        small = small.filter(ImageFilter.UnsharpMask(radius=0.7, percent=70, threshold=0))
        small.save(OUT / f"{name}_{size}.png")
        silhouette.resize((size, size), Image.LANCZOS).save(OUT / f"{name}_silhouette_{size}.png")


if __name__ == "__main__":
    main()
