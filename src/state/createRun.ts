import { calculateStats } from '../stats/PlayerStats';
import { weapons } from '../data/weapons';
import { characters } from '../data/characters';
import { maps } from '../data/maps';
import { getMetaModifiers } from '../meta/progression';
import { isItemUnlocked, isWeaponUnlocked, type MetaState } from './MetaState';
import type { RunState } from './RunState';
import { blessingModifiers, weeklyBenefitModifiers } from '../systems/WeeklyGateSystem';
import { gateDifficulty } from '../data/gateProgression';
import { dangunBlessings, weeklyGateRules } from '../data/weeklyGate';

export function createRun(characterId: string, mapId: string, meta: MetaState, gateDepth = 1, weeklyTraitId = '', blessingId = '', startingWeaponId?: string): RunState {
  const character = Object.hasOwn(characters, characterId) ? characters[characterId] : undefined;
  const stage = Object.hasOwn(maps, mapId) ? maps[mapId] : undefined;
  if (!character || !stage) throw new Error('알 수 없는 캐릭터 또는 스테이지입니다.');
  const fallbackWeaponId = character.signatureWeaponId ?? 'manaBolt';
  const selectedWeaponId = startingWeaponId ?? fallbackWeaponId;
  const selectedWeapon = weapons[selectedWeaponId];
  const unlocked = !!selectedWeapon && (!selectedWeapon.requiresUnlock || isWeaponUnlocked(meta, selectedWeapon.id));
  const ownedSignature = !!selectedWeapon?.signatureOwnerId && selectedWeapon.signatureOwnerId === character.id;
  if (!selectedWeapon || selectedWeapon.structure || (!ownedSignature && selectedWeapon.signatureOwnerId) || !unlocked) throw new Error('시작 무기 선택을 확인하세요.');
  const baseStats = { ...character.baseStats };
  const blessingLevel=meta.blessings[blessingId]?.unlocked?meta.blessings[blessingId]!.level:0;
  const statModifiers = [...getMetaModifiers(meta),...weeklyBenefitModifiers(weeklyTraitId),...blessingModifiers(blessingId,blessingLevel)];
  const calculatedStats = calculateStats(baseStats, statModifiers);
  const maxHp = calculatedStats.maxHp;
  const progress = meta.gateProgression.characters[characterId] ?? { highestClearedDepth: 0, rewardedThroughDepth: 0, bestWaveByDepth: {} };
  const difficulty = gateDifficulty(gateDepth);
  const stageBalance = stage.balanceModifiers;
  difficulty.hp *= stageBalance?.enemyHp ?? 1;
  difficulty.damage *= stageBalance?.enemyDamage ?? 1;
  difficulty.speed *= stageBalance?.enemySpeed ?? 1;
  difficulty.spawn *= stageBalance?.spawnDensity ?? 1;
  difficulty.reward *= stageBalance?.rewards ?? 1;
  const weekly = weeklyGateRules[weeklyTraitId]?.penalty;
  difficulty.hp *= weekly?.enemyHp ?? 1; difficulty.damage *= weekly?.enemyDamage ?? 1;
  difficulty.speed *= weekly?.enemySpeed ?? 1; difficulty.spawn *= weekly?.spawn ?? 1;
  difficulty.eliteChance = Math.min(0.75, difficulty.eliteChance + (weekly?.eliteChance ?? 0));
  return {
    phase: 'preparing', characterId, mapId,
    gateDepth, weeklyTraitId, blessingId,
    characterHighestClearedDepth: progress.highestClearedDepth,
    characterRewardedThroughDepth: progress.rewardedThroughDepth,
    enemyDifficulty: difficulty,
    player: { x: 0, y: 0, hp: maxHp, maxHp, radius: character.radius,
      moveSpeed: calculatedStats.moveSpeed,
      pickupRadius: calculatedStats.pickupRange,
      invulnerability: 0, visual: character.visual },
    currentWave: 1, totalWaves: stage.totalWaves, waveElapsedTime: 0, waveRemainingTime: stage.waveDefinitions[0]!.duration, stageCombatTime: 0, waveStartKills: 0,
    curseExposure:0, kills: 0, earnedMetaCurrency: 0, earnedAssociationCoins: 0,
    startingWeaponId: selectedWeaponId,
    ownedWeapons: [{ id: selectedWeaponId, level: 1, cooldownRemaining: 0 }],
    baseStats, statModifiers, calculatedStats, combatPermissions: { indirectLifesteal: false },
    shop: {wave:0,itemStock:{rerolls:0,slots:[]},weaponStock:{rerolls:0,slots:[]}}, unlockedItemIds:Object.keys(itemsForMeta(meta)), itemEffects:[], structures: [],
    structureEffects: dangunBlessings[blessingId]?.structureLimitAtLevel&&blessingLevel>=dangunBlessings[blessingId]!.structureLimitAtLevel!
      ? [{sourceId:`blessing:${blessingId}`,tag:'STRUCTURE',type:'maxCount',value:1}] : [],
    runCurrency: 0, startingCurrency: 0, collectedMagicStone: 0,
    walletBonusRemaining: 0, walletStoredThisRun: 0,
    runItems: [], effects: [],
    availableWeaponIds: Object.values(weapons).filter(w => (!w.signatureOwnerId || w.signatureOwnerId === characterId) && (!w.requiresUnlock || isWeaponUnlocked(meta, w.id) || w.id === selectedWeaponId)).map(w => w.id),
    hostileProjectiles: [], hazards: [], enemies: [], projectiles: [], pickups: [], bossSpawned: false,
    waveId: stage.waveDefinitions[0]?.id ?? '', invincible: false,
  };
}

function itemsForMeta(meta: MetaState): Record<string, true> {
  return Object.fromEntries(meta.account.unlockedItemIds.filter(id => isItemUnlocked(meta, id)).map(id => [id, true]));
}

