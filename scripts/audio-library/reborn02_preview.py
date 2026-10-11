"""Rebuild the reborn-02 listening page from installed WAVs and the rollback snapshot.

Scripted offline demonstrations, not game recordings or a claim of listening QA.
The before examples use a repeatable simulation of the old random variant policy.
Neither the source library, installed sounds nor a player's save is modified.
"""
import html
import json

import numpy as np

from build import ROOT, RATE, dump, header, read_segment, resample, write_wav

OUT = ROOT / 'audio-library/reborn-02'
CEILING = 10 ** (-4.01 / 20)


def sound_data(content, cue_id, rng=None, last=None):
    cue = content['sfx'][cue_id]
    urls = cue['urls']
    if rng is None:
        url, pitch, gain = urls[0], 1.0, cue['gain']
    else:
        choices = [url for url in urls if len(urls) == 1 or url != last.get(cue_id)]
        url = choices[int(rng.integers(len(choices)))]
        last[cue_id] = url
        pitch = float(rng.uniform(*cue['pitch']))
        gain = cue['gain'] * float(rng.uniform(1 - cue['volumeVariation'], 1))
    file = ROOT / 'godot' / url.removeprefix('res://')
    meta = header(file)
    x = resample(read_segment(file, meta, 0, min(meta['duration'], 6), True),
                 meta['sample_rate'], pitch)
    return x * gain, {'cue': cue_id, 'file': url, 'pitch': pitch, 'gain': gain, 'pan': 0}


def render(content, events, old=False, duration=6):
    mix = np.zeros((round(duration * RATE), 2), dtype=np.float32)
    trace, last = [], {}
    rng = np.random.default_rng(1027) if old else None
    for time, cue_id in events:
        x, fact = sound_data(content, cue_id, rng, last)
        start = round(time * RATE)
        count = min(len(x), len(mix) - start)
        if count > 0:
            mix[start:start + count] += x[:count]
        trace.append({'at': time, **fact})
    return mix, trace


def scenarios():
    repeat_times = [0.15, 0.90, 1.65, 2.40, 3.15, 3.90, 4.65, 5.40]
    return [
        ('same-target', '같은 검 · 같은 철갑 몬스터',
         '일반/치명타를 번갈아 넣어도 적용 후에는 같은 타격음입니다.',
         [(t, 'critical' if i % 2 else 'enemyHit') for i, t in enumerate(repeat_times)],
         [(t, 'hit_manaSword_metal') for t in repeat_times]),
        ('weapons', '같은 몬스터 · 다른 무기',
         '검 → 마력탄 → 연쇄 번개. 무기의 충격과 마력 특성을 구분합니다.',
         [(t, 'enemyHit') for t in [.2, 1.1, 2.1, 3.1, 4.1, 5.1]],
         [(t, f'hit_{w}_metal') for t, w in zip([.2, 1.1, 2.1, 3.1, 4.1, 5.1],
                    ['manaSword', 'manaSword', 'manaBolt', 'manaBolt', 'chainLightning', 'chainLightning'])]),
        ('materials', '같은 검 · 다른 몬스터 재질',
         '금속 → 돌 → 결정 → 종이. 낮은 충격 위에 짧은 재질음을 합성했습니다.',
         [(t, 'enemyHit') for t in [.2, 1.6, 3.0, 4.4]],
         [(t, f'hit_manaSword_{m}') for t, m in zip([.2, 1.6, 3.0, 4.4],
                    ['metal', 'stone', 'crystal', 'paper'])]),
        ('resources', '마력석 · 협회 주화 · 생환석',
         '마력석 2회 → 주화 2회 → 하급/중급/상급 생환석. 종류와 등급을 고정 배정합니다.',
         [(t, 'magicStoneCollected') for t in [.2, .8, 1.5, 2.1, 3.0, 3.9, 4.8]],
         list(zip([.2, .8, 1.5, 2.1, 3.0, 3.9, 4.8],
             ['pickup_magicStone', 'pickup_magicStone', 'pickup_associationCoin',
              'pickup_associationCoin', 'pickup_revival_low', 'pickup_revival_mid', 'pickup_revival_high']))),
        ('items', '아이템 획득 · 종류에 맞는 접점',
         '삼각김밥 → 검술 교본 → 공구함. 각 아이템 ID가 고정된 재질 계열을 사용합니다.',
         [(t, 'purchase') for t in [.2, .9, 2.0, 2.7, 3.8, 4.5]],
         [(t, f'item_{family}') for t, family in zip([.2, .9, 2.0, 2.7, 3.8, 4.5],
                    ['consumable', 'consumable', 'paper', 'paper', 'metal', 'metal'])]),
        ('association', '협회 · 뽑기 공개와 강화 완료',
         '클릭 → 래치 → 결과 공개 → 강화 완료. 기존 연출의 효과음 역할을 보존했습니다.',
         [(.1, 'buttonClick'), (.55, 'supplyLatch'), (1.2, 'supplyFanfare'), (4.3, 'purchase')],
         [(.1, 'buttonClick'), (.55, 'supplyLatch'), (1.2, 'supplyFanfare'), (4.3, 'purchase')]),
        ('office', '로비 · 낮의 협회 사무실',
         '기존 배경 분류의 빗소리 예시와 새 고정 사무실 루프를 비교합니다. 음악은 포함하지 않았습니다.',
         [(0, 'lobbyRain')], [(0, 'officeDay')]),
    ]


STYLE = """
*{box-sizing:border-box}body{margin:0;background:#fbf6ec;color:#24395c;font:16px/1.6 system-ui,sans-serif}
main{max-width:1050px;margin:auto;padding:32px 24px}h1{font-size:30px;line-height:1.25}h2{font-size:20px}
.note{background:#e8efe9;padding:16px 20px;border-radius:10px}article{background:white;padding:20px 24px;margin:18px 0;border-radius:12px}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}audio{width:100%}small{color:#536276}a{color:#31598b}
.badge{font-size:12px;letter-spacing:.16em}details{margin-top:25px}table{width:100%;border-collapse:collapse;font-size:14px}
td,th{text-align:left;padding:9px;border-bottom:1px solid #e2e5e9}input{padding:12px;width:100%;font:inherit;margin:12px 0}
@media(max-width:640px){.pair{grid-template-columns:1fr}main{padding:20px 14px}h1{font-size:25px}}
"""


def build():
    before_path = OUT / 'rollback/files/godot/data/content.json'
    before = json.loads(before_path.read_text(encoding='utf-8'))
    after = json.loads((ROOT / 'godot/data/content.json').read_text(encoding='utf-8'))
    cards, facts = [], []
    for id, title, note, old_events, new_events in scenarios():
        a, old_trace = render(before, old_events, old=True)
        b, new_trace = render(after, new_events)
        # Equal whole-clip RMS for comparison only; runtime files/gains are untouched.
        rms_a = max(1e-9, float(np.sqrt(np.mean(a ** 2))))
        rms_b = max(1e-9, float(np.sqrt(np.mean(b ** 2))))
        target = min(.055, rms_a, rms_b)
        a *= target / rms_a
        b *= target / rms_b
        shared = min(1.0, CEILING / max(float(np.max(np.abs(a))), float(np.max(np.abs(b))), 1e-9))
        paths = {}
        for name, x in [('before', a), ('after', b)]:
            file = OUT / 'comparisons' / f'{id}-{name}.wav'
            write_wav(file, x * shared)
            paths[name] = file.relative_to(OUT).as_posix()
        facts.append({'id': id, 'label': title, **paths, 'beforeEvents': old_trace,
                      'afterEvents': new_trace, 'comparisonRms': target * shared,
                      'method': 'whole-clip RMS matched; perceived loudness may differ; offline scripted demo'})
        cards.append(f'<article><h2>{html.escape(title)}</h2><p>{html.escape(note)}</p><div class="pair">'
                     f'<div><strong>변경 전</strong><audio controls preload="none" src="{paths["before"]}"></audio></div>'
                     f'<div><strong>적용 후</strong><audio controls preload="none" src="{paths["after"]}"></audio></div></div></article>')
    dump(OUT / 'comparisons/preview-timelines.json', {'scenarios': facts, 'notGameRecording': True,
         'noBgmIncluded': True, 'beforePolicy': 'seeded example of old sample/pitch/gain selection; no crowd attenuation simulated'})
    rows = []
    for id, cue in after['sfx'].items():
        url = '../../godot/' + cue['urls'][0].removeprefix('res://')
        rows.append(f'<tr><td>{html.escape(cue["label"])}</td><td><small>{html.escape(id)}</small></td>'
                    f'<td><audio controls preload="none" src="{html.escape(url)}"></audio></td></tr>')
    page = f'''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>서울 히어로 · 고정 사운드 reborn-02</title><style>{STYLE}</style><main>
<div class="badge">SEOUL HERO / SOUND REBORN 02</div><h1>같은 상황에는 같은 소리,<br>타격에는 더 깊은 재질감</h1>
<p>주신 Sonniss 원본 5개 묶음에서 직접 편집한 적용본입니다. 치명타를 포함해 음원·음높이·음량·방향을 고정했습니다.</p>
<div class="note">아래 6초 비교는 동일한 입력을 바탕으로 편집한 청취 예시이며 게임 녹음이 아닙니다.
비교에만 전체 구간 RMS를 맞췄으며 체감 음량이 같다는 뜻은 아닙니다. 실제 적용 음원과 gain은 변경하지 않았습니다.
BGM 6곡은 그대로이며 이 비교에는 음악을 넣지 않았습니다.</div>
{''.join(cards)}<details><summary>전체 적용 음원 ({len(after['sfx'])}개 고정 프로필)</summary>
<input id="search" placeholder="무기 · 재질 · 효과음 이름 검색" aria-label="효과음 검색"><table><thead><tr><th>용도</th><th>고정 ID</th><th>듣기</th></tr></thead><tbody>{''.join(rows)}</tbody></table></details>
<p><a href="manifest.json">원본 구간·합성 설정</a> · <a href="../../godot/data/content.json">게임 연결 데이터</a> ·
<a href="qa/runtime-audio.json">Godot 진단 결과</a> · <a href="qa/deployed-data.json">파일·BGM·콘텐츠 확인</a></p>
<small>신호 분석과 Godot Dummy 출력 확인을 수행합니다. 실제 기기 청음 및 전체 플레이 QA는 별도입니다.</small></main>
<script>document.addEventListener('play',e=>{{document.querySelectorAll('audio').forEach(a=>{{if(a!==e.target)a.pause()}})}},true);
document.getElementById('search').addEventListener('input',e=>{{let q=e.target.value.toLowerCase();document.querySelectorAll('tbody tr').forEach(r=>r.hidden=!r.textContent.toLowerCase().includes(q))}});</script></html>'''
    (OUT / 'index.html').write_text(page, encoding='utf-8')
    print(json.dumps({'previews': len(facts), 'cues': len(after['sfx']), 'index': str(OUT / 'index.html')}))


if __name__ == '__main__':
    build()
