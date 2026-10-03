"""Rebuild shared Godot VFX cutouts without changing actor profiles or map art.

The reviewed source sheet is archived outside the runtime project.
No character parts, monster rigs, or preview portraits are generated.
"""
from pathlib import Path

from PIL import Image, ImageFilter

PROJECT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT.parent / "archive/legacy-godot-visuals/source/vfx-source.png"
OUTPUT = PROJECT / "assets/visuals/vfx"
RECTANGLES = {
    "shockwave": (546, 43, 1015, 539),
    "smoke": (1016, 37, 1536, 539),
    "spark": (19, 599, 537, 978),
    "debris": (598, 575, 988, 976),
}


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, rectangle in RECTANGLES.items():
        image = source.crop(rectangle)
        image.thumbnail((320, 320), Image.Resampling.LANCZOS)
        image.save(OUTPUT / f"{name}.png", optimize=True)

    shadow = Image.new("RGBA", (128, 64))
    pixels = shadow.load()
    for y in range(64):
        for x in range(128):
            radius = ((x - 63.5) / 60) ** 2 + ((y - 31.5) / 26) ** 2
            alpha = int(105 * max(0, 1 - radius) ** 1.6)
            pixels[x, y] = (5, 13, 19, alpha)
    shadow.filter(ImageFilter.GaussianBlur(3)).save(OUTPUT / "contact_shadow.png")
    print("Shared VFX cutouts prepared; actors.json and map artwork unchanged.")


if __name__ == "__main__":
    main()
