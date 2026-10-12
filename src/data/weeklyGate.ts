import type { StatKey, WeaponCapability } from './stats';
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
  weaponDamageBonus?: number;
  weaponCapability?: WeaponCapability;
  structureLimitAtLevel?: number;
}

export const weeklyGateRules: Record<string, WeeklyGateRule> = {
  hardened: { id:'hardened',name:'경화된 침식',description:'단단해진 개체를 상대하는 대신 공격 감응이 증폭됩니다.',icon:'⬢',image:'weeklyHardened',palette:{accent:'#d7a85f',glow:'#6f91a5',surface:'#18232b'},penaltyLabel:'적 최대 체력 +16%',benefitLabel:'모든 피해 +8%',penalty:{enemyHp:1.16},benefit:[{stat:'damage',operation:'multiply',value:1.08}] },
  violent: { id:'violent',name:'난폭한 파동',description:'적의 충격이 거세지는 만큼 방호 마력이 응집됩니다.',icon:'◆',image:'weeklyViolent',palette:{accent:'#dc8d83',glow:'#77b7c4',surface:'#251d22'},penaltyLabel:'적 공격력 +12%',benefitLabel:'방어력 +6',penalty:{enemyDamage:1.12},benefit:[{stat:'armor',operation:'add',value:6}] },
  crowded: { id:'crowded',name:'과밀 균열',description:'더 많은 침식체가 쏟아지지만 회수장이 넓어집니다.',icon:'▦',image:'weeklyCrowded',palette:{accent:'#b99b55',glow:'#62b8ae',surface:'#20231b'},penaltyLabel:'적 생성 밀도 +10%',benefitLabel:'획득 범위 +20%',penalty:{spawn:1.1},benefit:[{stat:'pickupRange',operation:'multiply',value:1.2}] },
  pursuit: { id:'pursuit',name:'추격 본능',description:'빠르고 강해진 추격 개체에 맞서 각성자의 기동력이 상승합니다.',icon:'»',image:'weeklyPursuit',palette:{accent:'#78c0d0',glow:'#b07a50',surface:'#15232c'},penaltyLabel:'적 이동 속도 +6% · 공격력 +4%',benefitLabel:'이동 속도 +4%',penalty:{enemySpeed:1.06,enemyDamage:1.04},benefit:[{stat:'moveSpeed',operation:'multiply',value:1.04}] },
  elite: { id:'elite',name:'정예 공명',description:'질겨진 개체와 잦은 정예 출현에 전장의 행운도 함께 요동칩니다.',icon:'♜',image:'weeklyElite',palette:{accent:'#c7a45a',glow:'#8e76c5',surface:'#201d2d'},penaltyLabel:'적 체력 +4% · 엘리트 확률 +4%p',benefitLabel:'행운 +10',penalty:{enemyHp:1.04,eliteChance:0.04},benefit:[{stat:'luck',operation:'add',value:10}] },
  attrition: { id:'attrition',name:'소모의 장막',description:'침식체가 질겨지는 동안 각성자의 생명력이 확장됩니다.',icon:'▲',image:'weeklyAttrition',palette:{accent:'#82966f',glow:'#6fae8f',surface:'#1c2420'},penaltyLabel:'적 체력 +10% · 공격력 +6%',benefitLabel:'최대 체력 +10%',penalty:{enemyHp:1.1,enemyDamage:1.06},benefit:[{stat:'maxHp',operation:'multiply',value:1.1}] },
  surge: { id:'surge',name:'범람하는 맥동',description:'균열의 유입이 빨라지는 만큼 공격 흐름도 가속됩니다.',icon:'⌁',image:'weeklySurge',palette:{accent:'#78b9d7',glow:'#706fc5',surface:'#161d31'},penaltyLabel:'생성 밀도 +10% · 이동 속도 +3%',benefitLabel:'공격 속도 +5%',penalty:{spawn:1.1,enemySpeed:1.03},benefit:[{stat:'attackSpeed',operation:'multiply',value:1.05}] },
};

export const dangunBlessings: Record<string, DangunBlessing> = {
  cheonbuOath:{id:'cheonbuOath',name:'천부인의 맹세',description:'세 인장의 마력으로 모든 피해 +8%.',icon:'✦',image:'blessingCheonbuOath',category:'attack',modifiers:[{stat:'damage',operation:'multiply',value:1.08}]},
  unyieldingJangseung:{id:'unyieldingJangseung',name:'불굴의 장승',description:'수호의 결계로 최대 HP +8%, 방어력 +4.',icon:'⬟',image:'blessingUnyieldingJangseung',category:'defense',modifiers:[{stat:'maxHp',operation:'multiply',value:1.08},{stat:'armor',operation:'add',value:4}]},
  samjogoWing:{id:'samjogoWing',name:'삼족오의 날개',description:'태양의 깃으로 이동 속도 +5%, 공격 속도 +6%.',icon:'≋',image:'blessingSamjogoWing',category:'speed',modifiers:[{stat:'moveSpeed',operation:'multiply',value:1.05},{stat:'attackSpeed',operation:'multiply',value:1.06}]},
  whiteTigerEye:{id:'whiteTigerEye',name:'백호의 눈',description:'흔들림 없는 시선으로 치명타 확률 +6%p, 치명타 피해 배율 +0.20.',icon:'◉',image:'blessingWhiteTigerEye',category:'critical',modifiers:[{stat:'criticalChance',operation:'add',value:.06},{stat:'criticalDamage',operation:'add',value:.2}]},
  goblinForge:{id:'goblinForge',name:'도깨비 대장간',description:'도깨비불로 설치물 무기 피해 +15%.',icon:'♜',image:'blessingGoblinForge',category:'structure',modifiers:[],weaponDamageBonus:.15,weaponCapability:'STRUCTURE'},
  harvestKnot:{id:'harvestKnot',name:'풍요의 매듭',description:'풍요의 매듭으로 마력석 획득량 +8%, 획득 범위 +15%.',icon:'∞',image:'blessingHarvestKnot',category:'recovery',modifiers:[{stat:'currencyGain',operation:'multiply',value:1.08},{stat:'pickupRange',operation:'multiply',value:1.15}]},
  reverseScale:{id:'reverseScale',name:'역린의 계약',description:'저주 +6을 받아들이는 대신 모든 피해 +20%.',icon:'◇',image:'blessingReverseScale',category:'risk',modifiers:[{stat:'curse',operation:'add',value:6},{stat:'damage',operation:'multiply',value:1.2}]},
};

export const OLD_BLESSING_ID_MAP: Record<string, keyof typeof dangunBlessings> = {
  blade:'cheonbuOath',mountain:'unyieldingJangseung',wind:'samjogoWing',fortune:'whiteTigerEye',
  armor:'goblinForge',harvest:'harvestKnot',tempo:'reverseScale',
};
