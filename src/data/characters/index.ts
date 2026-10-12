import { DEFAULT_STATS } from '../stats';
import type { Character, CharacterStatAdjustment } from '../types';
import type { PlayerStats } from '../stats';

/** Build future characters as explicit differences from Song Jinwoo's neutral baseline. */
export function characterStatsFromBaseline(adjustments: readonly CharacterStatAdjustment[]): PlayerStats {
  const result = { ...DEFAULT_STATS };
  for (const stat of Object.keys(DEFAULT_STATS) as (keyof PlayerStats)[]) {
    const matching = adjustments.filter(adjustment => adjustment.stat === stat);
    const flat = matching.filter(adjustment => adjustment.operation === 'add').reduce((sum, adjustment) => sum + adjustment.value, 0);
    const percent = matching.filter(adjustment => adjustment.operation === 'multiply').reduce((sum, adjustment) => sum + adjustment.value - 1, 0);
    result[stat] = Math.max(0, DEFAULT_STATS[stat] + flat + DEFAULT_STATS[stat] * percent);
  }
  return result;
}
export const characters: Record<string, Character> = {
  awakener: {
    id: 'awakener', name: '송진우', description: '현장에서 얻은 장비를 빠르게 익혀 자신의 방식으로 활용하는 각성자.',
    background: '게이트 사태 전에는 서울에서 평범하게 살아가던 청년. 각성 후 엘리트 코스보다 붕괴 지대의 실전을 택했고, 수많은 현장 작전을 거쳤다.',
    personality: '겉으로는 무심하고 크게 동요하지 않는다. 치밀한 계획보다 위험 속의 즉각적인 판단과 생존에 강하며, 서울 사람다운 현실적인 생활 습관이 남아 있다.',
    trait: { name: '현장 적응', description: '모든 무기 피해 +5%', weaponDamageBonus: 0.05 },
    baseStats: { ...DEFAULT_STATS }, radius: 15, portraitSprite: 'songJinwooSD', visual: { sprite: 'songJinwooSD', color: 0x6ff4dd, shape: 'diamond' },
  },
  kangTaehoon: {
    id: 'kangTaehoon', name: '강태훈', description: '초기 게이트 진압 작전을 거친 전직 특수임무요원. 공용 장비와 생존 전술에 능하다.',
    background: '게이트 사태 초기 군의 진압 작전에 참가해 기존 무기가 통하지 않는 괴물과 싸우다 각성했다. 여러 게이트 작전 후 전역했으며 현재 각성자 협회의 현장 작전에 참가한다. 초기 진압 중 공식 기록에 없는 사건을 직접 겪었다.',
    personality: '화려한 능력보다 침착한 상황 판단과 생존 능력을 믿는다. 환경과 장비를 빠르게 파악해 실용적인 해법을 고른다.',
    trait: { name: '특수임무 사격술', description: '총기 무기 피해 +15%', weaponDamageBonus: 0.15, weaponFamily: 'firearm' },
    baseStats: characterStatsFromBaseline([
      { stat: 'maxHp', operation: 'add', value: 10 },
      { stat: 'armor', operation: 'add', value: 5 },
      { stat: 'moveSpeed', operation: 'multiply', value: 0.95 },
    ]),
    radius: 15, portraitSprite: 'kangTaehoonSD',
    visual: { sprite: 'kangTaehoonSD', color: 0x8fa7ae, shape: 'diamond' },
  },
  parkDojun: {
    id:'parkDojun',name:'박도준',description:'49세 전직 지하철 구조반장. 무너진 현장에서도 안전한 길을 찾아내는 각성자.',
    background:'서울 지하철에서 25년 동안 시설과 구조 업무를 맡았다. 게이트 사고 때 마지막 승객을 구하던 중 각성했고, 이제 붕괴 현장의 동료들을 지킨다.',
    personality:'말수가 적고 단단하다. 남의 장비부터 챙겨 주며, 위험할수록 차분하게 다음 수를 고른다.',
    trait:{name:'구조반장의 버팀목',description:'모든 무기 피해 +8%',weaponDamageBonus:0.08},
    baseStats:characterStatsFromBaseline([{stat:'maxHp',operation:'add',value:20},{stat:'armor',operation:'add',value:8},{stat:'moveSpeed',operation:'multiply',value:0.9}]),
    radius:15,portraitSprite:'parkDojunSD',visual:{sprite:'parkDojunSD',color:0xdca550,shape:'diamond'},
  },
  leeSomin: {
    id: 'leeSomin', name: '이소민',
    description: '24세 신촌 편의점 야간 근무자. 작은 변화와 떨어진 마력석을 먼저 발견하는 수집형 각성자.',
    background: '시험 공부와 편의점 야간 근무를 병행했다. 새벽에 열린 게이트에서 손님을 대피시키던 중 각성했으며, 어둠 속에서 놓치기 쉬운 흔적을 찾는 감각이 남았다.',
    personality: '졸려 보여도 주변 변화는 먼저 알아챈다. 침착하게 상황을 살피고 필요한 일을 조용히 끝낸다.',
    trait: { name: '야간 근무의 눈썰미', description: '마력석 획득 범위 +25%, 행운 +10, 최대 HP -5', weaponDamageBonus: 0 },
    baseStats: characterStatsFromBaseline([
      { stat: 'pickupRange', operation: 'multiply', value: 1.25 },
      { stat: 'luck', operation: 'add', value: 10 },
      { stat: 'maxHp', operation: 'add', value: -5 },
    ]),
    radius: 15, portraitSprite: 'leeSominSD',
    visual: { sprite: 'leeSominSD', color: 0x9bcf55, shape: 'diamond' },
  },
  jungMinseok: {
    id: 'jungMinseok', name: '정민석',
    description: '35세 을지로 중소기업 경리 담당. 공격의 속도를 양보하고 한 판의 수입을 늘리는 경제형 각성자.',
    background: '월말 마감을 끝내고 퇴근하던 길에 게이트 사고를 만났다. 흩어진 동료와 물자를 빠짐없이 확인하다 각성했고, 이제 전장의 자원도 꼼꼼하게 챙긴다.',
    personality: '꼼꼼하지만 예상 밖 상황에도 건조한 농담을 한다. 당장 눈앞의 이득보다 끝까지 남길 몫을 계산한다.',
    trait: { name: '빈틈없는 정산', description: '마력석 획득량 +15%, 공격 속도 -8%', weaponDamageBonus: 0 },
    baseStats: characterStatsFromBaseline([
      { stat: 'currencyGain', operation: 'multiply', value: 1.15 },
      { stat: 'attackSpeed', operation: 'multiply', value: 0.92 },
    ]),
    radius: 15, portraitSprite: 'jungMinseokSD',
    visual: { sprite: 'jungMinseokSD', color: 0xc7b38a, shape: 'diamond' },
  },
  ohJieun: {
    id: 'ohJieun', name: '오지은',
    description: '38세 지하철 차량 정비 기사. 설치물의 출력을 높이고 거점을 지키는 정비형 각성자.',
    background: '첫차 전에 차량을 점검하던 중 차량기지에 게이트가 열렸다. 멈춘 설비를 되살려 동료의 탈출로를 확보하면서 각성했으며, 현장에서도 설치물의 작은 이상을 먼저 찾는다.',
    personality: '이상한 소리를 그냥 넘기지 않는 집중형이다. 손볼 곳을 정하면 서두르지 않고 정확하게 마무리한다.',
    trait: { name: '설비 최적화', description: '설치물 무기 피해 +20%, 방어력 +4, 이동 속도 -3%', weaponDamageBonus: 0.2, weaponCapability: 'STRUCTURE' },
    baseStats: characterStatsFromBaseline([
      { stat: 'armor', operation: 'add', value: 4 },
      { stat: 'moveSpeed', operation: 'multiply', value: 0.97 },
    ]),
    radius: 15, portraitSprite: 'ohJieunSD',
    visual: { sprite: 'ohJieunSD', color: 0x526b91, shape: 'diamond' },
  },
  moonTaeo: {
    id: 'moonTaeo', name: '문태오',
    description: '29세 성수 동네 제빵사. 빠른 손놀림으로 가까운 적을 연달아 상대하는 근접형 각성자.',
    background: '새벽부터 반죽을 준비하던 빵집에 게이트의 여파가 밀려왔다. 이웃을 가게 뒤편으로 대피시키며 위험을 막아내다 각성했고, 반복 작업으로 익힌 리듬을 근접 전투에 살린다.',
    personality: '손이 빠르고 실수를 숨기지 않는다. 할 수 있는 일부터 움직이며 결과가 어긋나면 곧바로 고친다.',
    trait: { name: '새벽 손놀림', description: '근접 피해 +12%, 공격 속도 +8%, 원거리 피해 -10%', weaponDamageBonus: 0 },
    baseStats: characterStatsFromBaseline([
      { stat: 'meleeDamage', operation: 'multiply', value: 1.12 },
      { stat: 'attackSpeed', operation: 'multiply', value: 1.08 },
      { stat: 'rangedDamage', operation: 'multiply', value: 0.9 },
    ]),
    radius: 15, portraitSprite: 'moonTaeoSD',
    visual: { sprite: 'moonTaeoSD', color: 0xcbb89b, shape: 'diamond' },
  },
  kimMigyeong: {
    id: 'kimMigyeong', name: '김미경',
    description: '54세 망원시장 반찬가게 운영자. 높은 체력과 꾸준한 회복으로 오래 버티는 생존형 각성자.',
    background: '단골의 식성과 사정을 기억하며 망원시장에서 반찬가게를 꾸렸다. 게이트 사고로 고립된 상인들을 먹이고 돌보다 각성했으며, 위기에서도 지치지 않고 사람을 챙긴다.',
    personality: '시원하게 말하지만 남의 곤란함을 먼저 챙긴다. 힘든 상황에서도 해야 할 일을 나눠 주고 주변을 든든하게 붙잡는다.',
    trait: { name: '든든한 한 끼', description: '최대 HP +15, 초당 HP 재생 +0.4, 이동 속도 -5%', weaponDamageBonus: 0 },
    baseStats: characterStatsFromBaseline([
      { stat: 'maxHp', operation: 'add', value: 15 },
      { stat: 'hpRegeneration', operation: 'add', value: 0.4 },
      { stat: 'moveSpeed', operation: 'multiply', value: 0.95 },
    ]),
    radius: 15, portraitSprite: 'kimMigyeongSD',
    visual: { sprite: 'kimMigyeongSD', color: 0xd8827b, shape: 'diamond' },
  },
  baeSeongho: {
    id: 'baeSeongho', name: '배성호',
    description: '47세 구로 주택가 택배 기사. 골목에서 익힌 동선으로 빠르게 이동하며 마력석을 회수하는 기동형 각성자.',
    background: '구로 주택가를 다니며 주민과 골목의 사정을 익혔다. 배송 중 게이트가 열리자 막히지 않은 길로 주민을 이끌며 각성했고, 지금도 필요한 곳에 제시간에 도착하려 한다.',
    personality: '낙천적이지만 시간 약속은 엄격하다. 익숙한 길이 막혀도 새 동선을 빠르게 찾고 사람을 안심시킨다.',
    trait: { name: '골목 배송 동선', description: '이동 속도 +8%, 마력석 획득 범위 +15%, 모든 피해 -5%', weaponDamageBonus: 0 },
    baseStats: characterStatsFromBaseline([
      { stat: 'moveSpeed', operation: 'multiply', value: 1.08 },
      { stat: 'pickupRange', operation: 'multiply', value: 1.15 },
      { stat: 'damage', operation: 'multiply', value: 0.95 },
    ]),
    radius: 15, portraitSprite: 'baeSeonghoSD',
    visual: { sprite: 'baeSeonghoSD', color: 0xb56350, shape: 'diamond' },
  },
  chaYujun: {
    id: 'chaYujun', name: '차유준',
    description: '22세 서울의 건축학과 대학생. 넓고 오래 남는 공격으로 공간을 확보하는 광역형 각성자.',
    background: '과제 때문에 학교 작업실에서 밤을 새우던 중 게이트 사고를 겪었다. 무너지는 건물의 구조를 읽고 동료의 탈출 경로를 찾으면서 각성했으며, 전장에서도 공간의 빈틈을 먼저 본다.',
    personality: '호기심이 많고 주변 구조를 유심히 본다. 집중하면 입을 다물고 여러 길을 머릿속에서 비교한다.',
    trait: { name: '공간 설계', description: '공격 범위 +12%, 지속시간 +15%, 공격 속도 -5%', weaponDamageBonus: 0 },
    baseStats: characterStatsFromBaseline([
      { stat: 'area', operation: 'multiply', value: 1.12 },
      { stat: 'duration', operation: 'multiply', value: 1.15 },
      { stat: 'attackSpeed', operation: 'multiply', value: 0.95 },
    ]),
    radius: 15, portraitSprite: 'chaYujunSD',
    visual: { sprite: 'chaYujunSD', color: 0xad98d0, shape: 'diamond' },
  },
  baekNari: {
    id: 'baekNari', name: '백나리',
    description: '31세 연남동 미용실 디자이너. 약점을 정확하게 노려 큰 한 방을 만드는 치명타형 각성자.',
    background: '손님에게 맞는 스타일을 단호하게 권하던 미용실 디자이너였다. 게이트 사고로 가게에 갇힌 손님을 구하다 각성했고, 작은 차이를 놓치지 않는 눈과 손끝을 전투에 쓴다.',
    personality: '자기 기준이 분명하고 말을 돌리지 않는다. 자신 있게 판단하되 상대에게 필요한 결과를 끝까지 책임진다.',
    trait: { name: '정밀한 손끝', description: '치명타 확률 +8%p, 치명타 피해 배율 1.5→1.7배, 최대 HP -8', weaponDamageBonus: 0 },
    baseStats: characterStatsFromBaseline([
      { stat: 'criticalChance', operation: 'add', value: 0.08 },
      { stat: 'criticalDamage', operation: 'add', value: 0.2 },
      { stat: 'maxHp', operation: 'add', value: -8 },
    ]),
    radius: 15, portraitSprite: 'baekNariSD',
    visual: { sprite: 'baekNariSD', color: 0xb795b2, shape: 'diamond' },
  },
  imGicheol: {
    id: 'imGicheol', name: '임기철',
    description: '58세 오래된 아파트 관리 기사. 느린 공격과 이동을 감수하며 위험을 버티는 방어형 각성자.',
    background: '주민이 말하지 않아도 고장난 곳을 찾아 손보던 아파트 관리 기사였다. 게이트 사고 때 무너지는 대피 통로를 지키며 각성했으며, 지금도 가장 오래 남아 현장을 살핀다.',
    personality: '느긋하지만 꼼꼼하다. 눈에 띄는 성과보다 다시 고장 나지 않도록 마무리하는 일을 중요하게 여긴다.',
    trait: { name: '튼튼한 현장 관리', description: '방어력 +16, 최대 HP +10, 공격 속도 -6%, 이동 속도 -4%', weaponDamageBonus: 0 },
    baseStats: characterStatsFromBaseline([
      { stat: 'armor', operation: 'add', value: 16 },
      { stat: 'maxHp', operation: 'add', value: 10 },
      { stat: 'attackSpeed', operation: 'multiply', value: 0.94 },
      { stat: 'moveSpeed', operation: 'multiply', value: 0.96 },
    ]),
    radius: 15, portraitSprite: 'imGicheolSD',
    visual: { sprite: 'imGicheolSD', color: 0x417c7d, shape: 'diamond' },
  },
  seoHyejin: {
    id: 'seoHyejin', name: '서혜진',
    description: '43세 종로 공공도서관 사서. 먼 적을 빠르게 맞히며 거리를 유지하는 원거리형 각성자.',
    background: '책보다 사람의 질문을 먼저 기억하는 공공도서관 사서였다. 게이트 사고 때 서가 사이에 흩어진 이용자를 찾아 대피시키다 각성했고, 멀리 있는 움직임을 차분하게 읽는다.',
    personality: '조용하고 인내심이 많지만 결정할 때는 단호하다. 오래 관찰한 뒤 필요한 순간에 정확한 답을 고른다.',
    trait: { name: '멀리 보는 관찰력', description: '사거리 +15%, 투사체 속도 +15%, 원거리 피해 +5%, 근접 피해 -10%', weaponDamageBonus: 0 },
    baseStats: characterStatsFromBaseline([
      { stat: 'range', operation: 'multiply', value: 1.15 },
      { stat: 'projectileSpeed', operation: 'multiply', value: 1.15 },
      { stat: 'rangedDamage', operation: 'multiply', value: 1.05 },
      { stat: 'meleeDamage', operation: 'multiply', value: 0.9 },
    ]),
    radius: 15, portraitSprite: 'seoHyejinSD',
    visual: { sprite: 'seoHyejinSD', color: 0x8f4057, shape: 'diamond' },
  },
};

