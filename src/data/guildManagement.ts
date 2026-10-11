import type { ImageId } from './images';
import type { StatKey } from './stats';

export const GUILD_NAME = '길드 본부';
export const guildOperator = {
  id: 'hanSeoa', name: '한서아', role: '길드 오퍼레이터',
  description: '현장 통신과 길드 본부 운영을 맡는다.',
  illustration: 'guildOperatorIllustration' as ImageId, sprite: 'guildOperatorTopdown' as ImageId,
} as const;

export const GUILD_FACILITY_IDS = ['office', 'research', 'expedition', 'production', 'recovery', 'workshop', 'revival', 'analysis'] as const;
export type GuildFacilityId = typeof GUILD_FACILITY_IDS[number];
export const GUILD_RESOURCE_KEYS = ['coins', 'materials', 'researchData', 'speedupTickets', 'constructionParts', 'electronicParts', 'manaCatalysts', 'bioReagents'] as const;
export type GuildResourceKey = typeof GUILD_RESOURCE_KEYS[number];
export type GuildResourceAmounts = Record<GuildResourceKey, number>;
export type GuildCost = Partial<GuildResourceAmounts> & { associationCoins?: number };
export interface GuildLevelDefinition { cost: GuildCost; durationMs: number }
export interface GuildFacility {
  id: GuildFacilityId; name: string; description: string; effect: string; icon: string;
  unlockOfficeLevel: number; maxLevel: number; levels: readonly GuildLevelDefinition[];
}

const constructionMinutes = [1, 5, 15, 60, 180, 360, 720, 1440, 2880, 4320] as const;
export const guildSpecialtyCosts: Record<GuildFacilityId, GuildCost> = {
  office: { constructionParts: 4, electronicParts: 1 }, research: { electronicParts: 4, manaCatalysts: 1 },
  expedition: { constructionParts: 3, electronicParts: 2 }, production: { constructionParts: 2, manaCatalysts: 2 },
  recovery: { constructionParts: 4, electronicParts: 2 }, workshop: { constructionParts: 3, electronicParts: 2, manaCatalysts: 2 },
  revival: { manaCatalysts: 2, bioReagents: 3 }, analysis: { electronicParts: 3, bioReagents: 4 },
};
function specialtyCost(facility: GuildFacilityId, level: number, research = false): GuildCost {
  const multiplier = level * (level + 1) / 2;
  return Object.fromEntries(Object.entries(guildSpecialtyCosts[facility]).map(([key, amount]) =>
    [key, (research ? Math.ceil(amount / 2) : amount) * multiplier]));
}
function facilityLevels(facility: GuildFacilityId, coins: number, materials: number, data: number, lowLevelDataThrough = 2): GuildLevelDefinition[] {
  return constructionMinutes.map((minutes, index) => ({ durationMs: minutes * 60_000,
    cost: { coins: Math.ceil(coins * Math.pow(1.75, index)), materials: Math.ceil(materials * Math.pow(1.6, index)),
      researchData: index < lowLevelDataThrough ? data : Math.ceil((data + 2) * Math.pow(1.45, index - 1)),
      ...specialtyCost(facility, index + 1) } }));
}
export const guildFacilities: Record<GuildFacilityId, GuildFacility> = {
  office: { id: 'office', name: '길드 운영실', description: '작은 사무소를 서울의 길드 사옥으로 키웁니다.',
    effect: 'Lv.2 2층 · Lv.3 3층 증축 · Lv.4 건설 2개 동시 진행 · 직원 정원 확대', icon: '🏢', unlockOfficeLevel: 1, maxLevel: 10, levels: facilityLevels('office', 45, 20, 0, 3) },
  research: { id: 'research', name: '연구실', description: '직원을 배치하고 새 업무와 지원 기술을 연구합니다.',
    effect: '연구 단축 · 길드 기술 5단계 성장', icon: '🔬', unlockOfficeLevel: 1, maxLevel: 10, levels: facilityLevels('research', 40, 15, 0) },
  expedition: { id: 'expedition', name: '탐험본부', description: '서울의 게이트 주변으로 직원을 파견합니다.',
    effect: '전문 재료·자재·연구자료·가속권·희귀 설계도 발견', icon: '🧭', unlockOfficeLevel: 1, maxLevel: 10, levels: facilityLevels('expedition', 50, 20, 0) },
  production: { id: 'production', name: '마력생산실', description: '마력을 정제해 운영 자금과 지정한 조각을 생산합니다.',
    effect: '추가 길드 코인 생산 · Lv.1 캐릭터 / Lv.3 무기 / Lv.5 축복 조각', icon: '⚙', unlockOfficeLevel: 1, maxLevel: 10, levels: facilityLevels('production', 50, 20, 0) },
  recovery: { id: 'recovery', name: '회수센터', description: '미접속 중 회수반의 보상과 보관 시간을 개선합니다.',
    effect: '회수 8종 보상 증가 · 연구로 최대 72시간 누적', icon: '📦', unlockOfficeLevel: 2, maxLevel: 10, levels: facilityLevels('recovery', 80, 35, 2) },
  workshop: { id: 'workshop', name: '장비공방', description: '편의점 상품을 개선하고 조합 설계도를 분석합니다.',
    effect: '협회 코인으로 아이템 영구 강화 · 상품 등장 제외 · 조합법 해금', icon: '🛠', unlockOfficeLevel: 3, maxLevel: 10, levels: facilityLevels('workshop', 120, 50, 5) },
  revival: { id: 'revival', name: '생환공방', description: '생명을 지키는 생환석을 제조하고 정제합니다.',
    effect: '생환석 제조 보장 · 등급 확률·재료 효율 연구 · 합성', icon: '💎', unlockOfficeLevel: 5, maxLevel: 10, levels: facilityLevels('revival', 180, 80, 10) },
  analysis: { id: 'analysis', name: '각성분석실', description: '각성자의 고유 잠재력을 분석해 추가 능력치를 부여합니다.',
    effect: '협회 코인으로 캐릭터별 능력치 한 줄 추첨 · 기존 또는 신규 선택', icon: '✨', unlockOfficeLevel: 7, maxLevel: 10, levels: facilityLevels('analysis', 250, 100, 15) },
};

export const GUILD_RESEARCH_IDS = ['offlineYield', 'offlineCapacity', 'expeditionRarity', 'expeditionTeams', 'expeditionParty',
  'productionEfficiency', 'stoneEfficiency', 'stonePurity', 'stoneSynthesis', 'shopExclusions', 'firstClearBonus'] as const;
export type GuildResearchId = typeof GUILD_RESEARCH_IDS[number];
export interface GuildResearchDefinition {
  id: GuildResearchId; name: string; description: string; facility: GuildFacilityId;
  unlockFacilityLevel: number; maxLevel: number; levels: readonly GuildLevelDefinition[];
}
function researchLevels(facility: GuildFacilityId): GuildLevelDefinition[] {
  return [5, 30, 120, 480, 1440].map((minutes, index) => ({ durationMs: minutes * 60_000,
    cost: { coins: Math.ceil(30 * Math.pow(2, index)), materials: Math.ceil(10 * Math.pow(1.7, index)),
      researchData: Math.ceil(5 * Math.pow(1.8, index)), ...specialtyCost(facility, index + 1, true) } }));
}
function research(id: GuildResearchId, name: string, description: string, facility: GuildFacilityId, unlockFacilityLevel = 1): GuildResearchDefinition {
  return { id, name, description, facility, unlockFacilityLevel, maxLevel: 5, levels: researchLevels(facility) };
}
export const guildResearch: Record<GuildResearchId, GuildResearchDefinition> = {
  offlineYield: research('offlineYield', '현장 회수 효율', '회수 8종 보상을 단계마다 10% 늘립니다.', 'recovery'),
  offlineCapacity: research('offlineCapacity', '장기 보관', '누적 상한을 12/18/24/36/48/72시간으로 늘립니다.', 'recovery'),
  expeditionRarity: research('expeditionRarity', '희귀 신호 분석', '탐험 희귀 발견 확률을 단계마다 4%p 높입니다.', 'expedition'),
  expeditionTeams: research('expeditionTeams', '탐험팀 확장', 'Lv.2에서 2팀, Lv.5에서 3팀을 동시 파견합니다.', 'expedition'),
  expeditionParty: research('expeditionParty', '협동 탐사', 'Lv.2에서 팀당 2명, Lv.5에서 3명을 배치합니다.', 'expedition'),
  productionEfficiency: research('productionEfficiency', '마력 정제', '길드 코인과 조각 생산량을 단계마다 10% 늘립니다.', 'production'),
  stoneEfficiency: research('stoneEfficiency', '제조 재료 최적화', '생환석 제조 재료를 단계마다 8% 줄입니다.', 'revival'),
  stonePurity: research('stonePurity', '결정 순도', '제조 중급·상급 생환석 발견 확률을 높입니다.', 'revival'),
  stoneSynthesis: research('stoneSynthesis', '생환석 합성', '같은 등급 생환석 3개를 한 단계 높은 생환석으로 합성합니다.', 'revival'),
  shopExclusions: research('shopExclusions', '선별 납품', '연구에 따라 최대 무기 2종·아이템 4종의 신규 등장을 제외합니다.', 'workshop'),
  firstClearBonus: research('firstClearBonus', '심도 성과 정산', '새 심도 첫 클리어의 협회 코인 보상을 단계마다 10% 늘립니다.', 'research'),
};

export interface GuildEmployeeDefinition { id: string; name: string; role: string; specialty: GuildFacilityId; description: string; hireCost: GuildCost }
const employeeRows: readonly [string, string, string, GuildFacilityId][] = [
  ['staffSeoYeon', '이서연', '마력 기술자', 'production'], ['staffMinJae', '김민재', '탐험 조사원', 'expedition'],
  ['staffJiWoo', '박지우', '연구원', 'research'], ['staffDoYoon', '최도윤', '회수 기사', 'recovery'],
  ['staffHaEun', '정하은', '공방 기술자', 'workshop'], ['staffSiWoo', '강시우', '사무 관리자', 'office'],
  ['staffSuBin', '윤수빈', '결정 정제사', 'revival'], ['staffJunSeo', '장준서', '각성 분석가', 'analysis'],
  ['staffYeRin', '임예린', '마력 기술자', 'production'], ['staffTaeMin', '한태민', '탐험 조사원', 'expedition'],
  ['staffSoYoon', '오소윤', '연구원', 'research'], ['staffHyunWoo', '서현우', '회수 기사', 'recovery'],
  ['staffDaIn', '신다인', '공방 기술자', 'workshop'], ['staffJaeHyun', '송재현', '사무 관리자', 'office'],
  ['staffYuNa', '권유나', '결정 정제사', 'revival'], ['staffSeongMin', '황성민', '각성 분석가', 'analysis'],
  ['staffChaeWon', '안채원', '마력 기술자', 'production'], ['staffGeonWoo', '문건우', '탐험 조사원', 'expedition'],
  ['staffNaYeon', '홍나연', '연구원', 'research'], ['staffSeJun', '백세준', '공방 기술자', 'workshop'],
];
export const guildEmployees: Record<string, GuildEmployeeDefinition> = Object.fromEntries(employeeRows.map(([id, name, role, specialty], index) =>
  [id, { id, name, role, specialty, description: guildFacilities[specialty].name + ' 업무 효율 +10%',
    hireCost: { coins: 80 + index * 15, materials: 15 + Math.floor(index / 4) * 5, researchData: 0 } }]));

export interface GuildExpeditionDefinition {
  id: string; name: string; description: string; durationMs: number; cost: GuildCost;
  baseRewards: GuildResourceAmounts; rareBlueprintIds: readonly string[]; rareChance: number;
  /** Highest cleared gate depth needed to send this expedition. */
  minDepth: number; supplyTicketChance: number;
  /** Guaranteed fragments for one random character, weapon or blessing. */
  fragmentAmount: number;
}
export const guildExpeditions: Record<string, GuildExpeditionDefinition> = {
  cityScout: { id: 'cityScout', name: '서울 골목 순찰', description: '짧은 조사로 마력자재와 연구 단서를 모읍니다.',
    durationMs: 30 * 60_000, cost: { coins: 10, materials: 0, researchData: 0 },
    baseRewards: { coins: 0, materials: 15, researchData: 3, speedupTickets: 1, constructionParts: 6, electronicParts: 3, manaCatalysts: 1, bioReagents: 1 }, rareBlueprintIds: ['recipeAttack', 'recipeSurvival', 'recipeRecovery'], rareChance: 0.1, minDepth: 0, supplyTicketChance: 0.1, fragmentAmount: 2 },
  gateSurvey: { id: 'gateSurvey', name: '게이트 잔향 조사', description: '통제 구역에서 자재와 오래된 설계도를 찾습니다.',
    durationMs: 2 * 60 * 60_000, cost: { coins: 25, materials: 0, researchData: 0 },
    baseRewards: { coins: 0, materials: 60, researchData: 15, speedupTickets: 2, constructionParts: 20, electronicParts: 16, manaCatalysts: 7, bioReagents: 5 }, rareBlueprintIds: ['recipeAttack', 'recipeSurvival', 'recipeRecovery'], rareChance: 0.2, minDepth: 5, supplyTicketChance: 0.3, fragmentAmount: 5 },
  deepSurvey: { id: 'deepSurvey', name: '심층 게이트 탐사', description: '긴 탐사로 연구자료와 희귀 설계도를 확보합니다.',
    durationMs: 8 * 60 * 60_000, cost: { coins: 60, materials: 0, researchData: 0 },
    baseRewards: { coins: 0, materials: 180, researchData: 50, speedupTickets: 5, constructionParts: 64, electronicParts: 48, manaCatalysts: 20, bioReagents: 18 }, rareBlueprintIds: ['recipeAttack', 'recipeSurvival', 'recipeRecovery'], rareChance: 0.35, minDepth: 10, supplyTicketChance: 1, fragmentAmount: 12 },
};
export interface GuildRecipeDefinition {
  id: string; name: string; description: string; ingredients: Record<string, number>; resultItemId: string;
  blueprintId: string; cost: GuildCost; durationMs: number;
}
export const guildRecipes: Record<string, GuildRecipeDefinition> = {
  recipeAttack: { id: 'recipeAttack', name: '조율 마력핵 조합', description: '마력 렌즈와 에너지 드링크를 조율 마력핵으로 조합합니다.',
    ingredients: { lens: 1, energyDrink: 1 }, resultItemId: 'tunedCore', blueprintId: 'recipeAttack', cost: { coins: 100, materials: 40, researchData: 10, electronicParts: 2, manaCatalysts: 4 }, durationMs: 30 * 60_000 },
  recipeSurvival: { id: 'recipeSurvival', name: '헌터 방호 코트 조합', description: '삼각김밥과 방탄 조끼를 헌터 방호 코트로 조합합니다.',
    ingredients: { riceBall: 1, vest: 1 }, resultItemId: 'hunterCoat', blueprintId: 'recipeSurvival', cost: { coins: 100, materials: 40, researchData: 10, electronicParts: 2, manaCatalysts: 4 }, durationMs: 30 * 60_000 },
  recipeRecovery: { id: 'recipeRecovery', name: '자력 회수기 조합', description: '튼튼한 지갑과 휴대용 자석을 자력 회수기로 조합합니다.',
    ingredients: { wallet: 1, magnet: 1 }, resultItemId: 'magneticCollector', blueprintId: 'recipeRecovery', cost: { coins: 100, materials: 40, researchData: 10, electronicParts: 2, manaCatalysts: 4 }, durationMs: 30 * 60_000 },
};

export interface GuildAffixDefinition { stat: StatKey; name: string; operation: 'add' | 'multiply'; min: number; max: number }
export const guildAffixPool: readonly GuildAffixDefinition[] = [
  { stat: 'damage', name: '피해량', operation: 'add', min: 0.01, max: 0.04 },
  { stat: 'attackSpeed', name: '공격 속도', operation: 'add', min: 0.01, max: 0.04 },
  { stat: 'meleeDamage', name: '근접 피해량', operation: 'add', min: 0.02, max: 0.06 },
  { stat: 'rangedDamage', name: '원거리 피해량', operation: 'add', min: 0.02, max: 0.06 },
  { stat: 'criticalChance', name: '치명타 확률', operation: 'add', min: 0.005, max: 0.02 },
  { stat: 'criticalDamage', name: '치명타 피해량', operation: 'add', min: 0.03, max: 0.1 },
  { stat: 'range', name: '사거리', operation: 'add', min: 0.01, max: 0.05 },
  { stat: 'area', name: '공격 범위', operation: 'add', min: 0.01, max: 0.05 },
  { stat: 'duration', name: '지속시간', operation: 'add', min: 0.01, max: 0.05 },
  { stat: 'projectileSpeed', name: '투사체 속도', operation: 'add', min: 0.02, max: 0.06 },
  { stat: 'maxHp', name: '최대 체력', operation: 'add', min: 2, max: 10 },
  { stat: 'armor', name: '방어력', operation: 'add', min: 1, max: 4 },
  { stat: 'dodge', name: '회피 확률', operation: 'add', min: 0.005, max: 0.02 },
  { stat: 'lifesteal', name: '흡혈', operation: 'add', min: 0.002, max: 0.008 },
  { stat: 'hpRegeneration', name: '체력 회복', operation: 'add', min: 0.02, max: 0.12 },
  { stat: 'moveSpeed', name: '이동속도', operation: 'add', min: 2, max: 6 },
  { stat: 'currencyGain', name: '마력석 획득량', operation: 'add', min: 0.01, max: 0.04 },
  { stat: 'pickupRange', name: '획득 범위', operation: 'add', min: 3, max: 15 },
  { stat: 'luck', name: '행운', operation: 'add', min: 1, max: 4 },
];

export const guildBalance = {
  facilityWorkBonusPerLevel: 0.03, expeditionRewardPerFacilityLevel: 0.05,
  baselineCoinsPerHour: 0, productionCoinsPerLevelHour: 24, productionFragmentsPerHour: 1,
  productionFragmentUnlockLevels: { character: 1, weapon: 3, blessing: 5 },
  staffExperiencePerHour: 10, staffLevelExperience: [20, 40, 80, 160] as readonly number[], staffLevelBonus: 0.04, staffSpecialtyBonus: 0.1,
  educationDurationMs: 2 * 60 * 60_000, educationCost: { coins: 60, materials: 20, researchData: 5, electronicParts: 1, bioReagents: 2 },
  itemUpgradeLevels: [1, 5, 15, 60, 180].map((minutes, index): GuildLevelDefinition => ({ durationMs: minutes * 60_000,
    cost: { associationCoins: 80 * (index + 1) } })),
  manufactureDurationMs: 30 * 60_000, manufactureCost: { coins: 100, materials: 60, researchData: 5, manaCatalysts: 2, bioReagents: 3 },
  synthesisCost: { coins: 50, materials: 30, researchData: 0, manaCatalysts: 1, bioReagents: 2 }, synthesisStoneCount: 3,
  affixCost: { associationCoins: 250 }, speedupTicketMs: 15 * 60_000, speedupCoinsPerMinute: 1,
  staffCapacityBase: 2, staffCapacityPerOfficeLevel: 2, maxStaffLevel: 5, maxItemLevel: 5,
  roomsPerFloor: 3, floorUnlockOfficeLevels: [1, 2, 3] as readonly number[], parallelConstructionOfficeLevel: 4,
  /** Highest cleared gate depth needed to upgrade the office to index+1 (index 0 = Lv.1, always open). */
  officeDepthByLevel: [0, 1, 3, 4, 6, 8, 10, 13, 16, 20] as readonly number[],
  offlineHoursBase: 12, offlineHoursMax: 72,
} as const;

/** Permanent support curves shared by management and combat, indexed by research level. */
export const guildBenefitBalance = {
  expeditionRarityPerFacilityLevel: 0.01, recoveryYieldPerFacilityLevel: 0.02,
  offlineYieldPerLevel: 0.1, offlineCapHours: [12, 18, 24, 36, 48, 72], expeditionRarityPerLevel: 0.04,
  expeditionTeamsByLevel: [1, 1, 2, 2, 2, 3], expeditionPartyByLevel: [1, 1, 2, 2, 2, 3],
  productionPerLevel: 0.1, stoneEfficiencyPerLevel: 0.08, stoneMidBase: 0.14, stoneMidPerLevel: 0.036,
  stoneHighBase: 0.01, stoneHighPerLevel: 0.014, weaponExclusionsByLevel: [0, 1, 1, 1, 2, 2],
  itemExclusionsByLevel: [0, 1, 2, 3, 4, 4], firstClearPerLevel: 0.1, itemStrengthPerLevel: 0.05,
  characterHpPerLevel: 0.03, weaponDamagePerLevel: 0.04, runMaterialsPerWaves: 2, runTicketsPerWaves: 5,
} as const;

/** Godot management content; legacy web guild stays preserved in guild.ts. */
export const GUILD_MANAGEMENT_DATA = { facilities: guildFacilities, research: guildResearch, employees: guildEmployees, expeditions: guildExpeditions, recipes: guildRecipes, affixPool: guildAffixPool, balance: guildBalance, benefits: guildBenefitBalance, resourceKeys: GUILD_RESOURCE_KEYS,
  initialWallet: { coins: 200, materials: 100, researchData: 20, speedupTickets: 0, constructionParts: 12, electronicParts: 8, manaCatalysts: 4, bioReagents: 2 },
  initialEmployees: ['staffSeoYeon', 'staffMinJae'] };
