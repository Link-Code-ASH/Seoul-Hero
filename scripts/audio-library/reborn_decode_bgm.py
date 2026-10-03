"""Read provided MP3s into short offline caches; no ACL or game writes."""
import json
from pathlib import Path
import sys
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'audio-library/reborn-01'
sys.path.insert(0, str(OUTPUT / '.tools'))
import miniaudio

content = json.loads((ROOT / 'godot/data/content.json').read_text(encoding='utf-8'))
destination = OUTPUT / 'decoded-bgm'
destination.mkdir(exist_ok=True)
for group in content['bgm'].values():
    for track in group['tracks']:
        source = ROOT / 'godot' / track['url'].removeprefix('res://')
        decoded = miniaudio.decode_file(str(source), output_format=miniaudio.SampleFormat.FLOAT32,
                                       nchannels=2, sample_rate=48000)
        x = np.asarray(decoded.samples, dtype=np.float32).reshape(-1, 2)[:20 * 48000]
        if not np.isfinite(x).all(): raise ValueError(f'Invalid MP3 decode: {source}')
        np.save(destination / (source.stem + '.npy'), x)
        print(f'BGM read-only excerpt {source.name}: {len(x) / 48000:.1f}s', flush=True)
