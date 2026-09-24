import { expect, it } from 'vitest';
import { parseSave } from './migrations';
import { createDefaultMeta } from '../state/MetaState';

it('migrates v8 through v12 meta state and removes permanent magic stones',()=>{
  const legacy={currency:999,deferredMagicStone:44,associationCoins:345,upgrades:{vitality:2},
    unlockedCharacters:['awakener'],unlockedWeapons:['manaBolt','autoTurret'],unlockedItems:['bloodCircuit'],unlockedStages:['seoul'],unlockedFeatures:['reroll'],
    gateProgression:{highestUnlockedDepth:7,characters:{}},weeklyGate:{weekKey:'',traitId:'',blessingCandidateIds:[],selectedBlessingId:'',remainingTraitIds:[]},
    stats:{runs:8,clears:2,totalKills:90,bestWave:7,bestTime:300,totalMetaEarned:999},settings:{masterVolume:.8,soundVolume:.8,combatVolume:.7,uiVolume:.7,musicVolume:.5,muted:true,highResolution:true,developerMode:false}};
  const save=parseSave(JSON.stringify({saveVersion:8,meta:legacy}));
  expect(save.saveVersion).toBe(12); expect(save.meta.wallet.associationCoins).toBe(345);
  expect(save.meta.wallet.revivalStones).toEqual({low:0,mid:0,high:0});
  expect(save.meta.association.upgrades.vitality).toBe(2); expect(save.meta.sharedWeapons.autoTurret?.unlocked).toBe(true);
  expect(save.meta.account.unlockedItemIds).toContain('bloodCircuit'); expect(save.meta.gateProgression.highestUnlockedDepth).toBe(7);
  expect(save.meta.statistics.runs).toBe(8); expect(save.meta).not.toHaveProperty('currency'); expect(save.meta).not.toHaveProperty('deferredMagicStone');
});

it('migrates v10 weekly selection and blessing progress into v11',()=>{
  const meta=createDefaultMeta() as unknown as Record<string,unknown>;
  meta.weeklyGate={weekKey:'2026-09-20',traitId:'hardened',blessingCandidateIds:['blade','tempo','mountain'],selectedBlessingId:'blade',remainingTraitIds:['violent']};
  meta.blessings={blade:{unlocked:true,fragments:9,level:2}};
  const save=parseSave(JSON.stringify({saveVersion:10,meta}));
  expect(save.meta.weeklyGate).toMatchObject({ruleId:'hardened',remainingRuleIds:['violent']});
  expect(save.meta.blessings.cheonbuOath).toMatchObject({unlocked:true,fragments:9,level:2});
});

it('preserves existing v11 currency while adding revival inventory',()=>{
  const meta=createDefaultMeta();meta.wallet.associationCoins=42;meta.wallet.supplyTickets=3;
  const old={...meta,wallet:{associationCoins:42,supplyTickets:3},offlineReward:{...meta.offlineReward,pendingRewards:{associationCoins:7,supplyTickets:0,characterFragments:{},weaponFragments:{},blessingFragments:{}}}};
  const save=parseSave(JSON.stringify({saveVersion:11,meta:old}));
  expect(save.meta.wallet).toMatchObject({associationCoins:42,supplyTickets:3,revivalStones:{low:0,mid:0,high:0}});
  expect(save.meta.offlineReward.pendingRewards).toMatchObject({associationCoins:7,revivalStones:{low:0,mid:0,high:0}});
});

it('validates revival inventory and pending rewards from current saves',()=>{
  const meta=createDefaultMeta();
  const raw={...meta,wallet:{...meta.wallet,revivalStones:{low:2,mid:-7,high:'bad'}},offlineReward:{...meta.offlineReward,pendingRewards:{...meta.offlineReward.pendingRewards,revivalStones:{low:1.9,mid:3,high:-4}}}};
  const save=parseSave(JSON.stringify({saveVersion:12,meta:raw}));
  expect(save.meta.wallet.revivalStones).toEqual({low:2,mid:0,high:0});
  expect(save.meta.offlineReward.pendingRewards.revivalStones).toEqual({low:1,mid:3,high:0});
});
