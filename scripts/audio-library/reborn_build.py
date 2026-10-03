"""Reborn-01 analysis, editing and verification. Always preview-only.

Never writes Music, assets/audio, Godot assets/data, or live sound mappings.
The renderer uses explicit trims from reborn_recipes, not filename selectors.
"""
import argparse
from collections import Counter, defaultdict
import json
import math
import os
from pathlib import Path
import re
import shutil
import numpy as np

from build import ROOT, RATE, header, decode, read_segment, resample, fade, filter_audio, normalize, write_wav, digest, dump

OUTPUT = ROOT / 'audio-library/reborn-01'
CEILING = 10 ** (-4.01 / 20)
POLICY = {
    'maxVoices': 16, 'normalVoices': 12, 'reservedImportantVoices': 4,
    'busyAttenuation': .12, 'musicFade': .35, 'pauseGain': .25,
    'chainHopMaxPerAttack': 2, 'noConsecutiveVariant': True,
    'protected': ['playerHit', 'eliteSpawned', 'bossSpawned', 'enemyCharge',
                  'enemyDetonate', 'bossAttack', 'stageClear', 'gameOver',
                  'supplyFanfare', 'waveCountdownTick'],
    'combatBgmGain': .12, 'ambienceFollows': 'musicVolume/mute; max one lobby loop',
    'hidden': 'stop playback', 'result': 'stop BGM; prioritize result cue',
    'status': 'proposed; offline listening comparisons only; NOT deployed',
}
NEW_IDS = {'shotgunAttack', 'bombardLaunch', 'chainHop', 'enemyProjectile',
           'enemyCharge', 'enemySupport', 'enemyDetonate', 'bossAttack'}
FALLBACK = {'shotgunAttack': 'weaponFired', 'bombardLaunch': 'bombardAttack', 'chainHop': 'chainAttack'}
CONNECTIONS = {
    'status': 'proposed; connects only after user listening approval',
    'compatibleApi': 'Sound.cue(id, context = {})',
    'existingGameEventIds': 'unchanged; additional audio-only payloads carry weapon/stage/behavior',
    'weaponStages': {
        'manaSword': {'attack': 'slashAttack'},
        'guardianDaggers': {'contact': 'orbitAttack'},
        'piercingShot': {'launch': 'piercingAttack'},
        'chainLightning': {'initial': 'chainAttack', 'hop': 'chainHop', 'maxHopsPerAttack': 2},
        'manaBombard': {'launch': 'bombardLaunch', 'impact': 'bombardAttack'},
        'manaBolt': {'launch': 'weaponFired'},
        'manaShotgun': {'launch': 'shotgunAttack'},
        'autoTurret': {'launch': 'turretFired'},
        'mineLayer': {'place': 'minePlaced', 'impact': 'mineExploded'},
        'manaField': {'activate': 'fieldActivated', 'sustainedDamage': None},
    },
    'enemyActions': {'projectileLaunch': 'enemyProjectile', 'chargeWindup': 'enemyCharge',
                     'supportOrSummonCast': 'enemySupport', 'selfDestructWarning': 'enemyDetonate',
                     'bossMajorAttack': 'bossAttack'},
    'excludedEvents': ['footsteps', 'movementLoops', 'continuousCries', 'dialogue'],
    'lobbyBackgrounds': {'rain': 'lobbyRain', 'wind': 'lobbyWind', 'gate': 'lobbyGate',
                         'winter': 'lobbyWinter', 'roof': 'lobbyRoof'},
}


def inspect_source(file, source):
    """Whole-file sample scan, 10ms energy, silence, quiet-floor and region map.

    Quiet-floor is a signal statistic, not a perceptual noise measurement.
    Multi-channel assets are inspected, but never guessed into stereo layers.
    """
    m = header(file)
    env, centroids = [], []
    peak = square = clipped = count = 0
    with file.open('rb') as stream:
        stream.seek(m['offset'])
        remaining = m['data_bytes']
        while remaining:
            raw = stream.read(min(remaining, m['sample_rate'] * m['align']))
            remaining -= len(raw)
            x = decode(raw, m)
            if not len(x): break
            peak = max(peak, float(np.max(np.abs(x))))
            square += float(np.sum(x.astype(np.float64) ** 2))
            count += x.size
            clipped += int(np.count_nonzero(np.abs(x) >= .9999))
            size = max(1, m['sample_rate'] // 100)
            power = np.mean(x ** 2, axis=1)
            n = len(power) // size
            env.extend(np.sqrt(power[:n * size].reshape(n, size).mean(axis=1)).tolist())
            if len(centroids) < 20:
                y = x[:min(8192, len(x))].mean(axis=1)
                spectrum = np.abs(np.fft.rfft(y * np.hanning(len(y))))
                frequency = np.fft.rfftfreq(len(y), 1 / m['sample_rate'])
                centroids.append(float(np.sum(spectrum * frequency) / max(np.sum(spectrum), 1e-12)))
    energy = np.asarray(env)
    threshold = max(float(energy.max(initial=0)) * .08, .0001)
    active = np.flatnonzero(energy > threshold)
    first = max(0, int(active[0]) - 2) if len(active) else 0
    last = min(len(energy), int(active[-1]) + 6) if len(active) else len(energy)
    onset_score = np.maximum(0, energy - np.r_[0, energy[:-1]]) * np.sqrt(np.maximum(energy, 0))
    events = [first]
    for i in np.argsort(onset_score)[::-1]:
        if len(events) >= 30 or onset_score[i] < onset_score.max(initial=0) * .08: break
        onset = max(0, int(i) - 2)
        if energy[i] > threshold and all(abs(onset - old) >= 18 for old in events): events.append(onset)
    # Merge short energy gaps, then split sustained recordings into <=20s regions.
    regions = []
    if len(active):
        starts = np.r_[0, np.flatnonzero(np.diff(active) > 25) + 1]
        ends = np.r_[starts[1:] - 1, len(active) - 1]
        for a, b in zip(starts, ends):
            begin = max(0, (int(active[a]) - 2) / 100)
            end = min(m['duration'], (int(active[b]) + 6) / 100)
            if end - begin < .03: continue
            for part in np.arange(begin, end, 20):
                regions.append({'start': round(float(part), 3), 'end': round(min(float(part) + 20, end), 3),
                                'reason': '파형 에너지 동작 구간' if end - begin < 20 else '긴 지속 녹음의 분할 구간'})
    rms = math.sqrt(square / max(count, 1))
    quiet = float(np.quantile(energy, .2)) if len(energy) else 0
    return {'path': file.relative_to(source).as_posix(), 'pack': file.parent.name,
            'sha256': digest(file), 'bytes': file.stat().st_size, **m,
            'peak': peak, 'peak_dbfs': round(20 * math.log10(max(peak, 1e-12)), 2),
            'rms': rms, 'rms_dbfs': round(20 * math.log10(max(rms, 1e-12)), 2),
            'clipped_samples': clipped,
            'spectral_centroid_hz': round(float(np.mean(centroids)), 1),
            'active_start': first / 100, 'active_end': min(m['duration'], last / 100),
            'events': sorted(i / 100 for i in events), 'segments': regions,
            'silence_ratio': round(float(np.mean(energy < .0003)), 4),
            'quiet_floor_dbfs': round(20 * math.log10(max(quiet, 1e-12)), 2),
            'noise_note': '조용한 20% 구간 RMS 기반 추정값. 실제 잡음의 청각적 식별은 미실시.',
            'mtime_ns': file.stat().st_mtime_ns, 'audition_state': 'not_auditioned',
            'review_method': 'whole-file sample/energy/metadata analysis; source semantics; no direct listening'}


def inventory(source):
    files = sorted(source.rglob('*.wav'))
    if len(files) != 346: raise ValueError(f'Expected 346 source WAVs, found {len(files)}')
    records = []
    for i, file in enumerate(files, 1):
        records.append(inspect_source(file, source))
        if i % 20 == 0 or i == len(files): print(f'Whole-source review {i}/{len(files)}', flush=True)
    licenses = []
    for i, folder in enumerate(sorted(source.glob('Sonniss.com-GDC2026-*')), 1):
        for file in folder.iterdir():
            if file.suffix.lower() not in {'.pdf', '.txt'}: continue
            dest = OUTPUT / 'provenance' / f'part-{i}' / file.name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(file, dest)
            licenses.append({'source': file.relative_to(source).as_posix(), 'sha256': digest(file),
                             'copy': dest.relative_to(OUTPUT).as_posix()})
    result = {'source_root': str(source), 'review': 'signal analysis completed; listening pending',
              'sources': records, 'licenses': licenses}
    dump(OUTPUT / 'inventory.json', result)
    return result


def source_preview(source, record, start, duration, stereo=False):
    key = digest_key(f'{record["sha256"]}:{start:.6f}:{duration:.6f}:{stereo}')
    file = OUTPUT / 'source-previews' / f'{key}.wav'
    preview_gain = None
    if not file.exists():
        x = resample(read_segment(source / record['path'], record, start, duration, stereo), record['sample_rate'])
        x, preview_gain = normalize(fade(x, .003, .03), .11, CEILING)
        write_wav(file, x)
    return file.relative_to(OUTPUT).as_posix(), preview_gain


def digest_key(text):
    import hashlib
    return hashlib.sha256(text.encode()).hexdigest()[:24]


def classify(record, uses):
    name = record['path'].lower()
    if uses:
        return 'candidate', '명시한 동작 구간을 새 효과음에 편집 사용. 최종 채택은 사용자 청취 대기.'
    if record['rms'] < .0001:
        return 'excluded', '파일 전체 에너지가 너무 작아 이번 묶음에서 제외.'
    if record['channels'] > 2:
        return 'hold', '다채널 공간 녹음. 방향/채널 해석 없이 모노·스테레오로 섞지 않고 보류.'
    if any(token in name for token in ['fight voices', 'detective', 'police officer', 'announcer', 'advertisements', 'police radio', 'walla']):
        return 'excluded', '대사·방송·군중 음성 계열. 이번 작업의 무대사·무이동음 범위에 맞지 않음.'
    if any(token in name for token in ['vocalisation', 'dinosaurs', 'humanoid creatures', 'death whistle', 'horror', 'haunting', 'sinister', 'ghostly']):
        return 'excluded', '울음·호러·지속 위협 질감 계열. 귀여운 SD 액션의 짧은 효과음 방향에서 제외.'
    if any(token in name for token in ['car interior', 'car foley', 'transportation', 'commute', 'crowds', 'grand central', 'public spaces', 'restaurants']):
        return 'hold', '현실 교통/생활 환경 녹음. 이번에는 이동음·상시 전투 환경층을 쓰지 않으므로 보류.'
    if any(token in name for token in ['bloopers', 'boing', 'squeak', 'comedy', 'cartoon & animation']):
        return 'hold', '코믹/장난감 질감 가능성이 있어 보류. 파형 분석만으로 귀여움과 유치함을 판단하지 않음.'
    details = f'{record["pack"]}, {record["duration"]:.2f}초, 동작 구간 {len(record["segments"])}개'
    return 'hold', f'{details}. 분석 가능한 재료지만 현재 cue의 명시한 구간에 채택하지 않은 대체 후보.'


def seamless(x, seconds, crossfade):
    """Remove seam by tail/head overlap; handles shorter stereo sources too."""
    cross = min(round(crossfade * RATE), max(2, len(x) // 4))
    ramp = np.linspace(0, 1, cross, dtype=np.float32)[:, None]
    length = round(seconds * RATE)
    while len(x) < length + cross:
        x = np.concatenate((x[:-cross], x[-cross:] * (1 - ramp) + x[:cross] * ramp, x[cross:]))
    x = x[:length + cross]
    return np.concatenate((x[-cross:] * (1 - ramp) + x[:cross] * ramp, x[cross:length]))


def render_variant(source, by_path, cue_id, cue, number, variant):
    channels = 2 if cue.get('loop') else 1
    arrays, layers = [], []
    duration = variant['duration']
    for spec in variant['layers']:
        rec = by_path[spec['source']]
        start, seconds = spec['start'], spec['duration']
        if start < 0 or seconds <= 0 or start + seconds > rec['duration'] + .001:
            raise ValueError(f'Invalid source range {cue_id}: {spec}')
        preview, preview_gain = source_preview(source, rec, start, seconds, channels == 2)
        x = read_segment(source / rec['path'], rec, start, seconds, channels == 2)
        x = resample(x, rec['sample_rate'], spec.get('speed', 1))
        dc = x.mean(axis=0)
        x -= dc
        low, high = spec.get('highpass_hz', 0), spec.get('lowpass_hz', RATE * .49)
        if low or high < RATE * .49: x = filter_audio(x, RATE, low, high)
        gate = spec.get('gate_db')
        if gate is not None:
            # Optional gentle expansion, per recipe; never universal noise gating.
            block = max(1, round(.008 * RATE))
            p = np.pad(np.mean(x ** 2, axis=1), (block // 2, block // 2))
            envelope = np.sqrt(np.convolve(p, np.ones(block) / block, mode='valid')[:len(x)])
            x *= np.minimum(1, envelope / 10 ** (gate / 20))[:, None]
        x, gain = normalize(x, spec.get('target_rms', .16), CEILING)
        x = fade(x, spec.get('fade_in', .002), spec.get('fade_out', .02))
        delay = round(spec.get('delay', 0) * RATE)
        x = np.pad(x * spec.get('gain', 1), ((delay, 0), (0, 0)))
        arrays.append(x)
        layers.append({**spec, 'sha256': rec['sha256'], 'preview': preview,
                       'preview_gain': preview_gain,
                       'preview_note': '원본 구간: 48kHz 변환·안전 음량·끝단 페이드만; EQ·레이어 없음',
                       'normalization_gain': gain, 'removed_dc': dc.tolist()})
    if cue.get('loop'):
        cross = cue.get('crossfade', cue.get('loop_crossfade', .5))
        mix = sum(seamless(x, duration, cross) for x in arrays)
    else:
        length = round(duration * RATE)
        mix = sum(np.pad(x[:length], ((0, max(0, length - len(x))), (0, 0))) for x in arrays)
        if variant.get('envelope') == 'decay':
            tau = variant.get('decay_seconds', max(.06, duration * .55))
            mix *= np.exp(-np.arange(length) / RATE / tau)[:, None]
        mix = fade(mix, variant.get('fade_in', .003), variant.get('fade_out', .04))
    mix, final_gain = normalize(mix, variant.get('target_rms', .11), CEILING)
    file = OUTPUT / 'sounds' / cue_id / f'{number:02d}.wav'
    write_wav(file, mix)
    return {'file': file.relative_to(OUTPUT).as_posix(), 'duration': len(mix) / RATE,
            'channels': channels, 'sample_rate': RATE, 'bits': 16, 'loop': bool(cue.get('loop')),
            'layers': layers, 'editing': {k: v for k, v in variant.items() if k != 'layers'},
            'notes': variant.get('note', ''), 'final_gain': final_gain,
            'sha256': digest(file), 'audition_state': 'not_auditioned'}


def load_wav(file, stereo=False):
    meta = header(file)
    return resample(read_segment(file, meta, 0, meta['duration'], stereo), meta['sample_rate'])


def matched_comparison(cue_id, new, current, number=1):
    # RMS matching is explicit, not a claim of equal perceived loudness.
    stereo = new.get('channels') == 2
    pairs = [('new', load_wav(OUTPUT / new['file'], stereo))]
    if current: pairs.append(('current', load_wav(OUTPUT / current[0]['file'], stereo)))
    rms = [float(np.sqrt(np.mean(x ** 2))) for _, x in pairs]
    target = min(.11, *(r for r in rms if r > 1e-8))
    scale = min(1, *(CEILING / max(float(np.max(np.abs(x))) * target / max(r, 1e-8), 1e-8)
                     for (_, x), r in zip(pairs, rms)))
    result = {'method': 'whole-clip RMS matched; perceived loudness may differ', 'target_rms': target * scale}
    for (name, x), r in zip(pairs, rms):
        suffix = '' if number == 1 else f'-{number:02d}'
        file = OUTPUT / 'comparisons' / f'{cue_id}{suffix}-{name}.wav'
        write_wav(file, x * target / max(r, 1e-8) * scale)
        result[name] = file.relative_to(OUTPUT).as_posix()
    return result


def live_snapshot():
    files = [ROOT / 'src/data/audio.ts', ROOT / 'src/data/sourcedAudio.ts', ROOT / 'godot/data/content.json',
             ROOT / 'godot/scripts/presentation/sound.gd']
    files += sorted((ROOT / 'assets/audio').rglob('*.wav'))
    files += sorted((ROOT / 'assets/audio').rglob('*.mp3'))
    files += sorted((ROOT / 'godot/assets/audio').rglob('*.wav'))
    files += sorted((ROOT / 'godot/assets/audio').rglob('*.mp3'))
    return {file.relative_to(ROOT).as_posix(): digest(file) for file in files if file.is_file()}


def build(source):
    from reborn_recipes import REBORN_CUES
    before = live_snapshot()
    inventory_path = OUTPUT / 'inventory.json'
    data = json.loads(inventory_path.read_text(encoding='utf-8')) if inventory_path.exists() else inventory(source)
    records = data['sources']
    by_path = {rec['path']: rec for rec in records}
    for rec in records:
        file = source / rec['path']
        if file.stat().st_size != rec['bytes'] or file.stat().st_mtime_ns != rec['mtime_ns']:
            raise ValueError(f'Source changed after analysis: {file}')
    content = json.loads((ROOT / 'godot/data/content.json').read_text(encoding='utf-8'))
    if set(REBORN_CUES) != set(content['sfx']) | NEW_IDS | {'lobbyRain', 'lobbyWind', 'lobbyGate', 'lobbyWinter', 'lobbyRoof'}:
        raise ValueError('Cue set does not match live31 + new8 + ambience5')
    cue_records, used = {}, defaultdict(list)
    for cue_id, cue in REBORN_CUES.items():
        variants = [render_variant(source, by_path, cue_id, cue, i, v) for i, v in enumerate(cue['variants'], 1)]
        for i, v in enumerate(variants, 1):
            for layer in v['layers']: used[layer['source']].append(f'{cue["label"]} · 변형 {i}')
        previous = content['sfx'].get(cue_id, content['sfx'].get(FALLBACK.get(cue_id, ''), {}))
        current = [{'file': Path(os.path.relpath(ROOT / 'godot' / url.removeprefix('res://'), OUTPUT)).as_posix()}
                   for url in previous.get('urls', [])]
        comparison_variants = [matched_comparison(cue_id, v, current, i) for i, v in enumerate(variants, 1)]
        cue_records[cue_id] = {**{k: v for k, v in cue.items() if k != 'variants'}, 'id': cue_id,
                               'variants': variants, 'current': current, 'notes': cue.get('note', ''), 'events': [cue_id],
                               'currentRole': FALLBACK.get(cue_id, cue_id) if current else None,
                               'comparisons': {**comparison_variants[0], 'variants': comparison_variants}}
        print(f'Rendered {cue_id}: {len(variants)} explicit variants', flush=True)
    # Every original, including rejected files, gets an analysis reason and a small raw preview.
    for i, rec in enumerate(records, 1):
        rec['uses'] = list(dict.fromkeys(used.get(rec['path'], [])))
        rec['status'], rec['reason'] = classify(rec, rec['uses'])
        chosen = rec['events'] if rec['duration'] > 12 else [rec['active_start']]
        indices = sorted(set([0, len(chosen) // 2, max(0, len(chosen) - 1)])) if rec['duration'] > 12 else [0]
        rec['audition_segments'] = []
        if rec['rms'] >= .0001:
            for j in indices:
                start = min(chosen[j], max(0, rec['duration'] - .05))
                duration = min(3, rec['duration'] - start)
                preview, _ = source_preview(source, rec, start, duration, rec['channels'] == 2)
                rec['audition_segments'].append({'start': start, 'duration': duration, 'preview': preview,
                                                'reason': '원본 동작 구간 청취용. 긴 녹음 전체를 대표한다고 가정하지 않음.'})
        if i % 50 == 0: print(f'Source preview/reason {i}/{len(records)}', flush=True)
    dump(inventory_path, data)
    summary = {'originals': len(records), 'original_bytes': sum(r['bytes'] for r in records),
               'original_duration_seconds': sum(r['duration'] for r in records), 'legacy_edits': 450,
               'existing_events': len(content['sfx']), 'new_events': 8, 'lobby_loops': 5,
               'cues': len(cue_records), 'edited_files': sum(len(c['variants']) for c in cue_records.values()),
               'used_sources': len(used), 'statuses': dict(Counter(r['status'] for r in records)),
               'direct_listening': 'NOT PERFORMED; user listening determines adoption', 'runtime': 'UNCHANGED'}
    manifest = {'version': 1, 'mode': 'preview-only', 'sample_rate': RATE, 'peak_ceiling_dbfs': -4,
                'builder_sha256': digest(Path(__file__)), 'recipes_sha256': digest(Path(__file__).with_name('reborn_recipes.py')),
                'numpy_version': np.__version__, 'summary': summary, 'policy': POLICY,
                'cues': cue_records, 'connections': CONNECTIONS, 'source_inventory': 'inventory.json', 'live_before': before}
    dump(OUTPUT / 'manifest.json', manifest)
    mixes()


def mixes():
    """Re-render policies/scenes without processing identical source trims again."""
    manifest = json.loads((OUTPUT / 'manifest.json').read_text(encoding='utf-8'))
    if manifest['live_before'] != live_snapshot(): raise ValueError('Live sound files changed since preview build')
    from reborn_mix import build_mixes
    manifest['mixes'] = build_mixes(OUTPUT, manifest)
    manifest['mixer_sha256'] = digest(Path(__file__).with_name('reborn_mix.py'))
    manifest['mp3_decoder'] = 'miniaudio 1.71; provided BGM short decode cache only'
    manifest['live_after'] = live_snapshot()
    if manifest['live_after'] != manifest['live_before']: raise ValueError('Live sound files/mappings changed during preview build')
    dump(OUTPUT / 'manifest.json', manifest)
    verify()


def export_catalog(manifest, records):
    # The source tab puts raw audition excerpts first, retaining all full-file regions in analysis.
    sources = [{**r, 'analysis': {'segments': r['segments']}, 'segments': r.get('audition_segments', [])} for r in records]
    catalog = {'summary': manifest['summary'], 'cues': list(manifest['cues'].values()),
               'sources': sources, 'mixes': manifest.get('mixes', []), 'policy': manifest['policy'],
               'notes': '직접 청취 미실시. 원본 전수 신호 분석·편집을 완료하고, 전체 후보의 사용자 청취와 컨펌을 기다립니다.'}
    (OUTPUT / 'catalog-data.js').write_text('window.REBORN_CATALOG = ' + json.dumps(catalog, ensure_ascii=False) + ';\n', encoding='utf-8')


def verify():
    manifest = json.loads((OUTPUT / 'manifest.json').read_text(encoding='utf-8'))
    inventory_data = json.loads((OUTPUT / 'inventory.json').read_text(encoding='utf-8'))
    problems, checks = [], []
    hashes = set()
    for cue_id, cue in manifest['cues'].items():
        textures = set()
        for entry in cue['variants']:
            file = OUTPUT / entry['file']
            meta = header(file); x = load_wav(file, entry['channels'] == 2)
            peak = float(np.max(np.abs(x))); rms = float(np.sqrt(np.mean(x ** 2)))
            errors = []
            if (meta['sample_rate'], meta['bits'], meta['channels']) != (48000, 16, entry['channels']): errors.append('format')
            if peak > 10 ** (-4 / 20) + 1 / 32768 or rms < .0001: errors.append('level_or_silence')
            edge = float(np.max(np.abs(x[-1] - x[0])))
            if cue.get('loop'):
                if edge > max(.015, float(np.quantile(np.abs(np.diff(x, axis=0)), .999)) * 2): errors.append('loop_seam')
            elif max(float(np.max(np.abs(x[0]))), float(np.max(np.abs(x[-1])))) > .0001: errors.append('end_click_boundary')
            texture = tuple((l['source'], l['start'], l['duration']) for l in entry['layers'])
            if texture in textures: errors.append('pitch_only_variant')
            textures.add(texture)
            sha = digest(file)
            if sha != entry['sha256'] or sha in hashes: errors.append('duplicate_or_hash')
            hashes.add(sha)
            for layer in entry['layers']:
                if not (OUTPUT / layer['preview']).exists(): errors.append('missing_source_preview')
            entry['measurements'] = {'peak_dbfs': round(20 * math.log10(max(peak, 1e-12)), 2),
                                     'rms_dbfs': round(20 * math.log10(max(rms, 1e-12)), 2), 'edge_step': edge}
            checks.append({'cue': cue_id, 'file': entry['file'], **entry['measurements'], 'errors': errors})
            if errors: problems.append(checks[-1])
    for mix in manifest.get('mixes', []):
        for name in ['current', 'new']:
            file = OUTPUT / mix[name]
            x = load_wav(file, True)
            if np.max(np.abs(x)) > 10 ** (-4 / 20) + 1 / 32768: problems.append({'mix': mix['id'], 'issue': 'ceiling'})
        policy = mix['policyReport']['new']
        if policy['concurrentMax'] > 16 or policy['normalConcurrentMax'] > 12:
            problems.append({'mix': mix['id'], 'issue': 'voice_limit'})
        last_variant, chains = {}, Counter()
        for event in policy['accepted']:
            cue_id = event['cue']
            if event['protected'] and event['busyAttenuation'] != 1:
                problems.append({'mix': mix['id'], 'issue': 'protected_attenuated', 'cue': cue_id})
            if len(manifest['cues'][cue_id]['variants']) > 1 and last_variant.get(cue_id) == event['variant']:
                problems.append({'mix': mix['id'], 'issue': 'consecutive_variant', 'cue': cue_id})
            last_variant[cue_id] = event['variant']
            if cue_id == 'chainHop': chains[event.get('attackId')] += 1
        if any(count > 2 for count in chains.values()): problems.append({'mix': mix['id'], 'issue': 'chain_hops'})
    records = inventory_data['sources']
    if len(records) != 346 or any(not r.get('status') or not r.get('reason') for r in records): problems.append({'sources': 'incomplete review'})
    if manifest['live_before'] != live_snapshot(): problems.append({'runtime': 'changed since preview started'})
    # Also check the generated comparisons/raw excerpts, not only candidate outputs.
    auxiliary = []
    for folder in ['source-previews', 'comparisons']:
        for file in sorted((OUTPUT / folder).glob('*.wav')):
            meta = header(file)
            x = load_wav(file, meta['channels'] == 2)
            peak, rms = float(np.max(np.abs(x))), float(np.sqrt(np.mean(x ** 2)))
            issues = []
            if meta['sample_rate'] != 48000 or meta['bits'] != 16 or meta['channels'] not in [1, 2]: issues.append('format')
            if peak > 10 ** (-4 / 20) + 1 / 32768 or rms < .0001: issues.append('level_or_silence')
            auxiliary.append({'file': file.relative_to(OUTPUT).as_posix(), 'peak_dbfs': round(20 * math.log10(max(peak, 1e-12)), 2), 'errors': issues})
            if issues: problems.append(auxiliary[-1])
    report = {'summary': manifest['summary'], 'problems': problems, 'measurements': checks,
              'auxiliary_measurements': auxiliary,
              'scope': 'sample format/peak/silence/edge/loop seam/provenance/mapping/audio preview only',
              'auditory_review': 'NOT PERFORMED: no audio perception tool; user approval pending',
              'gameplay_device_full_tests': 'NOT PERFORMED', 'live_files_unchanged': manifest['live_before'] == live_snapshot()}
    dump(OUTPUT / 'verification.json', report)
    dump(OUTPUT / 'manifest.json', manifest)
    export_catalog(manifest, records)
    print(json.dumps({k: v for k, v in report.items() if k not in {'measurements', 'auxiliary_measurements'}}, ensure_ascii=True), flush=True)
    if problems: raise ValueError(f'{len(problems)} preview verification problems')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['inventory', 'build', 'mixes', 'verify'])
    parser.add_argument('--preview-only', action='store_true', required=True,
                        help='Required guard: this command cannot deploy live sounds')
    parser.add_argument('--source', type=Path, default=Path.home() / 'Music')
    args = parser.parse_args()
    source = args.source.resolve()
    if os.name == 'nt' and not str(source).startswith('\\\\?\\'): source = Path('\\\\?\\' + str(source))
    if args.command == 'inventory': inventory(source)
    elif args.command == 'build': build(source)
    elif args.command == 'mixes': mixes()
    else: verify()
