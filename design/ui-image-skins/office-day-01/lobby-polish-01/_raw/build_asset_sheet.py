"""Compose the generated assets and record dimensions/alpha without modifying artwork."""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT.parents[3] / "godot" / "assets" / "ui" / "office-day-01" / "lobby-polish-01"
SPECS = {
    "speaker_on": (512, 512), "speaker_off": (512, 512),
    "menu_settings": (560, 152), "menu_archive": (560, 152), "menu_association": (560, 152),
    "deploy_surface": (640, 296), "operator_surface": (752, 196),
    "deploy_corner": (64, 64), "deploy_warning_tile": (48, 20), "deploy_streak": (112, 16),
}
sheet = Image.new("RGB", (1040, 1030), "#FBF6EC")
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 17)
heading = ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf", 28)
draw.text((32, 20), "서울 히어로 · 로비 제작 PNG 소재", fill="#24395C", font=heading)
draw.text((32, 63), "유리 투과·움직이는 빛은 실제 게임 캡처에서 확인", fill="#53657B", font=font)
validation = []
for name, size in SPECS.items():
    path = ROOT / (name + ".png")
    im = Image.open(path)
    alpha = im.getchannel("A")
    entry = {"file": path.name, "size": list(im.size), "mode": im.mode,
             "alpha_extrema": list(alpha.getextrema()), "has_alpha_zero": alpha.histogram()[0] > 0,
             "dimensions_match": im.size == size,
             "runtime_copy_matches": hashlib.sha256(path.read_bytes()).hexdigest() == hashlib.sha256((RUNTIME/path.name).read_bytes()).hexdigest(),
             "text_logo_visual_check": "none", "fake_checkerboard_visual_check": "none"}
    validation.append(entry)
    if not entry["dimensions_match"] or im.mode != "RGBA" or not entry["has_alpha_zero"] or not entry["runtime_copy_matches"]:
        raise ValueError(entry)

def place(name, xy, size):
    im = Image.open(ROOT / (name+".png")).convert("RGBA").resize(size, Image.Resampling.LANCZOS)
    sheet.paste(im, xy, im)
    draw.text((xy[0], xy[1]+size[1]+6), name+".png", fill="#24395C", font=font)

place("speaker_on", (40, 110), (160, 160))
place("speaker_off", (238, 110), (160, 160))
place("operator_surface", (500, 130), (500, 130))
for name, x in [("speaker_on",40),("speaker_off",238)]:
    im = Image.open(ROOT/(name+".png")).resize((32,32),Image.Resampling.LANCZOS)
    sheet.paste(im,(x,308),im)
    draw.text((x+42,312),"실제 32px",fill="#53657B",font=font)
for i,name in enumerate(["menu_settings","menu_archive","menu_association"]):
    place(name,(24,385+i*173),(560,152))
place("deploy_surface",(590,396),(420,194))
place("deploy_corner",(612,662),(80,80))
place("deploy_streak",(774,688),(224,32))
tile = Image.open(ROOT/"deploy_warning_tile.png")
for i in range(7): sheet.paste(tile,(612+i*48,803),tile)
draw.text((612,833),"deploy_warning_tile.png · 반복",fill="#24395C",font=font)
draw.text((32,983),"원본·프롬프트: _raw/manifest_surfaces.json, manifest_speaker_decor.json",fill="#53657B",font=font)
sheet.save(ROOT/"contact_sheet.png")
(ROOT/"_raw"/"validation_assets.json").write_text(json.dumps(validation,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps({"png_count":len(validation),"size_mode_alpha_runtime_copy":"passed"},ensure_ascii=False))
