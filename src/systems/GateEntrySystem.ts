import { characters } from '../data/characters';
import { maps } from '../data/maps';
import { dangunBlessings } from '../data/weeklyGate';
import { weapons } from '../data/weapons';
import { isCharacterUnlocked, isMapUnlocked, isWeaponUnlocked, type MetaState } from '../state/MetaState';

export interface GateEntryDraft {
  mapId: string; gateDepth: number; depthPage: number; characterId: string; startingWeaponId: string; blessingId: string;
}
export type GateEntryStep = 'gateMap' | 'gateDepth' | 'gateCharacter' | 'gateWeapon' | 'gateBlessing' | 'gateConfirm';
export const gateEntrySteps: readonly GateEntryStep[] = ['gateMap','gateDepth','gateCharacter','gateWeapon','gateBlessing','gateConfirm'];

export function createGateEntryDraft(meta: MetaState): GateEntryDraft {
  const mapId = meta.account.unlockedMapIds.find(id => maps[id]) ?? Object.keys(maps)[0] ?? '';
  const characterId = Object.keys(meta.characters).find(id => isCharacterUnlocked(meta, id) && characters[id]) ?? '';
  const blessingId=Object.keys(dangunBlessings).find(id=>meta.blessings[id]?.unlocked&&meta.blessings[id]!.level>0)??'';
  const gateDepth=Math.max(1,meta.gateProgression.highestUnlockedDepth);
  return { mapId,gateDepth,depthPage:Math.floor((gateDepth-1)/10),characterId,startingWeaponId:'',blessingId };
}

export function availableStartingWeapons(meta: MetaState, characterId: string) {
  return Object.values(weapons).filter(weapon => !weapon.structure
    && (!weapon.signatureOwnerId || weapon.signatureOwnerId === characterId)
    && (!weapon.requiresUnlock || isWeaponUnlocked(meta, weapon.id)));
}

export function validateGateEntry(meta: MetaState, draft: GateEntryDraft): string | null {
  if (!maps[draft.mapId] || !isMapUnlocked(meta, draft.mapId)) return '입장할 맵을 선택하세요.';
  if (!Number.isInteger(draft.gateDepth) || draft.gateDepth < 1 || draft.gateDepth > meta.gateProgression.highestUnlockedDepth) return '입장 가능한 게이트 심도를 선택하세요.';
  if (!characters[draft.characterId] || !isCharacterUnlocked(meta, draft.characterId)) return '출동할 각성자를 선택하세요.';
  if (!availableStartingWeapons(meta, draft.characterId).some(weapon => weapon.id === draft.startingWeaponId)) return '시작 무기를 선택하세요.';
  const unlockedBlessings=Object.keys(dangunBlessings).filter(id=>meta.blessings[id]?.unlocked&&meta.blessings[id]!.level>0);
  if(unlockedBlessings.length&&!unlockedBlessings.includes(draft.blessingId))return '보유한 단군의 축복을 선택하세요.';
  if(!unlockedBlessings.length&&draft.blessingId)return '해금되지 않은 단군의 축복입니다.';
  return null;
}
