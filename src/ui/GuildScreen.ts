import { characters } from '../data/characters';
import { GUILD_NAME, guildFacilities, type GuildPointId } from '../data/guild';
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
  return `<div class="guild-roster"><small>수탐자 명부</small><h2>조작할 각성자</h2><div class="guild-roster-list">${members.map(character =>
    `<button data-action="guild-avatar:${character.id}" class="${meta.guild.avatarCharacterId === character.id ? 'selected' : ''}" aria-pressed="${meta.guild.avatarCharacterId === character.id}">
      <img src="${images[character.portraitSprite ?? 'player'].url}" alt=""><b>${escapeHtml(character.name)}</b><span>${meta.guild.avatarCharacterId === character.id ? '조작 중' : '선택'}</span>
    </button>`).join('')}</div></div>`;
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
  const avatar = characters[meta.guild.avatarCharacterId];
  const near = view.nearbyId ? guildPoint(view.nearbyId) : null;
  return `<section class="guild-screen" aria-label="수탐자 길드 본부">
    <header class="guild-head"><button data-action="lobby" class="guild-back">‹ <span>이전</span></button>
      <div class="guild-title"><small>HUNTER GUILD</small><h1>${GUILD_NAME}</h1></div>
      <div class="guild-status"><span>${escapeHtml(avatar?.name ?? '각성자')}</span><img src="${images.associationCoin.url}" alt="협회 코인"><b>${meta.wallet.associationCoins.toLocaleString()}</b></div></header>
    <button class="guild-interact" data-action="guild-interact" ${near && !view.panelId ? '' : 'hidden'}>${near ? `${near.name} <span>살펴보기</span>` : ''}</button>
    ${panel(meta, view.panelId)}
  </section>`;
}
