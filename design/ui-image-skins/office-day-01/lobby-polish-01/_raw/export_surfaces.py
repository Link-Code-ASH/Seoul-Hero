"""Resample generated raster originals to their fixed UI canvases; no painted art."""
import json
from pathlib import Path
from shutil import copy2

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT.parents[3] / "godot" / "assets" / "ui" / "office-day-01" / "lobby-polish-01"

def export(entry):
    original = Path(entry["source"])
    raw = ROOT / "_raw" / (entry["name"] + "_generated.png")
    copy2(original, raw)
    im = Image.open(raw).convert("RGBA")
    bbox = im.getchannel("A").point(lambda a: 255 if a >= 24 else 0).getbbox()
    if not bbox:
        raise ValueError(f"Empty generated alpha: {original}")
    inset = entry["inset"]
    box = [max(0, bbox[0]-2), max(0, bbox[1]-2), min(im.width,bbox[2]+2), min(im.height,bbox[3]+2)]
    target = Image.new("RGBA", tuple(entry["size"]), (0,0,0,0))
    artwork = im.crop(box).resize(tuple(entry["body"]), Image.Resampling.LANCZOS)
    target.paste(artwork, tuple(inset))
    final = ROOT / (entry["name"] + ".png")
    target.save(final)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    copy2(final, RUNTIME / final.name)
    entry["crop"] = box
    entry["alpha_extrema"] = target.getchannel("A").getextrema()
    entry["raw_file"] = str(raw.relative_to(ROOT))
    entry["source_size"] = list(im.size)
    return entry

if __name__ == "__main__":
    manifest_path = ROOT / "_raw" / "manifest_surfaces.json"
    entries = json.loads(manifest_path.read_text(encoding="utf-8"))
    entries = [export(entry) for entry in entries]
    manifest_path.write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps([{k: e[k] for k in ("name","size","alpha_extrema","crop")} for e in entries], ensure_ascii=False))
