"""Deterministic, preview-only comparisons of current and proposed sound mixes.

No audio is installed in the game. These are scripted timelines, not gameplay
recordings or a listening review. All files stay under the supplied output.
"""
from __future__ import annotations

from dataclasses import dataclass, field
import json
import math
from pathlib import Path
import sys

import numpy as np

from build import RATE, ROOT, fade, header, read_segment, resample, write_wav

FALLBACKS = {
    'chainHop': 'chainAttack', 'bombardLaunch': 'bombardAttack',
    'shotgunAttack': 'weaponFired',
}
NEW_ONLY = {'enemyProjectile', 'enemyCharge', 'enemySupport', 'enemyDetonate', 'bossAttack'}
CEILING = 10 ** (-4 / 20)


def _value(policy: dict, names: tuple[str, ...], default):
    for name in names:
        if name in policy:
            return policy[name]
    return default


def _db(peak: float) -> float:
    return round(20 * math.log10(max(peak, 1e-6)), 3)


def _asset_path(url: str) -> Path:
    if not url.startswith('res://'):
        raise ValueError(f'Expected a Godot asset URL, got {url}')
    return ROOT / 'godot' / url[6:]


class AudioFiles:
    """Read only the short excerpts needed by these comparisons."""
    def __init__(self, output: Path):
        self.output = output
        self.cache: dict[str, np.ndarray] = {}

    def read(self, path: Path, duration: float | None = None) -> np.ndarray:
        key = f'{path.resolve()}:{duration}'
        if key in self.cache:
            return self.cache[key]
        if path.suffix.lower() == '.wav':
            meta = header(path)
            audio = read_segment(path, meta, 0, min(meta['duration'], duration) if duration else meta['duration'], stereo=True)
            audio = resample(audio, meta['sample_rate'])
        else:
            cached_excerpt = self.output / 'decoded-bgm' / f'{path.stem}.npy'
            if cached_excerpt.exists():
                audio = np.load(cached_excerpt, allow_pickle=False).astype(np.float32)
                if audio.ndim != 2 or audio.shape[1] != 2:
                    raise ValueError(f'Expected 48kHz stereo BGM excerpt: {cached_excerpt}')
                if duration and len(audio) < round(duration * RATE):
                    raise ValueError(f'BGM excerpt is too short for this scene: {cached_excerpt}')
            else:
                for directory in [ROOT / 'audio-library/reborn-01/.tools', self.output / '.tools']:
                    tools = str(directory)
                    if tools not in sys.path:
                        sys.path.insert(0, tools)
                import miniaudio
                decoded = miniaudio.decode_file(str(path), output_format=miniaudio.SampleFormat.FLOAT32, nchannels=2, sample_rate=RATE)
                audio = np.asarray(decoded.samples, dtype=np.float32).reshape(-1, 2)
            if duration:
                audio = audio[:round(duration * RATE)].copy()
        if not len(audio) or not np.isfinite(audio).all():
            raise ValueError(f'Empty or invalid audio: {path}')
        self.cache[key] = audio
        return audio


def _event(at: float, cue: str, attack: str | None = None, **context) -> dict:
    value = {'time': round(float(at), 4), 'cue': cue}
    if attack:
        value['attackId'] = attack
    if context:
        value['context'] = context
    return value


def _chain(events: list, at: float, attack: str, third_probe=False):
    events.append(_event(at, 'chainAttack', attack))
    for hop in range(1, 4 if third_probe else 3):
        events.append(_event(at + hop * .09, 'chainHop', attack, hop=hop))


def _scenarios() -> list[dict]:
    low = [_event(.25, 'waveStarted')]
    for index in range(12):
        at = .95 + index * 1.18
        low.extend([_event(at, 'weaponFired', f'low-{index}'), _event(at + .16, 'enemyHit'),
                    _event(at + .31, 'magicStoneCollected')])
        if index % 3 == 1:
            low.append(_event(at + .23, 'enemyKilled'))
    low.extend([_event(3.1, 'slashAttack'), _event(5.4, 'orbitAttack'), _event(7.1, 'minePlaced'),
                _event(8.0, 'fieldActivated'), _event(9.2, 'mineExploded'), _event(10.9, 'turretFired'),
                _event(14.7, 'walletSweep')])
    _chain(low, 12.8, 'low-chain')

    dense = [_event(.20, 'waveStarted')]
    patterns = [('weaponFired', .31, .8), ('slashAttack', .83, .9), ('piercingAttack', .77, 1.0),
                ('shotgunAttack', 1.12, 1.1), ('bombardLaunch', 1.39, 1.2), ('chainAttack', 1.06, 1.25)]
    for cue, interval, start in patterns:
        for index, at in enumerate(np.arange(start, 17.7, interval)):
            attack = f'{cue}-{index}'
            if cue == 'chainAttack':
                _chain(dense, float(at), attack, index == 4)
            else:
                dense.append(_event(float(at), cue, attack))
            dense.append(_event(float(at) + .135, 'enemyHit'))
            if cue == 'bombardLaunch':
                dense.append(_event(float(at) + .46, 'bombardAttack', attack))
            if index % 3 == 0:
                dense.extend([_event(float(at) + .21, 'enemyKilled'), _event(float(at) + .29, 'magicStoneCollected')])
            if index % 5 == 0:
                dense.append(_event(float(at) + .16, 'critical'))

    warnings = list(dense[:1])
    for index, at in enumerate(np.arange(.8, 15.0, .20)):
        warnings.extend([_event(float(at), 'weaponFired'), _event(float(at) + .065, 'enemyHit'),
                         _event(float(at) + .10, 'enemyKilled')])
        if index % 4 == 0:
            warnings.append(_event(float(at), 'slashAttack'))
        if index % 9 == 0:
            _chain(warnings, float(at), f'warning-chain-{index}')
    warnings.extend([_event(3.0, 'enemyProjectile'), _event(4.5, 'enemyCharge'),
                     _event(5.8, 'enemySupport'), _event(6.8, 'enemyDetonate'),
                     _event(7.8, 'eliteSpawned'), _event(9.2, 'bossSpawned'),
                     _event(9.45, 'bossAttack'), _event(9.6, 'playerHit'),
                     _event(10.1, 'playerHit'), _event(11.0, 'bossAttack')])
    warnings.extend(_event(12.5 + index, 'waveCountdownTick') for index in range(4))

    shop = [_event(.6, 'buttonClick'), _event(1.1, 'purchase'), _event(2.5, 'lock'),
            _event(3.6, 'reroll'), _event(4.9, 'buttonClick'), _event(5.3, 'weaponPurchase'),
            _event(7.2, 'branchChoice'), _event(9.2, 'reroll'), _event(10.7, 'purchase'),
            _event(12.4, 'lock'), _event(14.0, 'weaponPurchase'), _event(16.2, 'waveStarted')]
    rewards = [_event(.7, 'buttonClick'), _event(1.4, 'supplyLatch'), _event(2.6, 'supplyFanfare'),
               _event(5.0, 'walletSweep'), _event(6.0, 'waveCompleted'), _event(8.0, 'stageClear')]
    scenes = [
        {'id': 'low-combat', 'label': '저밀도 전투 · 발사와 적중', 'duration': 18, 'music': 'combat', 'track': 0, 'events': low},
        {'id': 'six-weapons', 'label': '무기 6종 · 혼잡한 전투', 'duration': 20, 'music': 'combat', 'track': 1, 'events': dense},
        {'id': 'hit-warning', 'label': '피격·위험 경고 · 전투 속 중요한 소리', 'duration': 18, 'music': 'combat', 'track': 1, 'events': warnings},
        {'id': 'gate24', 'label': '게이트24 · 구매와 재진열', 'duration': 18, 'music': 'menu', 'track': 0, 'events': shop},
        {'id': 'reward-result', 'label': '보급·보상·작전 결과', 'duration': 18, 'music': 'guild', 'track': 0, 'events': rewards, 'states': [{'time': 8.0, 'state': 'result'}]},
    ]
    environments = [('rain', '비'), ('wind', '바람'), ('gate', '마력 게이트'), ('winter', '겨울 검문소'), ('roof', '옥상')]
    for index, (token, label) in enumerate(environments):
        scenes.append({'id': f'lobby-{token}', 'label': f'로비 · {label}', 'duration': 16,
                       'music': 'menu', 'track': index % 3, 'ambience': token,
                       'events': [_event(1.2, 'buttonClick'), _event(9.8, 'buttonClick')]})
    scenes.append({'id': 'pause-hidden', 'label': '일시정지와 앱 숨김 · 음악 전환', 'duration': 18,
                   'music': 'combat', 'track': 0,
                   'events': [_event(.7, 'waveStarted'), _event(2.0, 'weaponFired'), _event(6.05, 'buttonClick'),
                              _event(9.05, 'buttonClick'), _event(10, 'weaponFired'), _event(12.1, 'enemyHit'),
                              _event(15, 'weaponFired')],
                   'states': [{'time': 6, 'state': 'pause'}, {'time': 9, 'state': 'resume'},
                              {'time': 12, 'state': 'hidden'}, {'time': 14, 'state': 'visible'}]})
    for scene in scenes:
        scene['events'].sort(key=lambda event: event['time'])
    return scenes


@dataclass
class Voice:
    cue: str
    requested: str
    start: float
    end: float
    samples: np.ndarray
    gain: float
    priority: int
    protected: bool
    entry: dict = field(default_factory=dict)


def _state_at(scene: dict, time: float) -> str:
    state = 'active'
    for change in scene.get('states', []):
        if change['time'] > time:
            break
        state = change['state']
    return state


def _definition(manifest: dict, content: dict, cue: str, proposed: bool) -> tuple[str, dict]:
    if proposed:
        return cue, manifest['cues'].get(cue, {})
    if cue in NEW_ONLY or cue == 'chainHop':
        return cue, {}
    resolved = FALLBACKS.get(cue, cue)
    return resolved, content['sfx'].get(resolved, {})


def _render_voices(scene: dict, output: Path, manifest: dict, content: dict, audio: AudioFiles, proposed: bool) -> tuple[np.ndarray, dict]:
    policy = manifest.get('policy', {})
    cap = int(_value(policy, ('maxVoices', 'max_voices', 'voices'), 16)) if proposed else 16
    normal_cap = int(_value(policy, ('normalVoices', 'normal_voices', 'normalVoiceLimit'), 12))
    busy_coefficient = float(_value(policy, ('busyAttenuation', 'busy_attenuation', 'busy_coefficient'), .12))
    chain_cap = int(_value(policy, ('chainHopMaxPerAttack', 'chain_hop_max_per_attack'), 2))
    seed = sum(ord(char) for char in scene['id']) + 20261003
    rng = np.random.default_rng(seed)
    last, last_variant, chains = {}, {}, {}
    voices: list[Voice] = []
    report = {'accepted': [], 'rejected': [], 'preempt': [], 'protected': [],
              'concurrentMax': 0, 'normalConcurrentMax': 0, 'voiceLimit': cap,
              'normalLimit': normal_cap if proposed else cap,
              'selection': 'nonconsecutive_variants' if proposed else 'legacy_random',
              'referenceBuses': 'unity gain; compare cue and music gains without changing saved settings',
              'notReproduced': ['Godot Master compressor (-5 dB threshold, 4:1 ratio)', 'output device response', 'saved user bus volumes']}
    for event in scene['events']:
        at = float(event['time'])
        requested = event['cue']
        resolved, definition = _definition(manifest, content, requested, proposed)
        rejection = {'time': at, 'cue': requested, 'resolvedCue': resolved}
        state = _state_at(scene, at)
        if proposed and state == 'hidden':
            report['rejected'].append({**rejection, 'reason': 'app_hidden'})
            continue
        if not definition:
            reason = 'missing_proposed_cue' if proposed else 'no_current_chain_hop' if requested == 'chainHop' else 'no_current_sound'
            report['rejected'].append({**rejection, 'reason': reason})
            continue
        if proposed and state == 'pause' and definition.get('category') == 'combat':
            report['rejected'].append({**rejection, 'reason': 'combat_paused'})
            continue
        if at - last.get(resolved, -999) < float(definition.get('interval', 0)):
            report['rejected'].append({**rejection, 'reason': 'minimum_interval'})
            continue
        active = [voice for voice in voices if voice.end > at and voice.start <= at]
        if sum(voice.cue == resolved for voice in active) >= int(definition.get('concurrency', 1)):
            report['rejected'].append({**rejection, 'reason': 'cue_concurrency'})
            continue
        attack = event.get('attackId')
        if proposed and requested == 'chainHop' and attack and chains.get(attack, 0) >= chain_cap:
            report['rejected'].append({**rejection, 'reason': 'chain_hop_attack_limit', 'attackId': attack})
            continue
        protected = bool(definition.get('protected', False)) if proposed else False
        priority = int(definition.get('priority', 1))
        normal = [voice for voice in active if not voice.protected]
        constrained_normal = proposed and not protected and len(normal) >= normal_cap
        if len(active) >= cap or constrained_normal:
            candidates = [voice for voice in (normal if constrained_normal else active)
                          if voice.priority < priority and (not proposed or not voice.protected)]
            if not candidates:
                report['rejected'].append({**rejection, 'reason': 'normal_reserved_limit' if constrained_normal else 'total_voice_limit'})
                continue
            victim = min(candidates, key=(lambda voice: (voice.priority, voice.start)) if proposed else (lambda voice: voice.start))
            victim.end = at
            victim.entry['preemptedAt'] = at
            report['preempt'].append({'time': at, 'stopped': victim.cue, 'for': requested, 'stoppedPriority': victim.priority, 'incomingPriority': priority})
            active = [voice for voice in active if voice is not victim]
        variants = definition.get('variants', []) if proposed else definition.get('urls', [])
        if not variants:
            report['rejected'].append({**rejection, 'reason': 'empty_variants'})
            continue
        possible = list(range(len(variants)))
        if proposed and len(possible) > 1 and resolved in last_variant:
            possible.remove(last_variant[resolved])
        index = int(rng.choice(possible))
        path = output / variants[index]['file'] if proposed else _asset_path(variants[index])
        samples = audio.read(path)
        pitch = definition.get('pitch', [1, 1])
        speed = float(rng.uniform(float(pitch[0]), float(pitch[1])))
        if abs(speed - 1) > 1e-7:
            samples = resample(samples, RATE, speed)
        variation = float(definition.get('volumeVariation', 0))
        gain = float(definition.get('gain', .25)) * float(rng.uniform(1 - variation, 1))
        busy = len(active)
        attenuation = 1.0 if protected else 1 / math.sqrt(1 + busy * (busy_coefficient if proposed else .12))
        gain *= attenuation
        entry = {'time': at, 'cue': requested, 'resolvedCue': resolved, 'variant': index + 1,
                 'file': path.relative_to(ROOT).as_posix() if path.is_relative_to(ROOT) else str(path),
                 'gain': round(gain, 6), 'pitch': round(speed, 5), 'busyBefore': busy,
                 'busyAttenuation': round(attenuation, 6), 'protected': protected}
        if attack:
            entry['attackId'] = attack
        voices.append(Voice(resolved, requested, at, at + len(samples) / RATE, samples, gain, priority, protected, entry))
        report['accepted'].append(entry)
        if protected:
            report['protected'].append({'time': at, 'cue': requested, 'busyBefore': busy, 'attenuation': 1.0})
        last[resolved], last_variant[resolved] = at, index
        if proposed and requested == 'chainHop' and attack:
            chains[attack] = chains.get(attack, 0) + 1
        active.append(voices[-1])
        report['concurrentMax'] = max(report['concurrentMax'], len(active))
        report['normalConcurrentMax'] = max(report['normalConcurrentMax'], sum(not voice.protected for voice in active))
    mixed = np.zeros((round(scene['duration'] * RATE), 2), np.float32)
    for voice in voices:
        start = round(voice.start * RATE)
        count = min(len(voice.samples), round((voice.end - voice.start) * RATE), len(mixed) - start)
        if count <= 0:
            continue
        samples = voice.samples[:count]
        if voice.entry.get('preemptedAt') is not None:
            samples = fade(samples, attack=0, release=.006)
        mixed[start:start + count] += samples * voice.gain
    if proposed:
        for index, change in enumerate(scene.get('states', [])):
            if change['state'] != 'hidden':
                continue
            start = round(change['time'] * RATE)
            later = scene.get('states', [])[index + 1:]
            visible = next((item['time'] for item in later if item['state'] == 'visible'), scene['duration'])
            end = min(len(mixed), round(visible * RATE))
            edge = min(start, round(.006 * RATE))
            if edge:
                mixed[start - edge:start] *= np.linspace(1, 0, edge, dtype=np.float32)[:, None]
            mixed[start:end] = 0
            report.setdefault('appHiddenStops', []).append({'time': change['time'], 'until': visible})
    report['peakDbfs'] = _db(float(np.max(np.abs(mixed))))
    return mixed, report


def _ramp(envelope: np.ndarray, at: float, target: float, duration: float):
    first = max(0, min(len(envelope) - 1, round(at * RATE)))
    end = min(len(envelope), first + round(duration * RATE))
    initial = float(envelope[first - 1]) if first else 0.0
    if end > first:
        envelope[first:end] = np.linspace(initial, target, end - first, dtype=np.float32)
    envelope[end:] = target


def _music(scene: dict, content: dict, manifest: dict, audio: AudioFiles, proposed: bool) -> tuple[np.ndarray, dict]:
    length = round(scene['duration'] * RATE)
    policy = manifest.get('policy', {})
    fade_time = float(_value(policy, ('musicFade', 'music_fade', 'musicFadeSeconds'), .35))
    pause_gain = float(_value(policy, ('pauseGain', 'pause_gain'), .25))
    group = content['bgm'][scene['music']]
    track = group['tracks'][scene.get('track', 0) % len(group['tracks'])]
    base = audio.read(_asset_path(track['url']), scene['duration'])
    mixed = np.zeros((length, 2), np.float32)
    take = min(length, len(base))
    mixed[:take] = base[:take] * float(group.get('gain', .5))
    envelope = np.ones(length, np.float32)
    changes = []
    if proposed:
        _ramp(envelope, 0, 1, fade_time)
    for change in scene.get('states', []):
        at, state = float(change['time']), change['state']
        if proposed:
            target = pause_gain if state == 'pause' else 0.0 if state in ('hidden', 'result') else 1.0
            # Hiding stops immediately; audible fades must not continue in the background.
            _ramp(envelope, at, target, 0 if state == 'hidden' else fade_time)
            if state == 'hidden':
                first = round(at * RATE)
                edge = min(first, round(.006 * RATE))
                if edge:
                    envelope[first - edge:first] *= np.linspace(1, 0, edge, dtype=np.float32)
        elif state == 'result':
            first = round(at * RATE)
            menu = content['bgm']['menu']
            menu_track = menu['tracks'][0]
            data = audio.read(_asset_path(menu_track['url']), scene['duration'] - at)
            mixed[first:] = 0
            count = min(len(data), len(mixed) - first)
            mixed[first:first + count] = data[:count] * float(menu.get('gain', .65))
        changes.append({'time': at, 'state': state, 'behavior': 'proposed_fade_or_stop' if proposed else 'legacy_menu_on_result_otherwise_unchanged'})
    mixed *= envelope[:, None]
    return mixed, {'track': track['url'], 'mode': scene['music'], 'gain': group.get('gain'),
                   'fadeSeconds': fade_time if proposed else 0, 'pauseMultiplier': pause_gain if proposed else 1,
                   'changes': changes, 'result': 'music_stop' if proposed else 'menu_music'}


def _ambience(scene: dict, output: Path, manifest: dict, audio: AudioFiles) -> tuple[np.ndarray, dict | None]:
    result = np.zeros((round(scene['duration'] * RATE), 2), np.float32)
    token = scene.get('ambience')
    if not token:
        return result, None
    candidates = [(cue_id, cue) for cue_id, cue in manifest['cues'].items()
                  if (cue.get('loop') or cue.get('category') == 'ambience') and token in cue_id.lower()]
    if not candidates:
        return result, {'missing': token, 'activeLoops': 0}
    cue_id, cue = candidates[0]
    variant = cue['variants'][0]
    samples = audio.read(output / variant['file'])
    repeats = math.ceil(len(result) / len(samples))
    result[:] = np.tile(samples, (repeats, 1))[:len(result)] * float(cue.get('gain', .10))
    result = fade(result, attack=.35, release=.35)
    return result, {'cue': cue_id, 'file': variant['file'], 'gain': cue.get('gain'),
                    'activeLoops': 1, 'settings': 'music volume and mute; no new saved setting'}


def build_mixes(output: Path, manifest: dict) -> list[dict]:
    """Render paired WAVs and return catalog-ready records; never alter runtime."""
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    content = json.loads((ROOT / 'godot/data/content.json').read_text(encoding='utf-8'))
    if not isinstance(manifest.get('cues'), dict):
        raise ValueError('manifest.cues must be a dictionary keyed by cue ID')
    audio = AudioFiles(output)
    records = []
    for scene in _scenarios():
        old, old_report = _render_voices(scene, output, manifest, content, audio, False)
        new, new_report = _render_voices(scene, output, manifest, content, audio, True)
        old_music, old_music_report = _music(scene, content, manifest, audio, False)
        new_music, new_music_report = _music(scene, content, manifest, audio, True)
        ambience, ambience_report = _ambience(scene, output, manifest, audio)
        old += old_music
        new += new_music + ambience
        # Output edge treatment is not loudness matching. Each pair shares one
        # safety attenuation so its relative mix and protected gains survive.
        old, new = fade(old, attack=.003, release=.025), fade(new, attack=.003, release=.025)
        old_peak, new_peak = float(np.max(np.abs(old))), float(np.max(np.abs(new)))
        gain = min(1.0, (CEILING - .00004) / max(old_peak, new_peak, 1e-9))
        old *= gain; new *= gain
        current_file = f'mixes/{scene["id"]}-current.wav'
        new_file = f'mixes/{scene["id"]}-new.wav'
        write_wav(output / current_file, old)
        write_wav(output / new_file, new)
        report = {
            'current': {**old_report, 'music': old_music_report, 'ambience': {'activeLoops': 0}},
            'new': {**new_report, 'music': new_music_report, 'ambience': ambience_report},
            'pairedSafety': {'ceilingDbfs': -4, 'sharedGain': round(gain, 8),
                             'currentBeforeDbfs': _db(old_peak), 'newBeforeDbfs': _db(new_peak),
                             'currentAfterDbfs': _db(old_peak * gain), 'newAfterDbfs': _db(new_peak * gain)},
            'auditionState': 'not_auditioned',
        }
        notes = '실제 예정 cue·BGM gain과 동시 재생 정책으로 만든 편집 믹스입니다. 실제 게임 녹음과 직접 청취 평가는 아닙니다. 두 버전에는 동일한 안전 감쇄만 적용했습니다. 사용자 버스는 공통 기준 gain 1이며 Master 압축기와 출력기기는 재현하지 않았습니다.'
        if scene.get('ambience'):
            notes += ' 현재 버전은 BGM만, 새 후보는 배경에 맞는 환경 루프 하나를 포함합니다.'
        if scene['id'] == 'reward-result':
            notes += ' 8초에서 새 후보는 음악을 멈추고 결과음을 우선하며 현재 버전은 메뉴 음악으로 전환합니다.'
        if scene['id'] == 'pause-hidden':
            notes += ' 6초 일시정지, 9초 복귀, 12초 앱 숨김, 14초 복귀를 비교합니다.'
        record = {'id': scene['id'], 'label': scene['label'], 'current': current_file,
                  'new': new_file, 'duration': scene['duration'], 'notes': notes,
                  'policyReport': report, 'events': scene['events'] + scene.get('states', [])}
        records.append(record)
        print(f'Mix {scene["id"]}: {len(old_report["accepted"])} current / {len(new_report["accepted"])} new; shared gain {gain:.4f}', flush=True)
    return records
