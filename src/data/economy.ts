import { GATE_CONFIG } from './gateProgression';
import { META_GROWTH_CONFIG } from './metaFacilities';
import { metaUpgrades, type MetaEffect } from './meta';
import type { StatKey } from './stats';

/** Godot economy. The preserved web edition retains its original meta data. */
export interface EconomyResource {
  key: string; name: string; image: string; target: 'run' | 'profile' | 'guild'; uses: readonly string[];
}
export const ECONOMY_RESOURCES: Record<string, EconomyResource> = {
  magicStone: { key: 'magicStone', name: '마력석', image: 'magicStone', target: 'run', uses: ['출동 상점 구매', '출동 상점 리롤'] },
  associationCoins: { key: 'associationCoins', name: '협회 코인', image: 'associationCoin', target: 'profile', uses: ['협회 능력치 강화', '전투 콘텐츠 해금', '축복 성장', '아이템 영구 강화', '캐릭터 옵션 추첨'] },
  supplyTickets: { key: 'supplyTickets', name: '보급권', image: 'supplyTicket', target: 'profile', uses: ['보급 상자 개봉'] },
  characterFragments: { key: 'characterFragments', name: '캐릭터 조각', image: 'lobbyAwakener', target: 'profile', uses: ['캐릭터 해금'] },
  weaponFragments: { key: 'weaponFragments', name: '무기 조각', image: 'lobbyWeapons', target: 'profile', uses: ['무기 해금'] },
  blessingFragments: { key: 'blessingFragments', name: '축복 조각', image: 'blessingBlade', target: 'profile', uses: ['축복 해금', '축복 성장'] },
  coins: { key: 'coins', name: '길드 코인', image: 'guildCoin', target: 'guild', uses: ['길드 운영', '남은 작업 시간 즉시 완료'] },
  materials: { key: 'materials', name: '마력자재', image: 'guildMaterials', target: 'guild', uses: ['시설 건설', '연구', '제조', '직원 교육'] },
  researchData: { key: 'researchData', name: '연구자료', image: 'guildResearchData', target: 'guild', uses: ['길드 연구', '상위 시설', '조합법 해금'] },
  speedupTickets: { key: 'speedupTickets', name: '가속권', image: 'guildSpeedupTicket', target: 'guild', uses: ['길드 작업 15분 단축'] },
  constructionParts: { key: 'constructionParts', name: '건축 부품', image: 'guildConstructionParts', target: 'guild', uses: ['건물 건설', '증축', '보관 연구', '탐험팀 확장'] },
  electronicParts: { key: 'electronicParts', name: '전자 부품', image: 'guildElectronicParts', target: 'guild', uses: ['제어 시설', '연구', '공방', '분석', '직원 교육'] },
  manaCatalysts: { key: 'manaCatalysts', name: '마력 촉매', image: 'guildManaCatalysts', target: 'guild', uses: ['마력생산', '정제', '생환석 제조', '조합법 해금'] },
  bioReagents: { key: 'bioReagents', name: '생체 시약', image: 'guildBioReagents', target: 'guild', uses: ['생환공방', '직원 교육', '각성분석실'] },
  revivalStoneLow: { key: 'revivalStoneLow', name: '조제 생환석', image: 'revivalStoneLow', target: 'profile', uses: ['출동 중 부활 · 최대 체력 30%'] },
  revivalStoneMid: { key: 'revivalStoneMid', name: '정제 생환석', image: 'revivalStoneMid', target: 'profile', uses: ['출동 중 부활 · 최대 체력 50%'] },
  revivalStoneHigh: { key: 'revivalStoneHigh', name: '순정 생환석', image: 'revivalStoneHigh', target: 'profile', uses: ['출동 중 부활 · 최대 체력 100%'] },
};

export interface EconomyUpgrade {
  id: string; name: string; description: string; maxLevel: number;
  baseCost: number; costStep: number; effect: MetaEffect; softCap?: number;
}
function statUpgrade(id: string, name: string, stat: StatKey, value: number, major = false, softCap?: number, operation: 'add' | 'multiply' = 'add'): EconomyUpgrade {
  return { id, name, description: '협회 코인으로 영구 강화합니다. 같은 능력치를 강화할수록 비용이 고정량씩 증가합니다.',
    maxLevel: 0, baseCost: major ? 30 : 20, costStep: major ? 6 : 4,
    effect: { type: 'stat', stat, operation, value }, ...(softCap === undefined ? {} : { softCap }) };
}
function unlock(id: 'circuit' | 'reroll'): EconomyUpgrade {
  const existing = metaUpgrades[id]!;
  return { id, name: existing.name, description: existing.description, maxLevel: 1,
    baseCost: existing.baseCost, costStep: 0, effect: existing.effect };
}
export const ECONOMY_UPGRADES: Record<string, EconomyUpgrade> = {
  vitality: statUpgrade('vitality', '기초 체력', 'maxHp', 3),
  armor: statUpgrade('armor', '방어 단련', 'armor', 2.5),
  hpRegeneration: statUpgrade('hpRegeneration', '재생 훈련', 'hpRegeneration', 0.08),
  power: statUpgrade('power', '마력 단련', 'damage', 0.03, true),
  meleeDamage: statUpgrade('meleeDamage', '근접 숙련', 'meleeDamage', 0.035),
  rangedDamage: statUpgrade('rangedDamage', '원거리 숙련', 'rangedDamage', 0.035),
  attackSpeed: statUpgrade('attackSpeed', '공격 속도 훈련', 'attackSpeed', 0.03, true, 3),
  criticalChance: statUpgrade('criticalChance', '치명타 훈련', 'criticalChance', 0.012, true, 0.65),
  criticalDamage: statUpgrade('criticalDamage', '급소 타격', 'criticalDamage', 0.08),
  dodge: statUpgrade('dodge', '회피 훈련', 'dodge', 0.03, true, 0.5),
  lifesteal: statUpgrade('lifesteal', '생명 회수', 'lifesteal', 0.003, true, 0.12),
  range: statUpgrade('range', '사거리 훈련', 'range', 0.03, false, 1.5),
  area: statUpgrade('area', '마력 확장', 'area', 0.025, false, 1.5),
  duration: statUpgrade('duration', '마력 지속', 'duration', 0.04, false, 2),
  projectileSpeed: statUpgrade('projectileSpeed', '투사체 가속', 'projectileSpeed', 0.05, false, 2),
  mobility: statUpgrade('mobility', '가벼운 발걸음', 'moveSpeed', 0.015, true, 0.5, 'multiply'),
  currencyGain: statUpgrade('currencyGain', '마력석 회수 훈련', 'currencyGain', 0.03, true, 1.5),
  pickupRange: statUpgrade('pickupRange', '획득 반경 확장', 'pickupRange', 5, false, 200),
  fortune: statUpgrade('fortune', '행운 훈련', 'luck', 2, false, 100),
  // 자동 포탑은 협회 허가 대신 무기 조각으로 해금한다.
  circuit: unlock('circuit'), reroll: unlock('reroll'),
};

export const ECONOMY_GROWTH = { ...META_GROWTH_CONFIG, coinCosts: [50, 100, 175, 275, 400] } as const;
/** Every run pays per completed wave; clears add a depth bonus and first clears keep the one-time reward. */
export const ECONOMY_GATE = { ...GATE_CONFIG, firstClearReward: 100, rewardPerDepth: 10,
  repeatRewardFraction: 0.2, deathRewardFraction: 0.05,
  runCoinsPerWave: 3, clearCoinBase: 30, clearCoinPerDepth: 4, firstClearTickets: 1,
  runMaterialsPerWave: 1, runMaterialsDepthStep: 5, clearPartsBase: 2, clearPartsDepthStep: 5 } as const;
/** Highest cleared depth raises guild-side rewards (회수 guild resources, expeditions). */
export const ECONOMY_REGION = { bonusPerDepth: 0.05, maxBonus: 1 } as const;
export const ECONOMY_OFFLINE = {
  capHours: 12, coinIntervalMinutes: 30,
  // supplyTickets 0.125 per 30 minutes = 1 ticket per 4 hours. Fixed keys ignore yield and depth bonuses.
  baseRewards: { associationCoins: 2, supplyTickets: 0.125, coins: 6, materials: 4, researchData: 1,
    constructionParts: 3, electronicParts: 2, manaCatalysts: 1, bioReagents: 1 },
  fixedRewardKeys: ['associationCoins', 'supplyTickets'] as readonly string[],
} as const;

/** Daily gift: resets at 05:00 KST. One random target's fragments, plus a 7-day streak bonus. */
export const ECONOMY_DAILY = {
  resetUtcHour: 20, fragmentAmounts: { character: 8, weapon: 10, blessing: 8 },
  kindWeights: { character: 1, weapon: 1, blessing: 1 },
  associationCoins: 30, guildCoins: 100,
  streakDays: 7, streakRewards: { supplyTickets: 3, revivalStoneLow: 1 },
} as const;

export interface EconomySupplyEntry {
  type: 'associationCoin' | 'guildResource' | 'supplyTicket' | 'characterFragment' | 'weaponFragment' | 'blessingFragment' | 'revivalStone';
  contentId?: string; weight: number; amounts: readonly number[];
}
export const ECONOMY_SUPPLY = {
  id: 'standard', ticketCost: 1, pityLimit: 10,
  // Every box spills 3-5 rewards.
  kindCounts: [{ amount: 3, weight: 60 }, { amount: 4, weight: 30 }, { amount: 5, weight: 10 }],
  amountWeights: [70, 25, 5],
  entries: [
    { type: 'associationCoin', weight: 14, amounts: [10, 20, 40] },
    { type: 'guildResource', contentId: 'coins', weight: 12, amounts: [20, 40, 80] },
    { type: 'guildResource', contentId: 'materials', weight: 10, amounts: [10, 20, 40] },
    { type: 'guildResource', contentId: 'researchData', weight: 5, amounts: [3, 6, 12] },
    { type: 'guildResource', contentId: 'constructionParts', weight: 4, amounts: [4, 8, 16] },
    { type: 'guildResource', contentId: 'electronicParts', weight: 4, amounts: [3, 6, 12] },
    { type: 'guildResource', contentId: 'manaCatalysts', weight: 4, amounts: [2, 4, 8] },
    { type: 'guildResource', contentId: 'bioReagents', weight: 4, amounts: [2, 4, 8] },
    { type: 'guildResource', contentId: 'speedupTickets', weight: 4, amounts: [1, 2, 3] },
    { type: 'supplyTicket', weight: 1.5, amounts: [1] },
    { type: 'characterFragment', weight: 10, amounts: [3, 6, 12] },
    { type: 'weaponFragment', weight: 12, amounts: [3, 6, 12] },
    { type: 'blessingFragment', weight: 10, amounts: [3, 6, 12] },
    { type: 'revivalStone', contentId: 'low', weight: 3, amounts: [1] },
    { type: 'revivalStone', contentId: 'mid', weight: 1, amounts: [1] },
    { type: 'revivalStone', contentId: 'high', weight: 0.2, amounts: [1] },
  ] as readonly EconomySupplyEntry[],
} as const;
