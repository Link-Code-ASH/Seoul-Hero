"""Render reborn-02 masters directly from read-only Sonniss source recordings.

This command writes only audio-library/reborn-02. Runtime deployment is separate.
No random source selection, DSP randomization or synthesized oscillator layers.
"""
import argparse
from collections import defaultdict
from copy import deepcopy
import json
from pathlib import Path
import shutil

import numpy as np

from build import ROOT, RATE, header, read_segment, digest, dump
import reborn_build as dsp
from reborn02_recipes import FIXED_CUES, MATERIALS, WEAPONS

OUTPUT = ROOT / 'audio-library/reborn-02'
POLICY = deepcopy(dsp.POLICY)
POLICY.update(busyAttenuation=0, noConsecutiveVariant=False,
              status='fixed identities; original-source offline masters',
              critical='same cue and gain as ordinary hit; visual only',
              pan=0, pitch=1, volumeVariation=0)


def build(source):
    source = source.resolve()
    if len(list(source.glob('Sonniss.com-GDC2026-GameAudioBundle*of5'))) != 5:
        raise ValueError('The user-provided five-part Sonniss library was not found.')
    reference = ROOT / 'audio-library/reborn-01/inventory.json'
    inventory = json.loads(reference.read_text(encoding='utf-8'))
    records = {row['path']: row for row in inventory['sources']}
    wanted = {layer['source'] for cue in FIXED_CUES.values()
              for variant in cue['variants'] for layer in variant['layers']}
    used_records = {}
    for relative in sorted(wanted):
        path = source / relative
        record = deepcopy(records[relative])
        actual = digest(path)
        if actual != record['sha256']:
            raise ValueError(f'Original differs from preserved source hash: {relative}')
        if header(path)['duration'] != record['duration']:
            raise ValueError(f'Original duration changed: {relative}')
        used_records[relative] = record
    # Reuse proven WAV decoding, EQ, gain, trim/fade and loop seam code. Redirect
    # its preview/output folder; it never reads a previous processed sound.
    dsp.OUTPUT = OUTPUT
    OUTPUT.mkdir(parents=True, exist_ok=True)
    cues, used = {}, defaultdict(list)
    for cue_id, cue in FIXED_CUES.items():
        if cue.get('alias_of'):
            continue
        variant = dsp.render_variant(source, used_records, cue_id, cue, 1, cue['variants'][0])
        for layer in variant['layers']:
            used[layer['source']].append(cue_id)
        cues[cue_id] = {**{k: v for k, v in cue.items() if k != 'variants'},
                       'id': cue_id, 'variants': [variant], 'events': [cue_id],
                       'notes': cue['note'], 'role': 'fixed semantic audio identity'}
        print(f'Mastered {cue_id}', flush=True)
    for cue_id, cue in FIXED_CUES.items():
        if not cue.get('alias_of'):
            continue
        master = cues[cue['alias_of']]
        variant = deepcopy(master['variants'][0])
        target = OUTPUT / 'sounds' / cue_id / '01.wav'
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(OUTPUT / variant['file'], target)
        variant.update(file=target.relative_to(OUTPUT).as_posix(), alias_of=cue['alias_of'])
        cues[cue_id] = {**{k: v for k, v in cue.items() if k != 'variants'},
                       'id': cue_id, 'variants': [variant], 'events': [cue_id],
                       'notes': cue['note'], 'role': 'exact compatibility alias'}
    licenses = []
    for index, part in enumerate(sorted(source.glob('Sonniss.com-GDC2026-GameAudioBundle*of5')), 1):
        for path in sorted(part.iterdir()):
            if path.suffix.lower() not in ('.pdf', '.txt'):
                continue
            target = OUTPUT / 'provenance' / f'part-{index}' / path.name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
            licenses.append({'source': path.relative_to(source).as_posix(),
                             'sha256': digest(path), 'copy': target.relative_to(OUTPUT).as_posix()})
    for relative, record in used_records.items():
        record.update(uses=list(dict.fromkeys(used[relative])),
                      preservation='SHA-256 rechecked; read-only original',
                      selection='explicit measured transient/steady-room intervals; no runtime randomization')
    dump(OUTPUT / 'inventory.json', {'source_root': str(source),
         'original_collection_files': len(inventory['sources']),
         'sources': list(used_records.values()), 'licenses': licenses,
         'complete_prior_inventory': '../reborn-01/inventory.json'})
    manifest = {'version': 2, 'revision': 'reborn-02', 'mode': 'offline-master; separate deployment',
                'sample_rate': RATE, 'peak_ceiling_dbfs': -4,
                'builder_sha256': digest(Path(__file__)),
                'recipes_sha256': digest(Path(__file__).with_name('reborn02_recipes.py')),
                'numpy_version': np.__version__, 'policy': POLICY,
                'summary': {'cues': len(cues), 'edited_files': len(cues),
                            'sfx': sum(not cue.get('loop', False) for cue in cues.values()),
                            'ambience': sum(bool(cue.get('loop')) for cue in cues.values()),
                            'used_original_sources': len(used_records),
                            'source_collection_files': len(inventory['sources']),
                            'weapon_material_hits': len(WEAPONS) * len(MATERIALS),
                            'listening': 'Audio signal verification; human listening not performed',
                            'originals': 'unchanged; selected SHA-256 rechecked', 'bgm': 'not touched'},
                'cues': cues, 'connections': deepcopy(dsp.CONNECTIONS),
                'source_inventory': 'inventory.json'}
    manifest['connections'].update(status='fixed identity profiles; active mapping authored during deployment')
    dump(OUTPUT / 'manifest.json', manifest)
    verify()
    write_readme(manifest)


def verify():
    manifest = json.loads((OUTPUT / 'manifest.json').read_text(encoding='utf-8'))
    results = []
    for cue_id, cue in manifest['cues'].items():
        if len(cue['variants']) != 1 or cue['pitch'] != [1, 1] or cue['volumeVariation'] != 0:
            raise ValueError(f'Non-fixed cue metadata: {cue_id}')
        variant = cue['variants'][0]
        path = OUTPUT / variant['file']
        meta = header(path)
        x = read_segment(path, meta, 0, meta['duration'], bool(cue.get('loop')))
        peak = float(np.max(np.abs(x)))
        if meta['sample_rate'] != RATE or meta['bits'] != 16 or meta['channels'] != (2 if cue.get('loop') else 1):
            raise ValueError(f'Invalid audio format: {cue_id}')
        if peak > 10 ** (-4 / 20) + 1 / 32768 or digest(path) != variant['sha256']:
            raise ValueError(f'Invalid peak/hash: {cue_id}')
        if cue.get('loop') and abs(meta['duration'] - 16) > 1 / RATE:
            raise ValueError(f'Invalid loop duration: {cue_id}')
        results.append({'cue': cue_id, 'peak_dbfs': round(20 * np.log10(max(peak, 1e-9)), 3),
                        'rms_dbfs': round(20 * np.log10(max(float(np.sqrt(np.mean(x*x))), 1e-9)), 3),
                        'duration': meta['duration'], 'channels': meta['channels'],
                        'sha256': variant['sha256'], 'pass': True})
    if manifest['cues']['critical']['variants'][0]['sha256'] != manifest['cues']['enemyHit']['variants'][0]['sha256']:
        raise ValueError('Critical and ordinary fallback WAV bytes differ')
    dump(OUTPUT / 'qa/audio-signal.json', {'pass': True, 'files': len(results),
         'critical_alias_identical': True, 'results': results,
         'limitations': 'Signal/format/identity verification. Not human listening or full gameplay QA.'})
    dump(OUTPUT / 'verification.json', {'problems': [], 'verified_files': len(results),
         'critical_alias_identical': True, 'report': 'qa/audio-signal.json',
         'method': 'complete PCM scan, source hashes, fixed metadata; no listening claim'})
    print(f'Verified {len(results)} fixed masters; critical alias is byte-identical.', flush=True)


def write_readme(manifest):
    summary = manifest['summary']
    text = f'''# reborn-02 · 고정된 사운드 정체성과 짧은 깊이

사용자가 제공한 `C:/Users/geniu/Music`의 Sonniss GDC2026 묶음 5개 폴더를 직접 읽어 제작했다. 전체 {summary['source_collection_files']}개 원본 중 {summary['used_original_sources']}개 재료를 명시한 구간으로 편집했다. 이전 가공 WAV를 제작 입력으로 사용하지 않는다. 원본 SHA-256을 재확인했으며 원본과 BGM은 수정하지 않았다.

## 결과와 재현

- 단일 고정 WAV {summary['cues']}개: 단발 {summary['sfx']}개, 16초 스테레오 환경 루프 {summary['ambience']}개.
- 무기 9종 × 재질 6종 = 적중 {summary['weapon_material_hits']}개. 마력장은 지속 피해음을 추가하지 않는다.
- 단발은 48kHz/16bit 모노이며 중앙 출력. 제작 시 무기 접점·낮은 몸통·대상 재질·짧은 잔향을 한 WAV로 합성했다.
- 모든 cue는 단일 음원, runtime pitch 1, volumeVariation 0. `critical`과 `enemyHit`는 WAV 바이트와 gain이 같다.
- `inventory.json`은 원본 경로·해시·라이선스, `manifest.json`은 구간·EQ·고정 속도·레이어 gain/delay·페이드·정규화 기록을 보존한다. `provenance/`는 제공 묶음의 라이선스 사본이다.
- 빌드: `python scripts/audio-library/reborn02_build.py build --source C:/Users/geniu/Music`
- 신호 확인: `python scripts/audio-library/reborn02_build.py verify`
- 빌더는 이 폴더에만 쓴다. 실제 적용은 공용 데이터와 exporter를 통해 별도 수행한다. `reborn-01`은 보존한다.

## 확인 결과

`qa/audio-signal.json`: 파일 전체의 크기·48kHz·16bit·채널 수·해시·피크 −4dBFS 이하·루프 16초·치명타 바이트 동일을 확인했다. 직접 청취와 실제 모바일/전투 플레이 QA는 수행하지 않았다. 청취 비교는 오프라인 편집 자료이며 실제 게임 녹음으로 표시하지 않는다.

## 새로운 소리 배정

적중은 `hit_<weaponId>_<material>`, 처치는 `death_<material>`. 재질은 soft/metal/stone/crystal/energy/paper이다. 드롭은 마력석·협회 코인·생환석 low/mid/high를 고정 배정한다. 아이템은 consumable/cloth/optic/paper/metal/arcane/circuitry의 소재·용도 음색을 콘텐츠 ID에 명시적으로 연결한다. 서로 같은 소재인 콘텐츠가 소리를 공유할 수 있으며 무작위 선택은 하지 않는다. 최신 사무실에는 `officeDay` 고정 실내·먼 도시 루프를 사용한다.
'''
    (OUTPUT / 'README.md').write_text(text, encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('build', 'verify'))
    parser.add_argument('--source', default='C:/Users/geniu/Music')
    args = parser.parse_args()
    if args.command == 'build':
        build(Path(args.source))
    else:
        verify()
