import {resolveWeaponStats} from '../stats/WeaponStats';
import {itemArt,inventoryArt,weaponArt} from './InventoryArt';
import {items} from '../data/items';
import {weapons} from '../data/weapons';
import {images} from '../data/images';
import type {RunState} from '../state/RunState';
import type {MetaState} from '../state/MetaState';
import {REVIVAL_STONE_GRADES,REVIVAL_STONES} from '../data/revivalStones';
import {itemCount,canAddItem} from '../systems/ItemSystem';
import {itemRerollCost,weaponRerollCost,itemAvailable,weaponOfferAvailable,weaponPrice} from '../systems/ShopSystem';
import {button,escapeHtml} from './helpers';
import {shopStats} from './ShopStats';
const rarityNames={COMMON:'일반',UNCOMMON:'고급',RARE:'희귀',LEGENDARY:'전설'};
const price=(amount:number)=>'<img class="price-coin" src="'+images.magicStone.url+'" alt=""><b>'+amount+'</b>';
const lock=(action:string,locked:boolean)=>button(action,inventoryArt(locked?43:44),'lock-button',`aria-label="${locked?'잠금 해제':'상품 잠금'}" aria-pressed="${locked}"`);

function branchPicker(run:RunState):string {
 const weapon=weapons[run.pendingBranchWeaponId??''];if(!weapon)return '';
 return '<div class="shop-branch-overlay"><section class="branch-panel"><span class="shop-section-kicker">LV.'+weapon.branchAtLevel+' 전투 방식</span><h2>'+escapeHtml(weapon.name)+' 분기 선택</h2><p>구매는 완료되었습니다. 이번 출동에서 사용할 형태를 선택하세요.</p><div class="branch-options">'+weapon.branches.map(branch=>button('branch:'+branch.id,'<b>'+branch.id+'</b><strong>'+escapeHtml(branch.name)+'</strong><span>'+escapeHtml(branch.description)+'</span>','branch-shop-card')).join('')+'</div></section></div>';
}
function weaponChange(run:RunState,weaponId:string,targetLevel:number):string {
 const weapon=weapons[weaponId]!,owned=run.ownedWeapons.find(slot=>slot.id===weaponId);
 if(!owned)return weapon.description;
 if(targetLevel===weapon.branchAtLevel&&!owned.branchId)return '구매 후 A/B 전투 방식 선택';
 if(owned.branchId)return `${owned.branchId} 분기 성능 강화`;
 return `기본 성능 강화 · Lv.${owned.level} → Lv.${targetLevel}`;
}

function weaponHighlight(run:RunState,id:string,level:number):string {
 const weapon=weapons[id]!,owned=run.ownedWeapons.find(w=>w.id===id);
 if(owned&&level===weapon.branchAtLevel&&!owned.branchId)return 'A / B 분기 선택';
 const next=resolveWeaponStats(weapon,level,run.calculatedStats,false,owned?.branchId);
 if(!owned)return `피해 ${next.damage} · ${next.cooldown.toFixed(1)}초`;
 const current=resolveWeaponStats(weapon,owned.level,run.calculatedStats,false,owned.branchId);
 if(next.damage!==current.damage)return `피해 ${current.damage} → ${next.damage}`;
 if(next.cooldown!==current.cooldown)return `주기 ${current.cooldown.toFixed(1)} → ${next.cooldown.toFixed(1)}초`;
 if(next.projectileCount!==current.projectileCount)return `공격 수 ${current.projectileCount} → ${next.projectileCount}`;
 return '무기 성능 강화';
}

export type ShopTab = 'weapons' | 'items';
export function shopScreen(run:RunState,meta:MetaState,tab:ShopTab='weapons'):string {
 const itemCost=itemRerollCost(run),weaponCost=weaponRerollCost(run),blocked=!!run.pendingBranchWeaponId;
 const weaponCards=run.shop.weaponStock.slots.map((slot,index)=>{
  const weapon=weapons[slot.weaponId??''];if(!weapon)return '<article class="shop-card weapon-shop-card sold" aria-label="무기 품절"><span class="sold-crest" aria-hidden="true">×</span><strong>품절</strong><small>무기 진열대</small></article>';
  const offer={weaponId:weapon.id,targetLevel:slot.targetLevel},cost=weaponPrice(offer),owned=run.ownedWeapons.find(w=>w.id===weapon.id),valid=weaponOfferAvailable(run,offer);
  const disabled=blocked||!valid||run.runCurrency<cost;
  return '<article class="shop-card weapon-shop-card'+(slot.locked?' locked':'')+'"><div class="product-heading"><span class="weapon-offer-type">'+(owned?'무기 강화':'신규 무기')+'</span>'+lock('shop-weapon-lock:'+index,slot.locked)+'</div>'+weaponArt(weapon.id)+'<h2>'+escapeHtml(weapon.name)+'</h2><span class="product-highlight">'+weaponHighlight(run,weapon.id,slot.targetLevel)+'</span><details class="product-detail"><summary>효과 보기</summary><p class="item-effect">'+escapeHtml(weaponChange(run,weapon.id,slot.targetLevel))+'</p></details><div class="product-footer"><small>'+(owned?'Lv.'+owned.level+' → Lv.'+slot.targetLevel:'Lv.1 획득')+'</small>'+button('shop-weapon-buy:'+index,price(cost),'purchase-price',`aria-label="${escapeHtml(weapon.name)} ${cost} 마력석 구매" ${disabled?'disabled':''}`)+'</div></article>';
 }).join('');
 const itemCards=run.shop.itemStock.slots.map((slot,index)=>{
  const item=items[slot.itemId??''];if(!item)return '<article class="shop-card sold"><span class="sold-crest">—</span><strong>품절</strong></article>';
  const count=itemCount(run,item.id),maxed=!canAddItem(run,item.id),disabled=blocked||maxed||!itemAvailable(run,item)||run.runCurrency<item.basePrice;
  return '<article class="shop-card rarity-'+item.rarity+(slot.locked?' locked':'')+'"><div class="product-heading"><span class="product-rarity">'+rarityNames[item.rarity]+'</span>'+lock('shop-lock:'+index,slot.locked)+'</div>'+itemArt(item.id)+'<h2>'+escapeHtml(item.name)+'</h2><span class="product-highlight">'+escapeHtml(item.description.split(' · ')[0]??'')+'</span><details class="product-detail"><summary>효과 보기</summary><p class="item-effect">'+escapeHtml(item.description)+'</p></details><div class="product-footer"><small>'+(count?'보유 '+count:'')+(maxed?' · 최대':'')+'</small>'+button('shop-buy:'+index,maxed?'완료':price(item.basePrice),'purchase-price',`aria-label="${escapeHtml(item.name)} ${item.basePrice} 마력석 구매" ${disabled?'disabled':''}`)+'</div></article>';
 }).join('');
 const weaponRerollDisabled=blocked||run.runCurrency<weaponCost||run.shop.weaponStock.slots.every(slot=>slot.locked);
 const itemRerollDisabled=blocked||run.runCurrency<itemCost||run.shop.itemStock.slots.every(slot=>slot.locked);
 const stones=REVIVAL_STONE_GRADES.map(grade=>`<span title="${REVIVAL_STONES[grade].name}" aria-label="${REVIVAL_STONES[grade].name} ${meta.wallet.revivalStones[grade]}개"><img src="${images[REVIVAL_STONES[grade].image].url}" alt=""><b>${meta.wallet.revivalStones[grade]}</b></span>`).join('');
 return '<section class="level-modal shop-screen" tabindex="-1"><header class="shop-header"><h1>게이트<span>24</span></h1><div class="shop-header-resources"><div class="shop-revival-stock" aria-label="보유 생환석">'+stones+'</div><div class="shop-wallet" aria-label="보유 마력석">'+price(Math.floor(run.runCurrency))+'</div></div></header><div class="shop-body">'+shopStats(run)+'<div class="shop-catalog"><nav class="shop-tabs" aria-label="상품 종류">'+button('shop-tab:weapons','무기','shop-tab',`aria-pressed="${tab==='weapons'}" aria-controls="shop-weapons"`)+button('shop-tab:items','아이템','shop-tab',`aria-pressed="${tab==='items'}" aria-controls="shop-items"`)+'</nav><section id="shop-weapons" class="shop-section" '+(tab==='weapons'?'':'hidden')+'><header><h2>무기 진열</h2>'+button('shop-weapon-reroll','<span>↻</span> '+price(weaponCost),'refresh-stock',`aria-label="무기 교체 ${weaponCost} 마력석" ${weaponRerollDisabled?'disabled':''}`)+'</header><div class="shop-grid weapon-shop-grid">'+weaponCards+'</div></section><section id="shop-items" class="shop-section" '+(tab==='items'?'':'hidden')+'><header><h2>보조 장비</h2>'+button('shop-reroll','<span>↻</span> '+price(itemCost),'refresh-stock',`aria-label="보조 장비 교체 ${itemCost} 마력석" ${itemRerollDisabled?'disabled':''}`)+'</header><div class="shop-grid">'+itemCards+'</div></section></div></div><footer class="shop-footer"><details class="bag-summary"><summary>보유 아이템</summary>'+run.runItems.map(i=>'<p>'+escapeHtml(items[i.id]?.name??i.id)+' × '+i.count+'</p>').join('')+'</details>'+button('next-wave','전투 시작 <span>→</span>','primary next-combat',blocked?'disabled':'')+'</footer>'+branchPicker(run)+'</section>';
}
