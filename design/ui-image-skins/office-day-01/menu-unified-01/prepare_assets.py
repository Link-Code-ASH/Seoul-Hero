"""Copy generated originals and normalize raster delivery sizes; no painted art generation."""
from pathlib import Path
import json
import shutil
import numpy as np
from PIL import Image

def central_component_box(alpha):
    mask = alpha > 180
    visited = np.zeros(mask.shape, dtype=bool)
    height, width = mask.shape
    stack = [(height // 2, width // 2)]
    min_x, min_y, max_x, max_y = width, height, 0, 0
    while stack:
        y, x = stack.pop()
        if visited[y, x] or not mask[y, x]:
            continue
        left = right = x
        while left > 0 and mask[y, left - 1] and not visited[y, left - 1]:
            left -= 1
        while right + 1 < width and mask[y, right + 1] and not visited[y, right + 1]:
            right += 1
        visited[y, left:right + 1] = True
        min_x, max_x = min(min_x, left), max(max_x, right + 1)
        min_y, max_y = min(min_y, y), max(max_y, y + 1)
        for next_y in (y - 1, y + 1):
            if not 0 <= next_y < height:
                continue
            candidates = mask[next_y, left:right + 1] & ~visited[next_y, left:right + 1]
            starts = np.flatnonzero(candidates & ~np.concatenate(([False], candidates[:-1])))
            stack.extend((next_y, left + int(start)) for start in starts)
    return min_x, min_y, max_x, max_y

ROOT = Path(__file__).resolve().parent
DELIVERY = ROOT / 'assets'
SIZES = {
    'bg_settings': (1830, 824), 'bg_archive': (1830, 824),
    'bg_association': (1830, 824), 'bg_gate': (1830, 824),
    'glass_panel': (512, 384), 'glass_header': (1024, 128),
    'glass_button': (512, 160), 'glass_button_navy': (512, 160),
    'glass_row': (512, 112),
}

def main():
    DELIVERY.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((ROOT / '_raw' / 'manifest.json').read_text(encoding='utf-8'))
    checks = []
    for asset in manifest['assets']:
        name = asset['name']
        source = Path(asset['source'])
        if 'originalSource' in asset:
            shutil.copy2(asset['originalSource'], ROOT / '_raw' / f'{name}_original.png')
        shutil.copy2(source, ROOT / '_raw' / f'{name}.png')
        image = Image.open(source).convert('RGBA')
        original_size = image.size
        crop = (0, 0, *image.size)
        if name.startswith('glass_'):
            left, top, right, bottom = central_component_box(np.array(image.getchannel('A')))
            crop = (max(0, left - 2), max(0, top - 2),
                    min(image.width, right + 2), min(image.height, bottom + 2))
            image = image.crop(crop)
        image = image.resize(SIZES[name], Image.Resampling.LANCZOS)
        image.save(DELIVERY / f'{name}.png')
        alpha = np.array(image.getchannel('A'))
        checks.append({'file': f'{name}.png', 'size': list(image.size),
                       'mode': image.mode, 'originalSize': list(original_size),
                       'crop': list(crop), 'alphaMin': int(alpha.min()),
                       'alphaMax': int(alpha.max()),
                       'alphaCenter': int(alpha[image.height // 2, image.width // 2]),
                       'fullyTransparentPixels': int((alpha == 0).sum())})
    (ROOT / 'asset_checks.json').write_text(json.dumps(checks, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(checks, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
