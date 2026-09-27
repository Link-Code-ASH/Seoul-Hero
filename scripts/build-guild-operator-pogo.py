"""Cut generated directional pogo illustrations into independently animated layers."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1] / "assets" / "guild"
DIRECTIONS = {
    "down": ("guild_operator_han_seoa_topdown_01", 915),
    "up": ("guild_operator_han_seoa_up_01", 1365),
    "right": ("guild_operator_han_seoa_right_01", 1400),
    "left": ("guild_operator_han_seoa_left_01", 1400),
}


def save_webp(image: Image.Image, stem: str) -> None:
    image.save(ROOT / f"{stem}.webp", "WEBP", quality=88, method=6)


for direction, (stem, spring_start) in DIRECTIONS.items():
    source = Image.open(ROOT / f"{stem}.png").convert("RGBA")
    save_webp(source, stem)
    upper = source.crop((0, 0, source.width, spring_start))
    save_webp(upper, f"guild_operator_pogo_{direction}_upper_01")

# The coil and rubber tip are nearly rotationally symmetric. Using one set of
# layers keeps the spring mechanism consistent while the illustrated rider turns.
front = Image.open(ROOT / "guild_operator_han_seoa_topdown_01.png").convert("RGBA")
save_webp(front.crop((215, 912, 365, 1010)), "guild_operator_pogo_spring_01")
save_webp(front.crop((225, 999, 355, 1116)), "guild_operator_pogo_tip_01")
