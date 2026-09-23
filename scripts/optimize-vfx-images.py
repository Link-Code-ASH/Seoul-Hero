"""Trim and downsample generated transparent VFX without destroying soft alpha edges."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets" / "effects"

for path in sorted(ROOT.glob("effect_vfx_*.png")):
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A")
    if alpha.getextrema()[0] == 255:
        raise RuntimeError(f"{path.name} has no transparent pixels")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError(f"{path.name} is fully transparent")
    left, top, right, bottom = bbox
    padding = max(12, round(max(right - left, bottom - top) * 0.06))
    box = (
        max(0, left - padding),
        max(0, top - padding),
        min(image.width, right + padding),
        min(image.height, bottom + padding),
    )
    image = image.crop(box)
    max_edge = 1024 if "chain" in path.name else 768
    image.thumbnail((max_edge, max_edge), Image.Resampling.LANCZOS)
    image.save(path, optimize=True)
    print(f"{path.name}: {image.width}x{image.height}, alpha={image.getchannel('A').getextrema()}")
