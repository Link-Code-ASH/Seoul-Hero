import { describe, expect, it } from 'vitest';
import { createDefaultMeta } from '../state/MetaState';
import { growthCost, upgradeGrowth } from './GrowthSystem';
import { accrueOfflineRewards, claimOfflineRewards } from './OfflineRewardSystem';
import { openSupplyBox } from './SupplySystem';
import { parseSave } from '../save/migrations';
import { supplyScreen } from '../ui/MetaScreens';

describe('meta facilities',()=>{
  it('spends fragments for stored growth without changing combat stats',()=>{const meta=createDefaultMeta();meta.characters.awakener!.fragments=20;expect(growthCost(meta,'character','awakener')).toBe(20);expect(upgradeGrowth(meta,'character','awakener')).toBe(true);expect(meta.characters.awakener).toMatchObject({fragments:0,breakthrough:1});});
  it('stores blessing growth in the same five-step facility structure',()=>{const meta=createDefaultMeta();meta.blessings.cheonbuOath={unlocked:false,fragments:18,level:0};expect(growthCost(meta,'blessing','cheonbuOath')).toBe(18);expect(upgradeGrowth(meta,'blessing','cheonbuOath')).toBe(true);expect(meta.blessings.cheonbuOath).toMatchObject({unlocked:true,fragments:0,level:1});});
  it('caps offline coins at twelve hours and claims once',()=>{const meta=createDefaultMeta();meta.offlineReward.lastExitAt='2026-01-01T00:00:00.000Z';expect(accrueOfflineRewards(meta,new Date('2026-01-02T00:00:00.000Z'),()=>1)).toBe(true);expect(meta.offlineReward.pendingRewards.associationCoins).toBe(24);expect(claimOfflineRewards(meta,new Date('2026-01-02T00:00:01.000Z'))).toBe(true);expect(meta.wallet.associationCoins).toBe(24);expect(claimOfflineRewards(meta)).toBe(false);});
  it('charges tickets and forces a fragment on the tenth non-fragment roll',()=>{const meta=createDefaultMeta();meta.wallet.supplyTickets=10;const rewards=openSupplyBox(meta,10,()=>0);expect(rewards).toHaveLength(10);expect(rewards![9]!.type.endsWith('Fragment')).toBe(true);expect(meta.wallet.supplyTickets).toBe(0);expect(meta.supply.boxes.standard?.opened).toBe(10);});
  it('renders image-led timed VFX and reward art without a close instruction',()=>{const html=supplyScreen(createDefaultMeta(),[{type:'associationCoins',amount:20}]);expect(html).toContain('supply-stage');expect(html).toContain('crate-closed');expect(html).toContain('crate-wide');expect(html).toContain('crate-transition-flash');expect(html).toContain('supply-burst-image');expect(html).toContain('supply-result-backplate');expect(html).toContain('supply-reward-art');expect(html).toContain('협회 코인');expect(html).not.toContain('눌러서 닫기');expect(html).not.toContain('supply-platform-image');});
  it('migrates v9 offline rewards into the structured v11 state',()=>{const meta=createDefaultMeta();const legacy={...meta,offlineReward:{lastExitAt:'',lastClaimedAt:'',pendingRewards:{associationCoins:3}}};const save=parseSave(JSON.stringify({saveVersion:9,meta:legacy}));expect(save.saveVersion).toBe(11);expect(save.meta.offlineReward.pendingRewards).toMatchObject({associationCoins:3,supplyTickets:0});});
});
