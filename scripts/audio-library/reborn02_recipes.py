"""Fixed, original-source sound identities for reborn-02.

All coordinates below refer to the user's read-only Sonniss collection. Runtime
does not select variants or alter pitch/gain. Depth is printed into one WAV.
The previous recipes are retained as cut-reference documentation, not decoded
production audio inputs. This module never deploys or edits source recordings.
"""
from copy import deepcopy

from reborn_recipes import REBORN_CUES, L, V, C

MATERIALS = ('soft', 'metal', 'stone', 'crystal', 'energy', 'paper')
WEAPONS = ('manaSword', 'guardianDaggers', 'piercingShot', 'chainLightning',
           'manaBombard', 'manaBolt', 'manaShotgun', 'autoTurret', 'mineLayer')


def fixed(label, category, gain, interval, concurrency, priority, variant,
          note, protected=False, loop=False):
    return C(label, category, gain, interval, concurrency, priority, [variant],
             note=note, protected=protected, pitch=(1, 1),
             volumeVariation=0, loop=loop)


def body(gain=.24, delay=.0):
    # Fourth body impact, separate from the former enemyHit default's first hit.
    # Remove the measured 30ms quiet approach so printed low body starts at
    # contact rather than lagging behind the separate weapon launch cue.
    return L('punchBody', 3.21, .22, gain, delay, hp=85, lp=1450, speed=.94)


MATERIAL_LAYERS = {
    'soft': L('wetWoodHit', .01, .18, .46, hp=140, lp=6900),
    'metal': L('metalThud', 1.24, .23, .43, hp=170, lp=6600, speed=1.08),
    'stone': L('spearImpact', 7.90, .23, .50, hp=120, lp=4700, speed=.92),
    'crystal': L('iceSnap', 3.69, .23, .42, hp=580, lp=10100),
    'energy': L('arcPower', 1.20, .23, .42, hp=420, lp=8800),
    'paper': L('cardFlip', .01, .14, .57, hp=650, lp=6800),
}
SIGNATURES = {
    'manaSword': L('swordSlide', 8.475, .20, .37, hp=270, lp=10600, speed=1.08),
    'guardianDaggers': L('springFlick', 3.26, .16, .32, hp=820, lp=8200),
    'piercingShot': L('iceFissure', 1.11, .17, .37, hp=480, lp=9700),
    'chainLightning': L('arcSnap', .59, .18, .42, hp=550, lp=10000),
    'manaBombard': L('boom11', .23, .39, .43, hp=100, lp=5100),
    'manaBolt': L('lightEnchant', .50, .23, .35, hp=470, lp=9500),
    'manaShotgun': L('crateBang', .02, .22, .41, hp=150, lp=7900),
    'autoTurret': L('metalTape', .38, .18, .31, hp=370, lp=7800),
    'mineLayer': L('caseDown', .02, .26, .38, hp=110, lp=5100, speed=.91),
}
WEAPON_LABELS = {
    'manaSword': '마력검', 'guardianDaggers': '수호 표창',
    'piercingShot': '관통탄', 'chainLightning': '연쇄번개',
    'manaBombard': '마력폭격', 'manaBolt': '마력탄',
    'manaShotgun': '마력산탄', 'autoTurret': '자동 포탑', 'mineLayer': '지뢰',
}
MATERIAL_LABELS = {'soft': '연성', 'metal': '금속', 'stone': '돌',
                   'crystal': '결정', 'energy': '마력', 'paper': '종이'}


def short_tail(layer, delay=.055, gain=.13):
    result = deepcopy(layer)
    result.update(delay=delay, gain=gain, duration=min(result['duration'], .17),
                  highpass_hz=max(result.get('highpass_hz', 120), 200),
                  lowpass_hz=min(result.get('lowpass_hz', 4700), 4700),
                  fade_in=.008, fade_out=.065)
    return result


def defaults():
    """Re-master fixed, purpose-selected cuts; never read reborn-01 WAV files."""
    result = {}
    for cue_id, old in REBORN_CUES.items():
        if cue_id == 'critical':
            continue  # Builder copies enemyHit bytes exactly after rendering.
        cue = deepcopy(old)
        # Previous explicit alternate cuts become the fixed identity, with new
        # printed body/tail. There is no random selection during build or play.
        chosen = deepcopy(old['variants'][min(1, len(old['variants']) - 1)])
        if old['category'] == 'combat':
            chosen['layers'].append(body(.16 if 'Fired' in cue_id else .23))
            chosen['layers'].append(short_tail(chosen['layers'][0], .035, .10))
            chosen['fade_out'] = min(chosen.get('fade_out', .06), .12)
            chosen['target_rms'] = min(chosen['target_rms'], .115)
        elif old['category'] == 'ui' and cue_id not in ('waveCountdownTick', 'buttonClick', 'magicStoneCollected'):
            # Quiet real switch contact anchors tonal UI sounds without turning
            # every purchase into a large impact.
            chosen['layers'].append(L('radioWheel', .83, .13, .10, hp=260, lp=4300))
        chosen['note'] += ' reborn-02: 고정 원본 구간을 새 몸통/짧은 잔향과 재합성.'
        cue.update(variants=[chosen], count=1, pitch=[1, 1], volumeVariation=0,
                   note=old['note'] + ' 단일 고정 음원·중앙 출력.')
        result[cue_id] = cue
    # A stable plain hit fallback, also the exact compatibility critical alias.
    result['enemyHit'] = fixed('기본 적중 · 고정 연성 접점', 'combat', .16, .085, 3, 2,
        V(.31, .0015, .065, .10, body(.32), deepcopy(MATERIAL_LAYERS['soft']),
          short_tail(MATERIAL_LAYERS['soft']),
          note='정의되지 않은 공격의 고정 연성 타격. 치명타와 바이트 동일.'),
        '재질/무기 맥락이 없는 레거시 호출의 고정 기본 타격.')
    return result


FIXED_CUES = defaults()
for weapon in WEAPONS:
    for material in MATERIALS:
        heavy = weapon in ('manaBombard', 'manaShotgun', 'mineLayer')
        signature = deepcopy(SIGNATURES[weapon])
        surface = deepcopy(MATERIAL_LAYERS[material])
        surface['delay'] = .006
        duration = .43 if heavy else .32
        gain = .18 if heavy else .14
        if weapon == 'guardianDaggers':
            gain = .09
        FIXED_CUES[f'hit_{weapon}_{material}'] = fixed(
            f'{WEAPON_LABELS[weapon]} 적중 · {MATERIAL_LABELS[material]}',
            'combat', gain, .12 if heavy else .085, 2, 2,
            V(duration, .0015, .075 if heavy else .060, .108 if heavy else .095,
              signature, body(.36 if heavy else .26), surface,
              short_tail(surface, .045, .12),
              note='무기 시작음 + 낮은 충격 몸통 + 대상 재질 + 짧은 고정 잔향. '
                   '치명타/개체/레벨/순서에 따른 변경 없음.'),
            '한 번의 적중을 한 WAV로 원자적으로 재생. 모든 레이어를 제작 시 합성.')

for material in MATERIALS:
    surface = deepcopy(MATERIAL_LAYERS[material])
    surface.update(speed=surface.get('speed', 1) * .88, gain=.50)
    FIXED_CUES[f'death_{material}'] = fixed(
        f'처치 · {MATERIAL_LABELS[material]} 해소', 'combat', .16, .18, 2, 2,
        V(.48, .003, .13, .088, surface, body(.27, .018),
          L('crystalWhoosh', 1.15, .30, .12, .075, hp=1100, lp=7400),
          note='대상 재질의 짧은 무너짐과 마력 해소. 비명/고어/긴 저음 없음.'),
        '처치는 적중과 다른 사건이며 같은 대상 재질에는 항상 같은 해소음.')

FIXED_CUES['pickup_magicStone'] = fixed('마력석 회수', 'ui', .085, .09, 2, 3,
    V(.25, .002, .065, .065,
      L('musicBoxA', .03, .22, .78, hp=500, lp=10400, speed=1.16),
      L('glassyAccept', .015, .14, .18, .012, hp=900, lp=9000),
      note='단일 결정 공명. 여러 회수에도 음정과 음량 고정.'),
    '마력석만의 짧은 고정 결정 음색.')
FIXED_CUES['pickup_associationCoin'] = fixed('협회 코인 회수', 'ui', .14, .11, 2, 3,
    V(.31, .001, .07, .075,
      L('coinFlip', .01, .25, .85, hp=250, lp=9000),
      L('springFlick', 5.23, .14, .14, .028, hp=750, lp=7800),
      note='금속 코인 한 번의 접점과 작은 공명. 마력석과 구별.'),
    '협회 코인의 고정 금속 정체성.')
for grade, alias, speed, length, gain in (
    ('low', 'musicBoxA', .95, .47, .17),
    ('mid', 'musicBoxB', 1.06, .56, .19),
    ('high', 'musicBoxC', 1.13, .64, .21),
):
    FIXED_CUES[f'pickup_revival_{grade}'] = fixed(
        f'생환석 회수 · {grade}', 'ui', gain, .16, 2, 4,
        V(length, .004, .12, .083,
          L(alias, .03, length - .05, .74, hp=350, lp=10000, speed=speed),
          L('lightEnchant', .90, .26, .24, .035, hp=700, lp=9400),
          note='등급별로 서로 다른 원본 공명을 고정. 재생 중 변조 없음.'),
        '생환석 종류와 등급이 같으면 같은 고정 음원.')

ITEM_LAYERS = {
    'consumable': L('glassyAccept', .015, .29, .80, hp=350, lp=10000),
    'cloth': L('clothPat', .055, .27, .88, hp=150, lp=7200),
    'optic': L('musicBoxB', .025, .34, .75, hp=700, lp=10200),
    'paper': L('cardFlip', .01, .14, .85, hp=300, lp=7200),
    'metal': L('antiqueLock', 2.41, .29, .75, hp=180, lp=8300),
    'arcane': L('lightEnchant', 1.26, .32, .78, hp=300, lp=10200),
    'circuitry': L('arcPower', 2.03, .26, .65, hp=550, lp=8300),
}
for family, layer in ITEM_LAYERS.items():
    FIXED_CUES[f'item_{family}'] = fixed(
        f'아이템 획득 · {family}', 'ui', .31, .12, 2, 4,
        V(.44, .002, .10, .079, deepcopy(layer),
          L('kalimba', .01, .29, .25, .055, hp=480, lp=9000),
          note='아이템 기능/소재 계열의 접점 뒤 고정 승인음. 개별 ID 배정은 연결표에 기록.'),
        '동일 콘텐츠 ID에는 같은 가족 음원. 무작위 가족 선택 없음.')

FIXED_CUES['officeDay'] = fixed('협회 사무실 · 낮 실내와 먼 도시', 'ambience', .052, 0, 1, 0,
    V(16, .01, .01, .050,
      L('spaceRoom', 40.0, 16.8, .73, hp=90, lp=1650),
      L('trafficPass', 1.20, 16.7, .18, hp=180, lp=1300),
      note='제공 원본의 중립 실내 소음 구간과 저역/고역을 절제한 먼 도시층. '
           '16초 루프·0.5초 이음부 교차 합성·무작위 돌발음 없음.'),
    '최신 밝은 사무실에 고정 환경음 하나. 음악 볼륨과 음소거를 따름.', loop=True)

# Cue identity still exists for callers in the preserved web game. The builder
# writes precisely the same file bytes and mix settings as enemyHit.
FIXED_CUES['critical'] = deepcopy(FIXED_CUES['enemyHit'])
FIXED_CUES['critical'].update(label='치명타 호환 ID · 기본 적중과 동일',
                              alias_of='enemyHit',
                              note='치명타 사운드 차등 없음. enemyHit WAV와 바이트 동일.')
