"""Build compact WebP runtime copies of the retained casual-art PNG masters."""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets"
GROUPS = (
    (ROOT / "ui/weapons", "*_casual_01.png", 768),
    (ROOT / "ui/archive", "*_casual_01.png", 768),
    (ROOT / "combat-chibi", "*.png", 768),
    (ROOT / "guild", "guild_hall_casual_01.png", 1672),
)

for directory, pattern, max_width in GROUPS:
    for source in directory.glob(pattern):
        with Image.open(source) as original:
            image = original.convert("RGBA")
            if image.width > max_width:
                height = round(image.height * max_width / image.width)
                image = image.resize((max_width, height), Image.Resampling.LANCZOS)
            destination = source.with_suffix(".webp")
            image.save(destination, "WEBP", quality=90, method=6, exact=True)
            print(f"{source.name}: {source.stat().st_size // 1024} KB -> {destination.stat().st_size // 1024} KB")
