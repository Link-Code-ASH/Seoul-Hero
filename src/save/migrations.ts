import { SAVE_VERSION } from './SaveData';
import type { SaveData } from './SaveData';
import { isRecord, validateMeta } from './validation';

export class FutureSaveVersionError extends Error {
  constructor() {
    super('현재 게임보다 새로운 버전의 저장입니다. 원본을 보호하기 위해 자동 저장을 중지했습니다.');
    this.name = 'FutureSaveVersionError';
  }
}

type Migration = (save: Record<string, unknown>) => Record<string, unknown>;

/** Historical steps stay intact; add the next numbered step when SAVE_VERSION changes. */
const migrations: Record<number, Migration> = {
  0: (save) => {
    const meta = isRecord(save.meta) ? save.meta : {};
    return { ...save, saveVersion: 1, meta: { ...meta, currency: meta.currency ?? meta.coins ?? 0 } };
  },
  1: (save) => {
    const meta = isRecord(save.meta) ? save.meta : {};
    const settings = isRecord(meta.settings) ? meta.settings : {};
    return { ...save, saveVersion: 2, meta: { ...meta, settings: { ...settings, muted: false } } };
  },
  3: (save) => {
    const meta=isRecord(save.meta)?save.meta:{};
    const stats=isRecord(meta.stats)?meta.stats:{};
    return {...save,saveVersion:4,meta:{...meta,unlockedWeapons:[...(Array.isArray(meta.unlockedWeapons)?meta.unlockedWeapons:[]),'autoTurret'],stats:{...stats,bestWave:0,totalMetaEarned:0}}};
  },
  4: (save) => {
    const meta = isRecord(save.meta) ? save.meta : {};
    return { ...save, saveVersion: 5, meta: { ...meta, deferredMagicStone: 0 } };
  },
  5: (save) => {
    const meta = isRecord(save.meta) ? save.meta : {};
    const settings = isRecord(meta.settings) ? meta.settings : {};
    const previous = typeof settings.soundVolume === 'number' ? settings.soundVolume : 0.8;
    return { ...save, saveVersion: 6, meta: { ...meta, settings: { ...settings, combatVolume: previous, uiVolume: previous } } };
  },
  6: (save) => {
    const meta = isRecord(save.meta) ? save.meta : {};
    return { ...save, saveVersion: 7, meta: { ...meta,
      gateProgression: { highestUnlockedDepth: 1, characters: {} },
      weeklyGate: { weekKey: '', traitId: '', blessingCandidateIds: [], selectedBlessingId: '', remainingTraitIds: [] },
    } };
  },
  7: (save) => {
    const meta = isRecord(save.meta) ? save.meta : {};
    return { ...save, saveVersion: 8, meta: { ...meta, associationCoins: 0 } };
  },
  8: (save) => {
    const meta = isRecord(save.meta) ? save.meta : {};
    const legacyStats = isRecord(meta.stats) ? meta.stats : {};
    const unlockedCharacters = Array.isArray(meta.unlockedCharacters) ? meta.unlockedCharacters.filter(id => typeof id === 'string') : ['awakener'];
    const unlockedWeapons = Array.isArray(meta.unlockedWeapons) ? meta.unlockedWeapons.filter(id => typeof id === 'string') : ['manaBolt'];
    const characters = Object.fromEntries(unlockedCharacters.map(id => [id, { unlocked: true, fragments: 0, breakthrough: 0 }]));
    const sharedWeapons = Object.fromEntries(unlockedWeapons.map(id => [id, { unlocked: true, fragments: 0, level: 0 }]));
    return { ...save, saveVersion: 9, meta: {
      account: {
        unlockedMapIds: Array.isArray(meta.unlockedStages) ? meta.unlockedStages : ['seoul'],
        unlockedItemIds: Array.isArray(meta.unlockedItems) ? meta.unlockedItems : [],
        unlockedFeatureIds: Array.isArray(meta.unlockedFeatures) ? meta.unlockedFeatures : [],
      },
      wallet: { associationCoins: meta.associationCoins ?? 0, supplyTickets: 0 },
      association: { upgrades: isRecord(meta.upgrades) ? meta.upgrades : {} },
      gateProgression: isRecord(meta.gateProgression) ? meta.gateProgression : { highestUnlockedDepth: 1, characters: {} },
      characters, sharedWeapons, blessings: {},
      weeklyGate: isRecord(meta.weeklyGate) ? meta.weeklyGate : { weekKey: '', traitId: '', blessingCandidateIds: [], selectedBlessingId: '', remainingTraitIds: [] },
      supply: { boxes: {} }, offlineReward: { lastExitAt: '', lastClaimedAt: '', pendingRewards: {} },
      statistics: { runs: legacyStats.runs ?? 0, clears: legacyStats.clears ?? 0, kills: legacyStats.totalKills ?? 0,
        bestWave: legacyStats.bestWave ?? 0, bestTime: legacyStats.bestTime ?? 0, byCharacter: {}, byMap: {} },
      settings: isRecord(meta.settings) ? meta.settings : {},
    } };
  },
  9: (save) => {
    const meta=isRecord(save.meta)?save.meta:{};
    const offline=isRecord(meta.offlineReward)?meta.offlineReward:{};
    const legacy=isRecord(offline.pendingRewards)?offline.pendingRewards:{};
    return {...save,saveVersion:10,meta:{...meta,offlineReward:{...offline,pendingRewards:{
      associationCoins:typeof legacy.associationCoins==='number'?legacy.associationCoins:0,
      supplyTickets:typeof legacy.supplyTickets==='number'?legacy.supplyTickets:0,
      characterFragments:isRecord(legacy.characterFragments)?legacy.characterFragments:{},
      weaponFragments:isRecord(legacy.weaponFragments)?legacy.weaponFragments:{},
      blessingFragments:isRecord(legacy.blessingFragments)?legacy.blessingFragments:{},
    }}}};
  },
  10: (save) => {
    const meta=isRecord(save.meta)?save.meta:{};
    const weekly=isRecord(meta.weeklyGate)?meta.weeklyGate:{};
    const idMap:Record<string,string>={blade:'cheonbuOath',mountain:'unyieldingJangseung',wind:'samjogoWing',fortune:'whiteTigerEye',armor:'goblinForge',harvest:'harvestKnot',tempo:'reverseScale'};
    const remapRecords=(value:unknown):Record<string,unknown>=>{
      if(!isRecord(value))return {};
      const result:Record<string,unknown>={};
      for(const [id,record] of Object.entries(value))result[idMap[id]??id]=record;
      return result;
    };
    const offline=isRecord(meta.offlineReward)?meta.offlineReward:{};
    const pending=isRecord(offline.pendingRewards)?offline.pendingRewards:{};
    return {...save,saveVersion:11,meta:{...meta,
      blessings:remapRecords(meta.blessings),
      weeklyGate:{
        weekKey:typeof weekly.weekKey==='string'?weekly.weekKey:'',
        ruleId:typeof weekly.traitId==='string'?weekly.traitId:'',
        remainingRuleIds:Array.isArray(weekly.remainingTraitIds)?weekly.remainingTraitIds:[],
      },
      offlineReward:{...offline,pendingRewards:{...pending,blessingFragments:remapRecords(pending.blessingFragments)}},
    }};
  },
  11: (save) => {
    const meta=isRecord(save.meta)?save.meta:{};
    const wallet=isRecord(meta.wallet)?meta.wallet:{};
    const offline=isRecord(meta.offlineReward)?meta.offlineReward:{};
    const pending=isRecord(offline.pendingRewards)?offline.pendingRewards:{};
    return {...save,saveVersion:12,meta:{...meta,
      wallet:{...wallet,revivalStones:{low:0,mid:0,high:0}},
      offlineReward:{...offline,pendingRewards:{...pending,revivalStones:{low:0,mid:0,high:0}}},
    }};
  },
  2: (save) => {
    const meta = isRecord(save.meta) ? save.meta : {};
    return { ...save, saveVersion: 3, meta: { ...meta, unlockedItems: meta.unlockedItems ?? [], unlockedStages: meta.unlockedStages ?? ['seoul'] } };
  },
};

export function parseSave(json: string): SaveData {
  const parsed: unknown = JSON.parse(json);
  if (!isRecord(parsed)) throw new Error('저장 파일의 형식이 올바르지 않습니다.');
  if (typeof parsed.saveVersion !== 'number' || !Number.isInteger(parsed.saveVersion) || parsed.saveVersion < 0) {
    throw new Error('저장 버전을 확인할 수 없습니다.');
  }
  if (parsed.saveVersion > SAVE_VERSION) throw new FutureSaveVersionError();
  if (!isRecord(parsed.meta)) throw new Error('저장 진행 데이터의 형식이 올바르지 않습니다.');
  let current = parsed;
  let version = parsed.saveVersion;
  while (version < SAVE_VERSION) {
    const migrate = migrations[version];
    if (!migrate) throw new Error(`저장 버전 ${version}의 이관 방법이 없습니다.`);
    current = migrate(current);
    if (current.saveVersion !== version + 1) throw new Error('저장 버전 이관에 실패했습니다.');
    version += 1;
  }
  return {
    saveVersion: SAVE_VERSION,
    savedAt: typeof current.savedAt === 'string' && Number.isFinite(Date.parse(current.savedAt))
      ? current.savedAt : new Date().toISOString(),
    meta: validateMeta(current.meta),
  };
}
