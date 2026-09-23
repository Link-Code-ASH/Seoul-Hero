"""Make high-quality, alpha-preserving WebP copies for runtime art.

The original PNG artwork stays in assets as the editable source. Runtime imports
exclude these PNGs so a mobile browser downloads only the smaller WebP copies.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets"
SOURCES = [
    *sorted((ROOT / "enemies").glob("enemy_*_01.png")),
    *sorted((ROOT / "bosses").glob("boss_*_01.png")),
    ROOT / "characters" / "player_plaza_01.png",
    ROOT / "backgrounds" / "gwanghwamun_plaza_01.png",
]

for source in SOURCES:
    target = source.with_suffix(".webp")
    with Image.open(source) as image:
        image.save(target, format="WEBP", quality=95, method=6)
    print(f"{source.relative_to(ROOT)}: {source.stat().st_size // 1024} → {target.stat().st_size // 1024} KiB")
