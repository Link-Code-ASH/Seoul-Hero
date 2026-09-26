"""Local, deterministic sample editing. Python 3.12 + NumPy; no AI audio model.

python scripts/audio-library/build.py inventory|build|verify [--source PATH]
The source collection is read-only. Future sounds stay outside Vite asset globs.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import wave

import numpy as np

from recipes import ACTIVE, FAMILIES

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / 'audio-library'
RATE = 48000
VERSION = 1


def dump(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def header(path):
    """RIFF PCM/IEEE float, including WAVE_FORMAT_EXTENSIBLE and ancillary chunks."""
    with path.open('rb') as f:
        riff = f.read(12)
        if riff[:4] != b'RIFF' or riff[8:] != b'WAVE':
            raise ValueError(f'Unsupported WAV container: {path}')
        result = {}
        while chunk := f.read(8):
            if len(chunk) != 8:
                break
            tag, size = struct.unpack('<4sI', chunk)
            offset = f.tell()
            if tag == b'fmt ':
                fmt = f.read(size)
                code, channels, rate, _, align, bits = struct.unpack('<HHIIHH', fmt[:16])
                if code == 65534:
                    code = struct.unpack('<H', fmt[24:26])[0]
                if code not in (1, 3) or bits not in (16, 24, 32, 64):
                    raise ValueError(f'Unsupported WAV sample encoding {code}/{bits}: {path}')
                result.update(format=code, channels=channels, sample_rate=rate, bits=bits, align=align)
            elif tag == b'data':
                result.update(offset=offset, data_bytes=size)
            f.seek(offset + size + size % 2)
        result['frames'] = result['data_bytes'] // result['align']
        result['duration'] = result['frames'] / result['sample_rate']
        return result


def decode(raw, meta):
    bits = meta['bits']
    if meta['format'] == 3:
        x = np.frombuffer(raw, dtype='<f4' if bits == 32 else '<f8').astype(np.float32)
    elif bits == 24:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        x = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        x = ((x ^ 0x800000) - 0x800000).astype(np.float32) / 8388608
    else:
        x = np.frombuffer(raw, dtype='<i2' if bits == 16 else '<i4').astype(np.float32) / (2 ** (bits - 1))
    if not np.isfinite(x).all():
        raise ValueError('Non-finite audio samples')
    return x.reshape(-1, meta['channels'])


def read_segment(path, meta, start, duration, stereo=False):
    first = max(0, round(start * meta['sample_rate']))
    count = min(round(duration * meta['sample_rate']), meta['frames'] - first)
    with path.open('rb') as f:
        f.seek(meta['offset'] + first * meta['align'])
        x = decode(f.read(count * meta['align']), meta)
    # More than two channels are never selected as sources in these recipes.
    if stereo and x.shape[1] == 2:
        return x
    mono = x.mean(axis=1, keepdims=True)
    # Avoid stereo cancellation: retain the strongest channel if downmix loses >12dB.
    if np.mean(mono ** 2) < np.mean(x ** 2) * .063:
        mono = x[:, [int(np.argmax(np.mean(x ** 2, axis=0)))]]
    return np.repeat(mono, 2, axis=1) if stereo else mono


def analyze(path, source):
    m = header(path)
    envelopes = []
    peak, square_sum, count, clipped = 0.0, 0.0, 0, 0
    centroid_sum, centroid_count = 0.0, 0
    with path.open('rb') as f:
        f.seek(m['offset'])
        remaining = m['data_bytes']
        while remaining:
            raw = f.read(min(remaining, m['sample_rate'] * m['align']))
            remaining -= len(raw)
            x = decode(raw, m)
            if not len(x):
                break
            peak = max(peak, float(np.max(np.abs(x))))
            square_sum += float(np.sum(x.astype(np.float64) ** 2))
            count += x.size
            clipped += int(np.count_nonzero(np.abs(x) >= .9999))
            frame = max(1, m['sample_rate'] // 100)
            # Channel energy rather than mean signal avoids phase cancellation in inventory.
            power = np.mean(x ** 2, axis=1)
            n = len(power) // frame
            envelopes.extend(np.sqrt(power[:n * frame].reshape(n, frame).mean(axis=1)).tolist())
            if centroid_count < 20:
                mono = x[:min(8192, len(x))].mean(axis=1)
                spectrum = np.abs(np.fft.rfft(mono * np.hanning(len(mono))))
                freqs = np.fft.rfftfreq(len(mono), 1 / m['sample_rate'])
                centroid_sum += float(np.sum(freqs * spectrum) / max(np.sum(spectrum), 1e-12))
                centroid_count += 1
    env = np.asarray(envelopes)
    threshold = max(float(env.max(initial=0)) * .08, 0.0001)
    active = np.flatnonzero(env > threshold)
    first = max(0, int(active[0]) - 2) if len(active) else 0
    last = min(len(env), int(active[-1]) + 6) if len(active) else len(env)
    # Independent transients: strong positive energy changes, separated by >=180 ms.
    previous = np.concatenate(([0.0], env[:-1]))
    score = np.maximum(0, env - previous) * np.sqrt(np.maximum(env, 0))
    events = [first]
    for i in np.argsort(score)[::-1]:
        if len(events) >= 20 or score[i] < score.max(initial=0) * .08:
            break
        onset = max(0, int(i) - 2)
        if env[i] > threshold and all(abs(onset - old) >= 18 for old in events):
            events.append(onset)
    return {
        'path': path.relative_to(source).as_posix(), 'sha256': digest(path),
        'pack': path.parent.name, 'bytes': path.stat().st_size, **m,
        'peak': peak, 'rms': float(np.sqrt(square_sum / max(count, 1))),
        'clipped_samples': clipped, 'spectral_centroid_hz': round(centroid_sum / max(centroid_count, 1), 1),
        'active_start': first / 100, 'active_end': min(m['duration'], last / 100),
        'events': sorted(i / 100 for i in events),
    }


def inventory(source):
    LIB.mkdir(exist_ok=True)
    old_path = LIB / 'inventory.json'
    old = {m['path']: m for m in json.loads(old_path.read_text(encoding='utf-8'))['sources']} if old_path.exists() else {}
    records = []
    files = sorted(source.glob('Sonniss.com-GDC2026-*/*/*.wav'))
    if not files:
        raise ValueError(f'No Sonniss WAV files found under {source}')
    for i, path in enumerate(files):
        rel = path.relative_to(source).as_posix()
        # Reuse only when source mtime and byte count match; build later hashes selected inputs.
        cached = old.get(rel)
        if cached and cached.get('mtime_ns') == path.stat().st_mtime_ns and cached['bytes'] == path.stat().st_size:
            record = cached
        else:
            record = analyze(path, source)
            record['mtime_ns'] = path.stat().st_mtime_ns
        records.append(record)
        if (i + 1) % 25 == 0:
            print(f'Inventory {i + 1}/{len(files)}', flush=True)
    licenses = []
    for i, folder in enumerate(sorted(source.glob('Sonniss.com-GDC2026-*')), 1):
        for p in sorted(folder.iterdir()):
            if p.suffix.lower() in ('.pdf', '.txt'):
                dest = LIB / 'provenance' / f'part-{i}' / p.name
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(p, dest)
                licenses.append({'source': p.relative_to(source).as_posix(), 'sha256': digest(p), 'copy': dest.relative_to(LIB).as_posix()})
    dump(old_path, {'version': VERSION, 'source_root': str(source), 'sources': records, 'licenses': licenses})
    print(f'Inventory complete: {len(records)} sources', flush=True)
    return records


def filter_audio(x, rate, low, high):
    """Smooth Butterworth-shaped spectral EQ, zero-padded against wraparound."""
    n = 1 << (len(x) + 2048 - 1).bit_length()
    freq = np.fft.rfftfreq(n, 1 / rate)
    response = 1 / np.sqrt(1 + (freq / high) ** 8)
    if low:
        response *= 1 / np.sqrt(1 + (low / np.maximum(freq, .01)) ** 4)
    spectrum = np.fft.rfft(x, n=n, axis=0)
    return np.fft.irfft(spectrum * response[:, None], n=n, axis=0)[:len(x)].astype(np.float32)


def resample(x, input_rate, speed=1.0):
    if input_rate == RATE and speed == 1:
        return x
    # Bandlimit before resampling, including speed-up processing.
    x = filter_audio(x, input_rate, 0, min(input_rate * .44, RATE * .44 / speed))
    length = max(2, round(len(x) * RATE / input_rate / speed))
    positions = np.arange(length) * input_rate * speed / RATE
    return np.column_stack([np.interp(positions, np.arange(len(x)), x[:, c]) for c in range(x.shape[1])]).astype(np.float32)


def fade(x, attack=.003, release=.025):
    x = x.copy()
    a, r = min(len(x), round(attack * RATE)), min(len(x), round(release * RATE))
    if a:
        x[:a] *= np.linspace(0, 1, a, dtype=np.float32)[:, None]
    if r:
        x[-r:] *= np.linspace(1, 0, r, dtype=np.float32)[:, None]
    return x


def normalize(x, target, ceiling=.63):
    rms = float(np.sqrt(np.mean(x ** 2)))
    peak = float(np.max(np.abs(x)))
    if peak < 1e-7 or rms < 1e-8:
        raise ValueError('Silent source segment')
    gain = min(target / rms, ceiling / peak)
    return x * gain, gain


def write_wav(path, x):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not np.isfinite(x).all() or np.max(np.abs(x)) > 1:
        raise ValueError(f'Invalid output samples: {path}')
    # TPDF dither with a fixed seed, preserving exact digital silence at boundaries.
    rng = np.random.default_rng(20260926)
    dither = (rng.random(x.shape) - rng.random(x.shape)) / 65536
    pcm = np.round((x + dither * (x != 0)) * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(x.shape[1]); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes(pcm.tobytes())


def matching(records, selectors):
    result = []
    for selector in selectors:
        hits = [m for m in records if selector.lower() in Path(m['path']).name.lower() and m['channels'] <= 2]
        if not hits:
            raise ValueError(f'No source matches selector {selector!r}')
        for m in hits:
            if m not in result:
                result.append(m)
    return result


def loop_join(x, length):
    """Crossfade repeated material, then overlap the tail into the head at the seam."""
    cross = min(round(.18 * RATE), max(2, len(x) // 4))
    while len(x) < length + cross:
        ramp = np.linspace(0, 1, cross)[:, None]
        x = np.concatenate((x[:-cross], x[-cross:] * (1 - ramp) + x[:cross] * ramp, x[cross:]))
    x = x[:length + cross].copy()
    ramp = np.linspace(0, 1, cross)[:, None]
    head = x[-cross:] * (1 - ramp) + x[:cross] * ramp
    return np.concatenate((head, x[cross:length]))


def make_layer(source, m, seconds, variant, layer_index, ambient, high):
    speed = (1.0, .94, 1.035, .975, 1.015)[variant] if not ambient else 1.0
    # Primary differences come from sources/segments; slight speed changes are finishing only.
    if ambient:
        maximum = max(0, m['duration'] - seconds - .4)
        start = maximum * ((variant + layer_index * 2) % 5) / 4
        duration = min(m['duration'] - start, seconds + .4)
    else:
        events = m['events']
        event = events[(variant // 2 + layer_index) % len(events)]
        start = event
        duration = min(seconds * speed, m['duration'] - start)
    original = read_segment(source / m['path'], m, start, duration, ambient)
    original = resample(original, m['sample_rate'])
    # Source preview is un-EQ'd and unlayered, with only fades and safe level adjustment.
    preview, preview_gain = normalize(fade(original), .13)
    preview_id = hashlib.sha256(f'{m["sha256"]}:{start:.6f}:{duration:.6f}:{ambient}'.encode()).hexdigest()[:20]
    preview_path = LIB / 'source-previews' / f'{preview_id}.wav'
    if not preview_path.exists():
        write_wav(preview_path, preview)
    x = resample(original, RATE, speed)
    x -= x.mean(axis=0)
    x = filter_audio(x, RATE, 45 if ambient else 65, high)
    if not ambient:
        # Shorten sustained tails while retaining a natural attack.
        t = np.arange(len(x)) / RATE
        envelope = np.exp(-t / max(.06, seconds * .6))
        x *= envelope[:, None]
        x = fade(x, .002, min(.065, seconds * .2))
    x, gain = normalize(x, .18)
    return x, {
        'source': m['path'], 'sha256': m['sha256'], 'start': round(start, 6), 'duration': round(duration, 6),
        'speed': speed, 'highpass_hz': 45 if ambient else 65, 'lowpass_hz': high,
        'normalization_gain': gain, 'preview': preview_path.relative_to(LIB).as_posix(),
        'preview_gain': preview_gain, 'preview_note': '48kHz, safe gain and edge fades only; no layering or tonal EQ',
    }


def build(source, records):
    manifest = []
    recipe_keys = set()
    used_hashes = set()
    selections = {}
    # Validate all selectors before rendering; fail visibly rather than substitute arbitrary audio.
    for category, families in FAMILIES.items():
        for family, label, primary, secondary, seconds, high in families:
            selections[f'{category}/{family}'] = (matching(records, primary), matching(records, secondary))
    for category, families in FAMILIES.items():
        for family, label, primary, secondary, seconds, high in families:
            ppool, spool = selections[f'{category}/{family}']
            ambient = category == 'ambience'
            family_textures = set()
            for v in range(5):
                for attempt in range(len(ppool) * max(1, len(spool))):
                    p = ppool[(v + attempt) % len(ppool)]
                    # Try another source pair if a short source was already used in full.
                    sources = [p] + ([spool[(v + v // len(ppool) + attempt // len(ppool)) % len(spool)]] if spool else [])
                    layers = []
                    arrays = []
                    for li, m in enumerate(sources):
                        if m['path'] not in used_hashes:
                            if digest(source / m['path']) != m['sha256']:
                                raise ValueError(f'Source changed after inventory: {m["path"]}')
                            used_hashes.add(m['path'])
                        x, record = make_layer(source, m, seconds if li == 0 else seconds * (.9 if ambient else .75), v, li, ambient, high if li == 0 else high * .8)
                        record['mix_gain'] = 1.0 if li == 0 else (.18 if ambient else .32)
                        record['delay_seconds'] = 0 if ambient or li == 0 else .008 + v * .004
                        layers.append(record)
                        delay = round(record['delay_seconds'] * RATE)
                        arrays.append(np.pad(x * record['mix_gain'], ((delay, 0), (0, 0))))
                    key = tuple((r['source'], r['start'], r['duration']) for r in layers)
                    # A different speed/ceiling alone does not count as another variation.
                    texture_key = tuple((r['source'], r['start']) for r in layers)
                    if key not in recipe_keys and texture_key not in family_textures:
                        break
                else:
                    raise ValueError(f'Duplicate source/trim recipe {category}/{family}/{v}')
                recipe_keys.add(key)
                family_textures.add(texture_key)
                if ambient:
                    length = round(seconds * RATE)
                    mix = sum(loop_join(x, length) for x in arrays)
                else:
                    length = max(map(len, arrays))
                    mix = sum(np.pad(x, ((0, length - len(x)), (0, 0))) for x in arrays)
                    # Remove trailing silence only; never time-stretch to a fixed duration.
                    audible = np.flatnonzero(np.max(np.abs(mix), axis=1) > .0005)
                    if len(audible):
                        mix = mix[:min(len(mix), int(audible[-1]) + round(.012 * RATE))]
                    mix = fade(mix, .002, min(.04, len(mix) / RATE * .2))
                target = {'ui': .11, 'weapons': .13, 'impacts': .14, 'magic': .10, 'creatures': .13, 'ambience': .07}[category]
                mix, final_gain = normalize(mix, target)
                asset_id = f'{category}/{family}_{v + 1:02d}'
                path = LIB / 'sounds' / f'{asset_id}.wav'
                write_wav(path, mix)
                active = [event for event, (fam, n) in ACTIVE.items() if fam == f'{category}/{family}' and v < n]
                if active:
                    game_path = ROOT / 'assets/audio/sfx/sourced' / f'{asset_id}.wav'
                    game_path.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, game_path)
                manifest.append({
                    'id': asset_id, 'category': category, 'family': family, 'label': f'{label} {v + 1:02d}',
                    'file': path.relative_to(LIB).as_posix(), 'duration': len(mix) / RATE,
                    'channels': mix.shape[1], 'sample_rate': RATE, 'bits': 16, 'loop': ambient,
                    'active_events': active, 'tags': [label, category, family] + [Path(m['path']).parent.name for m in sources],
                    'layers': layers, 'final_gain': final_gain, 'target_rms': target,
                    'sha256': digest(path), 'listening_review': 'not_auditioned',
                })
            print(f'Rendered {category}/{family}: {len(manifest)}/450', flush=True)
    dump(LIB / 'manifest.json', {'version': VERSION, 'sample_rate': RATE, 'numpy_version': np.__version__,
         'builder_sha256': digest(Path(__file__)), 'recipes_sha256': digest(Path(__file__).with_name('recipes.py')),
         'processing': {'mono_downmix': 'mean; strongest channel if energy falls >12dB',
                        'eq': 'zero-padded smooth spectral high/low pass', 'layer_target_rms': .18,
                        'envelope': 'exp(-t/max(0.06,seconds*0.6)); one-shots only',
                        'layer_fades_seconds': [.002, 'min(.065,seconds*.2)'],
                        'final_fades_seconds': [.002, 'min(.04,duration*.2)'],
                        'loop_crossfade_seconds': .18, 'peak_ceiling': .63, 'dither_seed': 20260926},
         'listening_review': 'not_auditioned', 'sounds': manifest})
    # JS data allows the catalog to work directly from file:// as well as the local server.
    (LIB / 'catalog-data.js').write_text('window.AUDIO_LIBRARY = ' + json.dumps(manifest, ensure_ascii=False) + ';\n', encoding='utf-8')
    mapping = {event: [f'{family}_{i + 1:02d}' for i in range(n)] for event, (family, n) in ACTIVE.items()}
    dump(LIB / 'game-mapping.json', mapping)
    lines = ['// Generated by scripts/audio-library/build.py. Source/trim records: audio-library/manifest.json.',
             'export const sourcedSfxPaths = {']
    for event, ids in mapping.items():
        lines.append(f"  {event}: [" + ', '.join(f"'sfx/sourced/{name}.wav'" for name in ids) + '],')
    lines.append('} as const;\n')
    (ROOT / 'src/data/sourcedAudio.ts').write_text('\n'.join(lines), encoding='utf-8')
    comparisons(manifest)
    return manifest


def load_output(entry):
    path = LIB / entry['file']
    m = header(path)
    return read_segment(path, m, 0, m['duration'])


def comparisons(manifest):
    by_id = {m['id']: m for m in manifest}
    plans = {
        'shot-then-hit': [(i * .65, f'weapons/mana_bolt_{i % 5 + 1:02d}', .23) for i in range(12)]
            + [(i * .65 + .17, f'impacts/hit_light_{i % 5 + 1:02d}', .19) for i in range(12)],
        'dense-combat-warning': [(i * .1, f'weapons/turret_{i % 4 + 1:02d}', .13) for i in range(80)]
            + [(i * .14 + .04, f'impacts/hit_light_{i % 5 + 1:02d}', .19) for i in range(55)]
            + [(i * .7, f'weapons/slash_{i % 5 + 1:02d}', .28) for i in range(11)]
            + [(2, 'creatures/boss_warning_01', .55), (5, 'creatures/player_hit_01', .46), (6.5, 'impacts/arcane_blast_01', .4)],
        'ui-sequence': [(i * 1.0, name, .4) for i, name in enumerate(['ui/click_01', 'ui/purchase_01', 'ui/reroll_01', 'ui/lock_01', 'ui/supply_01', 'ui/result_01', 'ui/branch_01', 'ui/wave_clear_01'])],
    }
    records = []
    for name, events in plans.items():
        mix = np.zeros((RATE * 11, 1), dtype=np.float32)
        for start, asset_id, gain in events:
            x = load_output(by_id[asset_id]) * gain
            a = round(start * RATE)
            mix[a:a + len(x)] += x
        scale = min(1, .8 / max(float(np.max(np.abs(mix))), 1e-8))
        write_wav(LIB / 'comparisons' / f'{name}.wav', fade(mix * scale))
        records.append({'file': f'comparisons/{name}.wav', 'events': events, 'safety_gain': scale, 'note': 'Offline layering illustration; not a gameplay/AudioPolicy recording; no BGM.'})
    dump(LIB / 'comparisons' / 'recipes.json', records)


def verify():
    manifest = json.loads((LIB / 'manifest.json').read_text(encoding='utf-8'))['sounds']
    checks = []
    problems = []
    hashes = set()
    textures = set()
    for entry in manifest:
        path = LIB / entry['file']
        m = header(path)
        x = read_segment(path, m, 0, m['duration'], entry['channels'] == 2)
        peak = float(np.max(np.abs(x)))
        rms = float(np.sqrt(np.mean(x ** 2)))
        edge = float(np.max(np.abs(x[-1] - x[0])))
        largest_step = float(np.max(np.abs(np.diff(x, axis=0))))
        errors = []
        texture = (entry['category'], entry['family'], tuple((l['source'], l['start']) for l in entry['layers']))
        if texture in textures: errors.append('pitch_only_variation')
        textures.add(texture)
        if (m['sample_rate'], m['bits'], m['channels']) != (48000, 16, entry['channels']): errors.append('format')
        if peak > .631 or rms < .0001: errors.append('level')
        if not entry['loop'] and max(float(np.max(np.abs(x[0]))), float(np.max(np.abs(x[-1])))) > .0001: errors.append('edge')
        # Compare the loop seam with normal inter-sample movement, not arbitrary peak silence.
        if entry['loop'] and edge > max(.015, float(np.quantile(np.abs(np.diff(x, axis=0)), .999)) * 2): errors.append('loop_seam')
        sha = digest(path)
        if sha != entry['sha256'] or sha in hashes: errors.append('hash_or_duplicate')
        hashes.add(sha)
        if entry['active_events']:
            game_path = ROOT / 'assets/audio/sfx/sourced' / (entry['id'] + '.wav')
            if not game_path.exists() or digest(game_path) != sha: errors.append('game_copy')
        check = {'id': entry['id'], 'peak_dbfs': round(20 * np.log10(max(peak, 1e-9)), 2), 'rms_dbfs': round(20 * np.log10(max(rms, 1e-9)), 2), 'edge_step': edge, 'largest_step': largest_step, 'errors': errors}
        checks.append(check)
        if errors: problems.append(check)
    if len(manifest) != 450: problems.append({'count': len(manifest)})
    expected = dict(ui=60, weapons=120, impacts=90, magic=70, creatures=60, ambience=50)
    if dict(Counter(m['category'] for m in manifest)) != expected: problems.append({'category_counts': 'mismatch'})
    mapping = json.loads((LIB / 'game-mapping.json').read_text(encoding='utf-8'))
    if set(mapping) != set(ACTIVE): problems.append({'mapping': 'event mismatch'})
    audio_source = (ROOT / 'src/data/audio.ts').read_text(encoding='utf-8')
    wired = dict(re.findall(r"(\w+): cue\('([^']+)'", audio_source))
    if set(wired) != set(mapping) or any(event != mapped for event, mapped in wired.items()):
        problems.append({'mapping': 'audio.ts event wiring mismatch'})
    ids = {m['id'] for m in manifest}
    if any(i not in ids for group in mapping.values() for i in group): problems.append({'mapping': 'missing asset'})
    report = {'files': len(manifest), 'active_files': sum(bool(m['active_events']) for m in manifest), 'events': len(mapping), 'category_counts': expected,
              'used_sources': len({layer['source'] for m in manifest for layer in m['layers']}),
              'total_bytes': sum((LIB / m['file']).stat().st_size for m in manifest),
              'active_bytes': sum((LIB / m['file']).stat().st_size for m in manifest if m['active_events']),
              'auditory_review': 'NOT PERFORMED: no audio perception tool available', 'gameplay_qa': 'NOT PERFORMED: user-owned',
              'problems': problems, 'measurements': checks}
    dump(LIB / 'verification.json', report)
    print(json.dumps({k: v for k, v in report.items() if k != 'measurements'}, ensure_ascii=True), flush=True)
    if problems:
        raise ValueError(f'{len(problems)} asset verification failures')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['inventory', 'build', 'verify'])
    parser.add_argument('--source', type=Path, default=Path.home() / 'Music')
    args = parser.parse_args()
    if os.name == 'nt' and not str(args.source).startswith('\\\\?\\'):
        args.source = Path('\\\\?\\' + str(args.source.resolve()))
    if args.command == 'verify':
        verify()
    else:
        records = inventory(args.source)
        if args.command == 'build':
            build(args.source, records)
            verify()
