import type { StatKey } from './stats';
import type { ImageId } from './images';

export interface WeeklyPenaltyEffect {
  enemyHp?: number; enemyDamage?: number; enemySpeed?: number; spawn?: number; eliteChance?: number;
}
export interface StatEffect { stat: StatKey; operation: 'add' | 'multiply'; value: number }
/** One automatically applied weekly rule. Its risk and benefit are inseparable. */
export interface WeeklyGateRule {
  id: string; name: string; description: string; icon: string; image: ImageId;
  palette: { accent: string; glow: string; surface: string };
  penaltyLabel: string; benefitLabel: string; penalty: WeeklyPenaltyEffect; benefit: StatEffect[];
}
/** Fragment-owned blessing selected before deployment. Values are per progression level. */
export interface DangunBlessing {
  id: string; name: string; description: string; icon: string; image: ImageId;
  category: 'attack' | 'defense' | 'speed' | 'critical' | 'structure' | 'recovery' | 'risk';
  modifiers: StatEffect[];
  structureLimitAtLevel?: number;
}

export const weeklyGateRules: Record<string, WeeklyGateRule> = {
  hardened: { id:'hardened',name:'경화된 침식',description:'단단해진 개체를 상대하는 대신 공격 감응이 증폭됩니다.',icon:'⬢',image:'weeklyHardened',palette:{accent:'#d7a85f',glow:'#6f91a5',surface:'#18232b'},penaltyLabel:'적 최대 체력 +20%',benefitLabel:'모든 피해 +12%',penalty:{enemyHp:1.2},benefit:[{stat:'damage',operation:'multiply',value:1.12}] },
  violent: { id:'violent',name:'난폭한 파동',description:'적의 충격이 거세지는 만큼 방호 마력이 응집됩니다.',icon:'◆',image:'weeklyViolent',palette:{accent:'#dc8d83',glow:'#77b7c4',surface:'#251d22'},penaltyLabel:'적 공격력 +18%',benefitLabel:'방어력 +12',penalty:{enemyDamage:1.18},benefit:[{stat:'armor',operation:'add',value:12}] },
  crowded: { id:'crowded',name:'과밀 균열',description:'더 많은 침식체가 쏟아지지만 회수장이 넓어집니다.',icon:'▦',image:'weeklyCrowded',palette:{accent:'#b99b55',glow:'#62b8ae',surface:'#20231b'},penaltyLabel:'적 생성 밀도 +25%',benefitLabel:'획득 범위 +30%',penalty:{spawn:1.25},benefit:[{stat:'pickupRange',operation:'multiply',value:1.3}] },
  pursuit: { id:'pursuit',name:'추격 본능',description:'추격 개체가 빨라지는 대신 각성자의 기동력이 상승합니다.',icon:'»',image:'weeklyPursuit',palette:{accent:'#78c0d0',glow:'#b07a50',surface:'#15232c'},penaltyLabel:'적 이동 속도 +8%',benefitLabel:'이동 속도 +8%',penalty:{enemySpeed:1.08},benefit:[{stat:'moveSpeed',operation:'multiply',value:1.08}] },
  elite: { id:'elite',name:'정예 공명',description:'정예 개체가 자주 나타나며 전장의 행운도 함께 요동칩니다.',icon:'♜',image:'weeklyElite',palette:{accent:'#c7a45a',glow:'#8e76c5',surface:'#201d2d'},penaltyLabel:'엘리트 확률 +8%p',benefitLabel:'행운 +18',penalty:{eliteChance:0.08},benefit:[{stat:'luck',operation:'add',value:18}] },
  attrition: { id:'attrition',name:'소모의 장막',description:'침식체가 질겨지는 동안 각성자의 생명력이 확장됩니다.',icon:'▲',image:'weeklyAttrition',palette:{accent:'#82966f',glow:'#6fae8f',surface:'#1c2420'},penaltyLabel:'적 체력 +12% · 공격력 +8%',benefitLabel:'최대 체력 +15%',penalty:{enemyHp:1.12,enemyDamage:1.08},benefit:[{stat:'maxHp',operation:'multiply',value:1.15}] },
  surge: { id:'surge',name:'범람하는 맥동',description:'균열의 유입이 빨라지는 만큼 공격 흐름도 가속됩니다.',icon:'⌁',image:'weeklySurge',palette:{accent:'#78b9d7',glow:'#706fc5',surface:'#161d31'},penaltyLabel:'생성 밀도 +15% · 이동 속도 +4%',benefitLabel:'공격 속도 +10%',penalty:{spawn:1.15,enemySpeed:1.04},benefit:[{stat:'attackSpeed',operation:'multiply',value:1.1}] },
};

export const dangunBlessings: Record<string, DangunBlessing> = {
  cheonbuOath:{id:'cheonbuOath',name:'천부인의 맹세',description:'세 인장의 마력이 모든 공격을 증폭합니다.',icon:'✦',image:'blessingCheonbuOath',category:'attack',modifiers:[{stat:'damage',operation:'multiply',value:1.04}]},
  unyieldingJangseung:{id:'unyieldingJangseung',name:'불굴의 장승',description:'수호의 결계가 생명력과 방어를 단단히 세웁니다.',icon:'⬟',image:'blessingUnyieldingJangseung',category:'defense',modifiers:[{stat:'maxHp',operation:'multiply',value:1.04},{stat:'armor',operation:'add',value:2}]},
  samjogoWing:{id:'samjogoWing',name:'삼족오의 날개',description:'태양의 깃이 이동과 공격의 흐름을 가볍게 만듭니다.',icon:'≋',image:'blessingSamjogoWing',category:'speed',modifiers:[{stat:'moveSpeed',operation:'multiply',value:1.025},{stat:'attackSpeed',operation:'multiply',value:1.02}]},
  whiteTigerEye:{id:'whiteTigerEye',name:'백호의 눈',description:'흔들림 없는 시선이 치명적인 빈틈을 포착합니다.',icon:'◉',image:'blessingWhiteTigerEye',category:'critical',modifiers:[{stat:'criticalChance',operation:'add',value:.025},{stat:'criticalDamage',operation:'add',value:.08}]},
  goblinForge:{id:'goblinForge',name:'도깨비 대장간',description:'도깨비불이 설치 무기의 출력과 설치 한도를 끌어올립니다.',icon:'♜',image:'blessingGoblinForge',category:'structure',modifiers:[{stat:'duration',operation:'multiply',value:1.04}],structureLimitAtLevel:3},
  harvestKnot:{id:'harvestKnot',name:'풍요의 매듭',description:'전장의 마력석이 더 넓고 풍성하게 모입니다.',icon:'∞',image:'blessingHarvestKnot',category:'recovery',modifiers:[{stat:'currencyGain',operation:'multiply',value:1.035},{stat:'pickupRange',operation:'multiply',value:1.06}]},
  reverseScale:{id:'reverseScale',name:'역린의 계약',description:'저주를 받아들이고 그 위험만큼 공격력을 얻습니다.',icon:'◇',image:'blessingReverseScale',category:'risk',modifiers:[{stat:'curse',operation:'add',value:2},{stat:'damage',operation:'multiply',value:1.04}]},
};

export const OLD_BLESSING_ID_MAP: Record<string, keyof typeof dangunBlessings> = {
  blade:'cheonbuOath',mountain:'unyieldingJangseung',wind:'samjogoWing',fortune:'whiteTigerEye',
  armor:'goblinForge',harvest:'harvestKnot',tempo:'reverseScale',
};
