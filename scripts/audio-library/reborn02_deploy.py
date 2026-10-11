"""Deploy/verify the authorized fixed reborn-02 audio without rebuilding source recordings.

Run --deploy, node scripts/export-godot-content.mjs --audio-only, then --verify.
Original Music files, previous WAVs and BGM are preserved; no player saves are read.
"""
import argparse
import array
import hashlib
import json
from pathlib import Path
import shutil
import wave

ROOT = Path(__file__).resolve().parents[2]
REVISION = 'reborn-02'
PREVIEW = ROOT / 'audio-library' / REVISION
DEPLOYED = ROOT / 'assets/audio/sfx' / REVISION
MUSIC = Path('C:/Users/geniu/Music')
MATERIALS = {'soft', 'metal', 'stone', 'crystal', 'energy', 'paper'}


def digest(file):
    return hashlib.sha256(file.read_bytes()).hexdigest()


def read_json(file):
    return json.loads(file.read_text(encoding='utf-8'))


def write_json(file, value):
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def preserve(relative):
    source = ROOT / relative
    target = PREVIEW / 'rollback/files' / relative
    if source.exists() and not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    return target


def verify_candidates(manifest):
    report = read_json(PREVIEW / 'verification.json')
    if report.get('problems'):
        raise ValueError('Candidate verification has unresolved errors')
    if not manifest.get('cues'):
        raise ValueError('No fixed sound candidates')
    files, originals = [], {}
    for cue_id, cue in manifest['cues'].items():
        variants = cue.get('variants', [])
        if len(variants) != 1:
            raise ValueError(f'{cue_id} needs exactly one fixed WAV')
        variant = variants[0]
        source = (PREVIEW / variant['file']).resolve()
        if not source.is_relative_to((PREVIEW / 'sounds').resolve()):
            raise ValueError(f'Candidate outside sounds/: {source}')
        if digest(source) != variant['sha256']:
            raise ValueError(f'Candidate hash changed: {cue_id}')
        loop = bool(cue.get('loop', variant.get('loop', False)))
        with wave.open(str(source)) as wav:
            if (wav.getframerate(), wav.getsampwidth(), wav.getnchannels()) != (48000, 2, 2 if loop else 1):
                raise ValueError(f'Unexpected PCM format: {cue_id}')
            samples = array.array('h', wav.readframes(wav.getnframes()))
            if not samples or max(abs(sample) for sample in samples) > 32768 * 10 ** (-4 / 20) + 1:
                raise ValueError(f'Empty or excessive peak: {cue_id}')
        for layer in variant.get('layers', []):
            relative = layer['source']
            original = (MUSIC / relative).resolve()
            if not original.is_relative_to(MUSIC.resolve()) or not original.is_file():
                raise ValueError(f'Original outside provided Music library: {relative}')
            expected = layer['sha256']
            if relative in originals and originals[relative] != expected:
                raise ValueError(f'Conflicting original hashes: {relative}')
            originals[relative] = expected
        files.append((cue_id, variant, source))
    # Hash once per used original, including material shared by several composite WAVs.
    for relative, expected in originals.items():
        if digest(MUSIC / relative) != expected:
            raise ValueError(f'Original source changed: {relative}')
    old_file = PREVIEW / 'rollback/files/godot/data/content.json'
    old = read_json(old_file if old_file.exists() else ROOT / 'godot/data/content.json')
    missing = set(old['sfx']) - set(manifest['cues'])
    if missing:
        raise ValueError(f'Existing cue IDs missing: {sorted(missing)}')
    return files, originals


def deploy():
    manifest = read_json(PREVIEW / 'manifest.json')
    candidates, originals = verify_candidates(manifest)
    old_content = preserve(Path('godot/data/content.json'))
    for relative in ('godot/data/import-provenance.json', 'src/data/sourcedAudio.ts'):
        preserve(Path(relative))
    old = read_json(old_content)
    previous = []
    for cue in old['sfx'].values():
        for url in cue['urls']:
            relative = Path('godot') / url.removeprefix('res://')
            target = preserve(relative)
            if not target.exists():
                raise ValueError(f'Cannot preserve existing WAV: {relative}')
            preserve(Path(str(relative) + '.import'))
            previous.append({'file': relative.as_posix(), 'sha256': digest(target)})
    paths, settings, provenance = {}, {}, {}
    for cue_id, cue in manifest['cues'].items():
        settings[cue_id] = {key: cue[key] for key in ('label', 'gain', 'interval', 'concurrency', 'priority', 'protected')}
        settings[cue_id].update(group=cue['category'], loop=bool(cue.get('loop', cue['variants'][0].get('loop', False))), pitch=[1, 1], volumeVariation=0)
        paths[cue_id] = []
        provenance[cue_id] = {'label': cue['label'], 'note': cue.get('note', ''), 'variants': []}
    for cue_id, variant, source in candidates:
        relative = Path(cue_id) / source.name
        target = DEPLOYED / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        paths[cue_id].append(f'sfx/{REVISION}/' + relative.as_posix())
        provenance[cue_id]['variants'].append({**variant, 'file': relative.as_posix()})
    policy = {**manifest['policy'], 'busyAttenuation': 0, 'noConsecutiveVariant': False,
              'status': 'deployed; user authorized fixed sound identities from provided Sonniss originals'}
    connections = {**manifest['connections'], 'status': 'deployed'}
    generated = '// Generated by scripts/audio-library/reborn02_deploy.py from the authorized reborn-02 manifest.\n'
    generated += '// Previous runtime mapping/WAVs remain in audio-library/reborn-02/rollback/files.\n'
    for name, value in [('sourcedSfxPaths', paths), ('sourcedSfxSettings', settings),
                        ('sourcedAudioPolicy', policy), ('sourcedAudioConnections', connections)]:
        generated += f'export const {name} = {json.dumps(value, ensure_ascii=False, indent=2)} as const;\n\n'
    (ROOT / 'src/data/sourcedAudio.ts').write_text(generated, encoding='utf-8')
    write_json(DEPLOYED / 'provenance.json', {
        'revision': REVISION, 'source': 'Sonniss GDC 2026 bundle 1–5, user-provided Music archive',
        'source_unchanged': True, 'manifest': f'audio-library/{REVISION}/manifest.json',
        'licenses': f'audio-library/{REVISION}/provenance/', 'identities': 'src/data/audioIdentity.ts',
        'policy': policy, 'connections': connections, 'cues': provenance,
    })
    write_json(PREVIEW / 'rollback/audio-files.json', previous)
    write_json(PREVIEW / 'deployment.json', {
        'revision': REVISION, 'authorization': 'User approved fixed-identity SFX/ambience rebuild using provided original library',
        'cues': len(paths), 'one_shot_cues': sum(not cue['loop'] for cue in settings.values()),
        'ambience_cues': sum(cue['loop'] for cue in settings.values()), 'files': len(candidates),
        'bytes': sum(source.stat().st_size for _, _, source in candidates),
        'assets': [{'file': (DEPLOYED / cue_id / source.name).relative_to(ROOT).as_posix(), 'sha256': variant['sha256']}
                   for cue_id, variant, source in candidates],
        'originals': originals,
        'bgm': {file.relative_to(ROOT).as_posix(): digest(file)
                for file in sorted((ROOT / 'assets/audio/bgm/provided').glob('*.mp3'))},
        'runtime_verification': 'pending', 'direct_listening': 'not performed; signal analysis and editing only',
        'rollback': 'Preserved prior content.json, sourcedAudio.ts and every mapped WAV; old source assets stay unchanged',
    })
    print(json.dumps({'deployed_cues': len(paths), 'files': len(candidates), 'originals': len(originals), 'previous_files_preserved': len(previous)}))


def verify_deployment():
    report = read_json(PREVIEW / 'deployment.json')
    content = read_json(ROOT / 'godot/data/content.json')
    old = read_json(PREVIEW / 'rollback/files/godot/data/content.json')
    problems = []
    for asset in report['assets']:
        for file in (ROOT / asset['file'], ROOT / 'godot' / asset['file']):
            if not file.exists() or digest(file) != asset['sha256']:
                problems.append(f'Asset mismatch: {file.relative_to(ROOT)}')
        settings = ROOT / 'godot' / (asset['file'] + '.import')
        if not settings.exists() or 'compress/mode=0' not in settings.read_text(encoding='utf-8'):
            problems.append(f'PCM import missing: {asset["file"]}')
    for relative, expected in report['bgm'].items():
        for file in (ROOT / relative, ROOT / 'godot' / relative):
            if not file.exists() or digest(file) != expected:
                problems.append(f'BGM changed: {file.relative_to(ROOT)}')
    for relative, expected in report['originals'].items():
        if digest(MUSIC / relative) != expected:
            problems.append(f'Original changed: {relative}')
    sfx = content['sfx']
    for cue_id, cue in sfx.items():
        if len(cue['urls']) != 1 or any(f'/sfx/{REVISION}/' not in url for url in cue['urls']):
            problems.append(f'Non-fixed or wrong revision cue: {cue_id}')
        if cue['pitch'] != [1, 1] or cue['volumeVariation'] != 0:
            problems.append(f'Non-fixed playback settings: {cue_id}')
    mappings = content['audioConnections']
    identity = mappings.get('identities', {})
    for content_key, identity_key in [('enemies', 'monsterMaterials'), ('items', 'items'), ('weapons', 'weaponHits'), ('weapons', 'weaponPurchases')]:
        expected, actual = set(content[content_key]), set(identity.get(identity_key, {}))
        if expected != actual:
            problems.append(f'Identity coverage {identity_key}: missing {sorted(expected - actual)}, extra {sorted(actual - expected)}')
    if set(identity.get('monsterMaterials', {}).values()) != MATERIALS or identity.get('defaultMaterial') != 'soft':
        problems.append('Material identities/default incomplete')
    for weapon, hits in identity.get('weaponHits', {}).items():
        if weapon == 'manaField':
            if hits is not None:
                problems.append('Sustained manaField must stay quiet')
        elif not isinstance(hits, dict) or set(hits) != MATERIALS:
            problems.append(f'Incomplete weapon/material identities: {weapon}')
    required = list(mappings['enemyActions'].values()) + list(mappings['lobbyBackgrounds'].values())
    required += [cue for stages in mappings['weaponStages'].values() for cue in stages.values() if isinstance(cue, str)]
    required += [cue for hits in identity.get('weaponHits', {}).values() if isinstance(hits, dict) for cue in hits.values()]
    required += list(identity.get('materialDeaths', {}).values()) + list(identity.get('items', {}).values())
    required += list(identity.get('weaponPurchases', {}).values()) + list(identity.get('aliases', {}).values())
    for pickup in identity.get('pickups', {}).values():
        required += list(pickup.values()) if isinstance(pickup, dict) else [pickup]
    problems += [f'Missing mapped cue: {cue}' for cue in sorted(set(required)) if cue not in sfx]
    if identity.get('aliases', {}).get('critical') != 'enemyHit':
        problems.append('Critical must use the normal hit identity')
    if mappings['lobbyBackgrounds'].get('officeDay') != 'officeDay':
        problems.append('Daytime office ambience not connected')
    if set(old['sfx']) - set(sfx) or len(sfx) != report['cues']:
        problems.append('Prior cue compatibility or manifest count mismatch')
    config = content['audioConfig']
    if config.get('busyAttenuation') != 0 or config.get('noConsecutiveVariant') is not False:
        problems.append('Playback still varies with busy state or previous variant')
    if (config.get('maxVoices'), config.get('normalVoices'), config.get('reservedImportantVoices')) != (16, 12, 4):
        problems.append('Voice limits changed')
    allowed = {'sfx', 'audioConfig', 'audioConnections'}
    problems += [f'Unexpected content change: {key}' for key in set(old) | set(content)
                 if key not in allowed and old.get(key) != content.get(key)]
    write_json(PREVIEW / 'qa/deployed-data.json', {
        'scope': 'fixed WAV/settings, original/BGM/source/Godot hashes, identity coverage, PCM imports and unchanged numerical/save/art content',
        'files': len(report['assets']), 'cues': len(sfx), 'originals': len(report['originals']), 'bgm': len(report['bgm']),
        'identities': {'monsters': len(identity.get('monsterMaterials', {})), 'items': len(identity.get('items', {}))},
        'problems': problems, 'gameplay_device_full_tests': 'not performed',
    })
    print(json.dumps({'checked_files': len(report['assets']), 'cues': len(sfx), 'problems': problems}))
    if problems:
        raise SystemExit(1)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--deploy', action='store_true')
    action.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    deploy() if args.deploy else verify_deployment()
