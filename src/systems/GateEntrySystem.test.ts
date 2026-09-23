import { expect, it } from 'vitest';
import { createDefaultMeta } from '../state/MetaState';
import { createGateEntryDraft, validateGateEntry } from './GateEntrySystem';

it('builds and validates the six-step gate entry draft',()=>{
  const meta=createDefaultMeta(); meta.blessings.cheonbuOath={unlocked:true,fragments:0,level:1};
  const draft=createGateEntryDraft(meta); draft.startingWeaponId='manaBolt';
  expect(draft).toMatchObject({mapId:'seoul',gateDepth:1,characterId:'awakener',blessingId:'cheonbuOath'});
  expect(validateGateEntry(meta,draft)).toBeNull();
  draft.gateDepth=2; expect(validateGateEntry(meta,draft)).toContain('심도');
});

it('keeps gate depth account-wide instead of nesting it under maps',()=>{
  const meta=createDefaultMeta(); meta.gateProgression.highestUnlockedDepth=12;
  const draft=createGateEntryDraft(meta); expect(draft.gateDepth).toBe(12);
  expect(meta.gateProgression).not.toHaveProperty('maps');
});
