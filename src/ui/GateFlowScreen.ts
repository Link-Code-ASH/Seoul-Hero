import { characters } from '../data/characters';
import { gateDifficulty } from '../data/gateProgression';
import { images, type ImageId } from '../data/images';
import { maps } from '../data/maps';
import { dangunBlessings, weeklyGateRules } from '../data/weeklyGate';
import { availableStartingWeapons, gateEntrySteps, type GateEntryDraft, type GateEntryStep } from '../systems/GateEntrySystem';
import { isCharacterUnlocked, isMapUnlocked, type MetaState } from '../state/MetaState';
import { button, escapeHtml } from './helpers';
import { weaponDetailArt } from './InventoryArt';
import { lobbyReturnButton } from './LobbyNavigation';

const labels:Record<GateEntryStep,string>={gateMap:'맵',gateDepth:'심도',gateCharacter:'각성자',gateWeapon:'무기',gateBlessing:'축복',gateConfirm:'입장'};
const adjacent=(step:GateEntryStep,offset:number):GateEntryStep|undefined=>gateEntrySteps[gateEntrySteps.indexOf(step)+offset];
const stepArt:Record<GateEntryStep,ImageId>={gateMap:'lobbyArchive',gateDepth:'lobbyGate',gateCharacter:'lobbyAwakener',gateWeapon:'lobbyWeapons',gateBlessing:'blessingCheonbuOath',gateConfirm:'lobbyAssociation'};
const stepHeader=(step:GateEntryStep)=>`<header class="gate-flow-head">${step==='gateMap'?lobbyReturnButton():button(`gate-step:${adjacent(step,-1)}`,'이전','quiet gate-prev')}<div><h1>${step==='gateConfirm'?'출동 준비':`${labels[step]} 선택`}</h1></div><ol aria-label="출동 준비 단계">${gateEntrySteps.map((id,index)=>`<li class="${id===step?'active':index<gateEntrySteps.indexOf(step)?'complete':''}" ${id===step?'aria-current="step"':''}><img src="${images[stepArt[id]].url}" alt=""><span><small>${index<gateEntrySteps.indexOf(step)?'완료':`${String(index+1).padStart(2,'0')}`}</small><b>${labels[id]}</b></span></li>`).join('')}</ol></header>`;
const next=(step:GateEntryStep,disabled=false)=>button(`gate-step:${adjacent(step,1)}`,'다음 →','primary gate-next',disabled?'disabled':'');
const pct=(value:number)=>`+${Math.round((value-1)*100)}%`;

function weeklyCard(meta:MetaState):string{
  const rule=weeklyGateRules[meta.weeklyGate.ruleId];
  if(!rule)return '<aside class="weekly-operation-card pending"><b>주간 신호 동기화 중</b></aside>';
  const style=`--rule-accent:${rule.palette.accent};--rule-glow:${rule.palette.glow};--rule-surface:${rule.palette.surface}`;
  return `<aside class="weekly-operation-card" style="${style}"><img src="${images[rule.image].url}" alt=""><div><small>WEEKLY GATE RULE</small><b>${escapeHtml(rule.name)}</b><p><em>위험</em>${escapeHtml(rule.penaltyLabel)}</p><p class="benefit"><em>가호</em>${escapeHtml(rule.benefitLabel)}</p></div></aside>`;
}

function depthStage(meta:MetaState,draft:GateEntryDraft):string{
  const highest=Math.max(1,meta.gateProgression.highestUnlockedDepth);
  const pageCount=Math.max(1,Math.ceil(highest/10));
  const page=Math.max(0,Math.min(pageCount-1,draft.depthPage));
  const start=page*10+1;
  const record=meta.gateProgression.characters[draft.characterId];
  const tiles=Array.from({length:10},(_,i)=>start+i).map(depth=>{
    const unlocked=depth<=highest,cleared=(record?.highestClearedDepth??0)>=depth,best=record?.bestWaveByDepth[String(depth)]??0;
    const status=cleared?'클리어':best?`WAVE ${best}`:'기록 없음';
    return `<button class="depth-tile ${depth===draft.gateDepth?'selected':''} ${unlocked?'':'locked'}" data-action="gate-depth-select:${depth}" ${depth===draft.gateDepth?'aria-pressed="true"':'aria-pressed="false"'} ${unlocked?'':'disabled'}><small>DEPTH</small><b>${depth}</b><span>${unlocked?status:'잠김'}</span>${depth===draft.gateDepth?'<strong class="depth-selected-flag">선택됨</strong>':''}</button>`;
  }).join('');
  const d=gateDifficulty(draft.gateDepth),best=record?.bestWaveByDepth[String(draft.gateDepth)]??0,cleared=(record?.highestClearedDepth??0)>=draft.gateDepth;
  return `<div class="depth-briefing"><section class="depth-board"><div class="depth-grid">${tiles}</div><div class="depth-pager"><button data-action="gate-depth-page:${Math.max(0,page-1)}" ${page===0?'disabled':''}>‹</button><span>${page+1} / ${pageCount}</span><button data-action="gate-depth-page:${Math.min(pageCount-1,page+1)}" ${page===pageCount-1?'disabled':''}>›</button></div></section><aside class="depth-dossier"><small>현재 선택한 게이트</small><span>DEPTH ${draft.gateDepth}</span><b>${cleared?'클리어 완료':best?`최대 WAVE ${best}`:'도전 기록 없음'}</b><dl><div><dt>적 체력</dt><dd>${pct(d.hp)}</dd></div><div><dt>적 공격력</dt><dd>${pct(d.damage)}</dd></div><div><dt>개체 밀도</dt><dd>${pct(d.spawn)}</dd></div><div><dt>최초 보상</dt><dd>${cleared?'수령 완료':'협회 코인 100'}</dd></div></dl></aside></div>${next('gateDepth')}`;
}

export function gateFlowScreen(step:GateEntryStep,meta:MetaState,draft:GateEntryDraft):string{
  let body='';
  if(step==='gateMap')body=`<div class="gate-card-grid map-grid">${Object.values(maps).map(map=>{const unlocked=isMapUnlocked(meta,map.id);return `<button class="gate-select-card map-card ${draft.mapId===map.id?'selected':''}" data-action="gate-map:${map.id}" ${unlocked?'':'disabled'}><img src="${images[map.thumbnail].url}" alt=""><span><small>${unlocked?'작전 가능':'잠김'}</small><b>${escapeHtml(map.name)}</b></span></button>`}).join('')}</div>${next(step,!draft.mapId)}`;
  if(step==='gateDepth')body=depthStage(meta,draft);
  if(step==='gateCharacter')body=`<div class="gate-card-grid character-meta-grid">${Object.values(characters).map(character=>{const progress=meta.characters[character.id],unlocked=isCharacterUnlocked(meta,character.id),selected=draft.characterId===character.id;return `<button class="gate-select-card character-meta-card ${selected?'selected':''}" data-action="gate-character:${character.id}" aria-pressed="${selected}" ${unlocked?'':'disabled'}><span class="character-card-art"><img src="${images[character.visual.sprite??'player'].url}" alt=""></span><span class="character-card-info"><small>AWAKENER · ${unlocked?'출동 가능':'잠김'}</small><b>${escapeHtml(character.name)}</b><em>돌파 ${progress?.breakthrough??0}</em><strong class="selection-seal">${selected?'작전 편성 완료':'각성자 선택'}</strong></span></button>`}).join('')}</div>${next(step,!draft.characterId)}`;
  if(step==='gateWeapon'){const choices=availableStartingWeapons(meta,draft.characterId);body=`<div class="gate-card-grid weapon-meta-grid">${choices.map(weapon=>{const selected=draft.startingWeaponId===weapon.id;return `<button class="gate-select-card weapon-meta-card ${selected?'selected':''}" data-action="gate-weapon:${weapon.id}" aria-pressed="${selected}"><span class="weapon-card-art">${weaponDetailArt(weapon.id)}</span><span class="weapon-card-info"><small>START Lv.1</small><b>${escapeHtml(weapon.name)}</b><strong class="selection-seal">${selected?'시작 무기 확정':'장착하기'}</strong></span></button>`}).join('')}</div>${next(step,!draft.startingWeaponId)}`;}
  if(step==='gateBlessing'){
    const owned=Object.values(dangunBlessings).filter(value=>meta.blessings[value.id]?.unlocked&&meta.blessings[value.id]!.level>0);
    body=owned.length?`<div class="gate-card-grid blessing-meta-grid">${owned.map(value=>`<button class="gate-select-card blessing-meta-card ${draft.blessingId===value.id?'selected':''}" data-action="gate-blessing:${value.id}"><img src="${images[value.image].url}" alt=""><span><small>Lv.${meta.blessings[value.id]!.level}</small><b>${escapeHtml(value.name)}</b><em>${escapeHtml(value.description)}</em></span></button>`).join('')}</div>${next(step,!draft.blessingId)}`:`<div class="no-blessing"><span>미해금</span><b>단군의 축복 없이 출동</b></div>${next(step)}`;
  }
  if(step==='gateConfirm'){const map=maps[draft.mapId],character=characters[draft.characterId],weapon=availableStartingWeapons(meta,draft.characterId).find(v=>v.id===draft.startingWeaponId),blessing=dangunBlessings[draft.blessingId];body=`<div class="deploy-summary"><div class="deploy-visual"><img class="deploy-map" src="${images[map?.thumbnail??'seoulIntersection'].url}" alt=""><span class="deploy-region"><small>OPERATION ZONE</small><b>${escapeHtml(map?.name??'-')}</b></span><img class="deploy-character" src="${images[character?.visual.sprite??'player'].url}" alt=""></div><div class="deploy-loadout"><div class="deploy-depth"><small>GATE DEPTH</small><b>${draft.gateDepth}</b><span>출동 편성 완료</span></div><div class="deploy-equipped"><div><img src="${images[character?.visual.sprite??'player'].url}" alt=""><span><small>각성자</small><b>${escapeHtml(character?.name??'-')}</b></span></div><div>${weapon?weaponDetailArt(weapon.id):''}<span><small>시작 무기</small><b>${escapeHtml(weapon?.name??'-')}</b></span></div><div><img src="${images[blessing?.image??'blessingCheonbuOath'].url}" alt=""><span><small>단군의 축복</small><b>${escapeHtml(blessing?.name??'없음')}</b></span></div></div></div></div>${button('gate-deploy','작전 시작 →','primary gate-deploy')}`;}
  const map=maps[draft.mapId];
  return `<section class="content-screen gate-flow-screen" style="--gate-bg:url('${images[map?.thumbnail??'seoulIntersection'].url}')">${stepHeader(step)}${weeklyCard(meta)}<main>${body}</main></section>`;
}
