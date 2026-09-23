import {describe,expect,it} from 'vitest';
import {Simulation} from '../core/Simulation';
import {createDefaultMeta} from '../state/MetaState';
import {buyWeapon,weaponPrice} from './ShopSystem';
import {shopScreen} from '../ui/ShopScreen';

const shop=()=>{const sim=new Simulation('awakener','seoul',createDefaultMeta(),()=>0.2);sim.completeWave();sim.continuePostWave();sim.state.runCurrency=500;return sim;};

describe('paid weapon branch progression',()=>{
 it('opens A/B immediately after the paid Lv.5 upgrade and does not charge twice',()=>{const sim=shop(),run=sim.state,weapon=run.ownedWeapons[0]!;weapon.level=4;run.shop.weaponStock.slots[0]={weaponId:weapon.id,targetLevel:5,locked:false};const before=run.runCurrency,cost=weaponPrice({weaponId:weapon.id,targetLevel:5});expect(buyWeapon(run,0)).toBe(true);expect(run.runCurrency).toBe(before-cost);expect(run.pendingBranchWeaponId).toBe(weapon.id);expect(sim.chooseBranch('A')).toBe(true);expect(run.runCurrency).toBe(before-cost);expect(weapon.branchId).toBe('A');});
 it('cannot change an already selected branch',()=>{const sim=shop(),run=sim.state,weapon=run.ownedWeapons[0]!;weapon.level=5;run.pendingBranchWeaponId=weapon.id;expect(sim.chooseBranch('B')).toBe(true);run.pendingBranchWeaponId=weapon.id;expect(sim.chooseBranch('A')).toBe(false);expect(weapon.branchId).toBe('B');});
 it('removes the branch overlay as soon as the choice succeeds',()=>{const sim=shop(),run=sim.state,weapon=run.ownedWeapons[0]!;weapon.level=5;run.pendingBranchWeaponId=weapon.id;expect(shopScreen(run)).toContain('shop-branch-overlay');expect(sim.chooseBranch('A')).toBe(true);expect(shopScreen(run)).not.toContain('shop-branch-overlay');});
});
