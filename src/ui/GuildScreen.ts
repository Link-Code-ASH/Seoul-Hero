import { characters } from '../data/characters';
import { guildFacilities, guildOperator, type GuildPointId } from '../data/guild';
import { images } from '../data/images';
import type { MetaState } from '../state/MetaState';
import { guildFacilityCost, guildFacilityLevel, guildPoint, isGuildFacility } from '../systems/GuildSystem';
import { escapeHtml } from './helpers';

export interface GuildViewState { panelId: GuildPointId | null; nearbyId: GuildPointId | null }

function facilityPanel(meta: MetaState, id: keyof typeof guildFacilities): string {
  const facility = guildFacilities[id];
  const level = guildFacilityLevel(meta, id);
  const cost = guildFacilityCost(meta, id);
  return `<div class="guild-panel-art"><img src="${images[facility.art].url}" alt=""></div>
    <div class="guild-panel-copy"><small>시설 · LV.${level}/${facility.maxLevel}</small><h2>${facility.name}</h2>
      <p>${facility.effect} <b>· 현재 ${level}단계</b></p>
      <div class="guild-panel-actions">${Number.isFinite(cost)
        ? `<button data-action="guild-upgrade:${id}" ${meta.wallet.associationCoins < cost ? 'disabled' : ''}>강화 <span>${cost} <img src="${images.associationCoin.url}" alt="협회 코인"></span></button>`
        : '<strong class="guild-max">최대 단계</strong>'}</div></div>`;
}

function rosterPanel(meta: MetaState): string {
  const members = Object.values(characters).filter(character => meta.characters[character.id]?.unlocked);
  return `<div class="guild-roster guild-roster-operator"><img class="guild-operator-portrait" src="${images.guildOperatorIllustration.url}" alt="${guildOperator.name}">
    <div><small>${guildOperator.role}</small><h2>${guildOperator.name}</h2><p>${guildOperator.description}</p>
    <div class="guild-member-names"><small>현장 각성자</small>${members.map(character => `<span>${escapeHtml(character.name)}</span>`).join('')}</div></div></div>`;
}

function panel(meta: MetaState, id: GuildPointId | null): string {
  if (!id || !guildPoint(id)) return '';
  const body = isGuildFacility(id) ? facilityPanel(meta, id)
    : id === 'roster' ? rosterPanel(meta)
      : `<div class="guild-gate-panel"><img src="${images.lobbyGate.url}" alt=""><div><small>작전 단말</small><h2>게이트 출동</h2><button data-action="guild-gate">출동 준비 <span aria-hidden="true">↗</span></button></div></div>`;
  return `<aside class="guild-panel" role="dialog" aria-label="${guildPoint(id)!.name}">
    <button class="guild-panel-close" data-action="guild-close" aria-label="창 닫기">×</button>${body}</aside>`;
}

export function guildScreen(meta: MetaState, view: GuildViewState): string {
  const near = view.nearbyId ? guildPoint(view.nearbyId) : null;
  return `<section class="guild-screen" aria-label="길드 본부">
    <button data-action="lobby" class="guild-back">‹ <span>이전</span></button>
    <button class="guild-interact" data-action="guild-interact" ${near && !view.panelId ? '' : 'hidden'}>${near ? `${near.name} <span>살펴보기</span>` : ''}</button>
    ${panel(meta, view.panelId)}
  </section>`;
}
