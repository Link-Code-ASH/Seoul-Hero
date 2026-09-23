import {weapons} from '../data/weapons';
import type {RunState} from '../state/RunState';

/** Lv.5 branch selection is free after its paid Shop upgrade and permanent for the current Run. */
export function chooseWeaponBranch(state:RunState,id:string):boolean {
 const slot=state.ownedWeapons.find(weapon=>weapon.id===state.pendingBranchWeaponId);
 if(!slot||slot.branchId||slot.level!==weapons[slot.id]!.branchAtLevel||!weapons[slot.id]!.branches.some(branch=>branch.id===id))return false;
 slot.branchId=id as 'A'|'B';state.pendingBranchWeaponId=undefined;return true;
}
