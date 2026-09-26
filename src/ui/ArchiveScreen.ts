import { characters } from '../data/characters';
import { enemies } from '../data/enemies';
import { ENEMY_MOVE_SCALE, enemyBaseMoveSpeed } from '../data/enemyConfig';
import { images } from '../data/images';
import { items, type Rarity } from '../data/items';
import { maps } from '../data/maps';
import { SHOP_CONFIG } from '../data/shopConfig';
import { DEFAULT_STATS, type PlayerStats, type WeaponCapability } from '../data/stats';
import type { EnemyDefinition, Weapon } from '../data/types';
import { weapons } from '../data/weapons';
import { resolveWeaponStats, type ResolvedWeaponStats } from '../stats/WeaponStats';
import { escapeHtml } from './helpers';
import { itemArt, weaponDetailArt } from './InventoryArt';
import { lobbyReturnButton } from './LobbyNavigation';
import { dangunBlessings, weeklyGateRules, type WeeklyGateRule } from '../data/weeklyGate';

export type ArchiveCategory = 'characters' | 'weapons' | 'items' | 'enemies' | 'weeklyTraits' | 'blessings';
export interface ArchiveViewState { category: ArchiveCategory; selectedId: string; mapId: string }

const categoryNames: Record<ArchiveCategory, string> = {
  characters: '캐릭터', weapons: '무기', items: '아이템', enemies: '몬스터', weeklyTraits: '주간 특성', blessings: '단군의 축복',
};
const behaviorNames: Record<EnemyDefinition['behavior'], string> = {
  chase: '추적형', skirmish: '견제형', tank: '중장형', ranged: '원거리형', swarm: '군집형', charge: '돌진형',
  bomber: '자폭형', splitter: '분열형', support: '지원형', summoner: '소환형', defender: '방어형', ambush: '기습형', boss: '보스',
};
const behaviorNotes: Record<EnemyDefinition['behavior'], string> = {
  chase: '플레이어를 계속 추적합니다.', skirmish: '적정 거리를 유지하며 빈틈을 노립니다.', tank: '느리게 접근하며 근거리 광역 충격을 일으킵니다.',
  ranged: '거리를 유지하며 적대 투사체를 발사합니다.', swarm: '빠르게 뭉쳐 접근하며 수로 압박합니다.', charge: '예고 동작 뒤 목표 방향으로 돌진합니다.',
  bomber: '접근 후 폭발해 범위 피해를 줍니다.', splitter: '처치되면 작은 개체로 분열합니다.', support: '주변 아군의 체력을 회복합니다.',
  summoner: '일정 주기로 하위 개체를 소환합니다.', defender: '주기적으로 방어 태세를 취합니다.', ambush: '희미해진 상태로 접근한 뒤 기습합니다.',
  boss: '여러 전용 공격 패턴을 순환합니다.',
};
const patternNames = { charge: '돌진', aoe: '광역 공격', summon: '소환', volley: '탄막' } as const;
const capabilityNames: Record<WeaponCapability, string> = {
  MELEE: '근접', RANGED: '원거리', PROJECTILE: '투사체', AREA: '범위', ORBIT: '회전', BEAM: '광선', SUMMON: '소환',
  STRUCTURE: '설치물', TURRET: '포탑', TRAP: '함정', MINE: '지뢰', AURA: '마력장', DURATION: '지속', PIERCING: '관통',
  CHAIN: '연쇄', EXPLOSIVE: '폭발', CAN_CRIT: '치명타 가능', HAS_RANGE: '사거리 적용',
};
const weaponBehaviorNames: Record<Weapon['behavior'], string> = {
  projectile: '투사체', slash: '검격', orbit: '회전 무기', chain: '연쇄 공격', bombard: '곡사 폭격', structure: '설치물',
};

const percent = (value: number): string => `${Math.round(value * 100)}%`;
const number = (value: number): string => Number.isInteger(value) ? value.toLocaleString() : value.toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
const statGroups: { title: string; rows: { key: keyof PlayerStats; label: string; format?: (value: number) => string }[] }[] = [
  { title: '공격', rows: [
    { key: 'damage', label: '공통 피해', format: percent }, { key: 'attackSpeed', label: '공격 속도', format: percent },
    { key: 'meleeDamage', label: '근접 피해', format: percent }, { key: 'rangedDamage', label: '원거리 피해', format: percent },
    { key: 'criticalChance', label: '치명타 확률', format: percent }, { key: 'criticalDamage', label: '치명타 피해', format: percent },
  ] },
  { title: '무기 효과', rows: [
    { key: 'range', label: '사거리', format: percent }, { key: 'area', label: '범위', format: percent },
    { key: 'duration', label: '지속시간', format: percent }, { key: 'projectileSpeed', label: '투사체 속도', format: percent },
  ] },
  { title: '생존과 이동', rows: [
    { key: 'maxHp', label: '최대 체력' }, { key: 'armor', label: '방어력' }, { key: 'dodge', label: '회피', format: percent },
    { key: 'lifesteal', label: '흡혈', format: percent }, { key: 'hpRegeneration', label: '초당 회복' }, { key: 'moveSpeed', label: '이동 속도' },
  ] },
  { title: '회수와 위험', rows: [
    { key: 'currencyGain', label: '마력석 획득', format: percent }, { key: 'pickupRange', label: '획득 범위' },
    { key: 'luck', label: '행운' }, { key: 'curse', label: '저주' },
  ] },
];

export function firstArchiveId(category: ArchiveCategory, mapId = 'seoul'): string {
  return archiveIds(category,mapId)[0] ?? '';
}

function archiveIds(category: ArchiveCategory, mapId: string): string[] {
  const roster=maps[mapId]?.archiveContent;
  if (category === 'characters') return Object.keys(characters);
  if (category === 'weapons') return Object.keys(weapons).filter(id=>!roster?.weaponIds||roster.weaponIds.includes(id));
  if (category === 'items') return Object.keys(items).filter(id=>!roster?.itemIds||roster.itemIds.includes(id));
  if (category === 'enemies') return Object.keys(enemies).filter(id=>!roster?.enemyIds||roster.enemyIds.includes(id));
  if (category === 'weeklyTraits') return Object.keys(weeklyGateRules);
  return Object.keys(dangunBlessings);
}

function portrait(sprite: keyof typeof images, alt: string, className = ''): string {
  return `<img class="${className}" src="${images[sprite].url}" alt="${escapeHtml(alt)}">`;
}

function characterDetail(id: string): string {
  const character = characters[id] ?? Object.values(characters)[0];
  if (!character) return '';
  const signature = character.signatureWeaponId ? weapons[character.signatureWeaponId] : undefined;
  const groups = statGroups.map(group => `<section class="archive-stat-group"><h3>${group.title}</h3><dl>${group.rows.map(row => `<div><dt>${row.label}</dt><dd>${row.format?.(character.baseStats[row.key]) ?? number(character.baseStats[row.key])}</dd></div>`).join('')}</dl></section>`).join('');
  return `<article class="archive-detail"><header class="archive-detail-hero">${portrait(character.portraitSprite ?? character.visual.sprite ?? 'player', character.name, 'archive-character-image')}<div><span class="archive-record-type">AWAKENER · SEOUL</span><h1>${escapeHtml(character.name)}</h1><p>${escapeHtml(character.description)}</p><div class="archive-signature"><small>${signature ? '고유 무기' : '시작 무기'}</small><b>${escapeHtml(signature?.name ?? '출동 전 전투 무기 선택')}</b></div></div></header><section class="archive-character-story"><div><h2>배경</h2><p>${escapeHtml(character.background)}</p></div><div><h2>성격</h2><p>${escapeHtml(character.personality)}</p></div></section><div class="archive-stat-groups">${groups}</div></article>`;
}

type WeaponMetric = { label: string; visible: (weapon: Weapon, stats: ResolvedWeaponStats) => boolean; value: (stats: ResolvedWeaponStats) => number; format?: (value: number) => string };
const weaponMetrics: WeaponMetric[] = [
  { label: '피해', visible: () => true, value: stats => stats.damage },
  { label: '공격 주기', visible: () => true, value: stats => stats.cooldown, format: value => `${number(value)}초` },
  { label: '사거리', visible: weapon => weapon.capabilities.includes('HAS_RANGE'), value: stats => stats.range },
  { label: '투사체 수', visible: (weapon, stats) => weapon.capabilities.includes('PROJECTILE') || stats.projectileCount > 1, value: stats => stats.projectileCount },
  { label: '산탄 각도', visible: weapon => weapon.base.spreadAngle !== undefined, value: stats => stats.spreadAngle ?? 0, format: value => `${Math.round(value * 180 / Math.PI)}°` },
  { label: '투사체 속도', visible: weapon => weapon.capabilities.includes('PROJECTILE'), value: stats => stats.projectileSpeed },
  { label: '관통', visible: (weapon, stats) => weapon.capabilities.includes('PIERCING') || stats.penetration > 0, value: stats => stats.penetration },
  { label: '타격 각도', visible: weapon => weapon.behavior === 'slash', value: stats => stats.attackAngle, format: value => `${Math.round(value * 180 / Math.PI)}°` },
  { label: '효과 범위', visible: weapon => weapon.capabilities.includes('AREA'), value: stats => stats.blastRadius || stats.projectileRadius, format: number },
  { label: '지속시간', visible: weapon => weapon.capabilities.includes('DURATION') || weapon.behavior === 'structure', value: stats => stats.duration, format: value => `${number(value)}초` },
  { label: '반복 횟수', visible: (_weapon, stats) => stats.repeatCount > 1, value: stats => stats.repeatCount },
  { label: '연쇄 거리', visible: weapon => weapon.capabilities.includes('CHAIN'), value: stats => stats.chainRange },
];
const resolved = (weapon: Weapon, level: number, branchId?: string): ResolvedWeaponStats => resolveWeaponStats(weapon, level, DEFAULT_STATS, false, branchId);
function weaponMetricRows(weapon: Weapon, stats: ResolvedWeaponStats): string {
  return weaponMetrics.filter(metric => metric.visible(weapon, stats)).map(metric => `<div><dt>${metric.label}</dt><dd>${metric.format?.(metric.value(stats)) ?? number(metric.value(stats))}</dd></div>`).join('');
}
function weaponChanges(weapon: Weapon, level: number, branchId?: string): string {
  if (level === 1) return '기본 형태';
  const current = resolved(weapon, level, branchId);
  const previous = resolved(weapon, level - 1, level - 1 >= weapon.branchAtLevel ? branchId : undefined);
  const changes = weaponMetrics.filter(metric => metric.visible(weapon, current) && Math.abs(metric.value(current) - metric.value(previous)) > 0.0001)
    .map(metric => `${metric.label} ${metric.format?.(metric.value(current)) ?? number(metric.value(current))}`);
  return changes.join(' · ') || '기본 성능 안정화';
}
function weaponProgress(weapon: Weapon): string {
  const common = Array.from({ length: Math.max(1, weapon.branchAtLevel - 1) }, (_, index) => index + 1).filter(level => level <= weapon.maxLevel).map(level => `<div class="archive-level-row"><b>Lv.${level}</b><span>${escapeHtml(weaponChanges(weapon, level))}</span></div>`).join('');
  const branches = weapon.branches.map(branch => `<section class="archive-branch"><header><b>${branch.id}</b><div><h3>${escapeHtml(branch.name)}</h3><p>${escapeHtml(branch.description)}</p></div></header>${Array.from({ length: weapon.maxLevel - weapon.branchAtLevel + 1 }, (_, index) => weapon.branchAtLevel + index).map(level => `<div class="archive-level-row"><b>Lv.${level}</b><span>${escapeHtml(weaponChanges(weapon, level, branch.id))}</span></div>`).join('')}</section>`).join('');
  return `<section class="archive-progress"><h2>성장 기록</h2>${common}<div class="archive-branches">${branches}</div></section>`;
}
function weaponDetail(id: string): string {
  const weapon = weapons[id] ?? Object.values(weapons)[0];
  if (!weapon) return '';
  const owner = weapon.signatureOwnerId ? characters[weapon.signatureOwnerId] : undefined;
  const base = resolved(weapon, 1);
  const structure = weapon.structure;
  return `<article class="archive-detail"><header class="archive-detail-hero archive-weapon-hero"><div class="archive-large-icon">${weaponDetailArt(weapon.id)}</div><div><span class="archive-record-type">${structure ? 'STRUCTURE WEAPON' : 'COMBAT WEAPON'} · ${weaponBehaviorNames[weapon.behavior]}</span><h1>${escapeHtml(weapon.name)}</h1><p>${escapeHtml(weapon.description)}</p>${owner ? `<div class="archive-signature"><small>고유 각성자</small><b>${escapeHtml(owner.name)}</b></div>` : ''}</div></header><div class="archive-tags">${weapon.capabilities.map(tag => `<span>${capabilityNames[tag]}</span>`).join('')}</div><section class="archive-specs"><h2>Lv.1 실제 수치</h2><dl>${weaponMetricRows(weapon, base)}${structure ? `<div><dt>최대 설치 수</dt><dd>${structure.maxCount}</dd></div><div><dt>설치 주기</dt><dd>${number(structure.placementInterval)}초</dd></div>` : ''}</dl></section>${weaponProgress(weapon)}</article>`;
}

function enemyDetail(id: string): string {
  const enemy = enemies[id] ?? Object.values(enemies)[0];
  if (!enemy) return '';
  const boss = enemy.tags.includes('BOSS');
  const patterns = enemy.bossPatterns?.map(pattern => `<li><b>${patternNames[pattern.type]}</b><span>예고 ${number(pattern.warning)}초 · 재사용 ${number(pattern.cooldown)}초${pattern.count > 1 ? ` · ${pattern.count}회` : ''}</span></li>`).join('') ?? '';
  return `<article class="archive-detail"><header class="archive-detail-hero archive-enemy-hero">${portrait(enemy.visual.sprite ?? 'brute', enemy.name, 'archive-enemy-image')}<div><span class="archive-record-type ${boss ? 'boss' : ''}">${boss ? 'BOSS ENTITY' : 'HOSTILE ENTITY'} · ${behaviorNames[enemy.behavior]}</span><h1>${escapeHtml(enemy.name)}</h1><p>${escapeHtml(enemy.description)}</p></div></header><section class="archive-specs"><h2>기본 전투 수치</h2><dl><div><dt>최대 체력</dt><dd>${number(enemy.maxHp)}</dd></div><div><dt>이동 속도</dt><dd>${number(enemyBaseMoveSpeed(enemy.id, enemy.moveSpeed))}</dd></div><div><dt>접촉 피해</dt><dd>${number(enemy.contactDamage)}</dd></div><div><dt>개체 크기</dt><dd>${number(enemy.radius)}</dd></div><div><dt>마력석 보상</dt><dd>${number(enemy.magicStoneDrop)}</dd></div></dl></section><section class="archive-behavior"><h2>행동 특성</h2><p>${behaviorNotes[enemy.behavior]}</p>${enemy.childId ? `<p>생성 개체: <b>${escapeHtml(enemies[enemy.childId]?.name ?? enemy.childId)}</b></p>` : ''}${enemy.charge ? `<dl><div><dt>돌진 감지 거리</dt><dd>${number(enemy.charge.triggerRange)}</dd></div><div><dt>돌진 속도</dt><dd>${number(enemy.charge.speed * ENEMY_MOVE_SCALE)}</dd></div><div><dt>예고 시간</dt><dd>${number(enemy.charge.warning)}초</dd></div></dl>` : ''}${patterns ? `<ul class="archive-patterns">${patterns}</ul>` : ''}</section></article>`;
}

const rarityNames:Record<Rarity,string>={COMMON:'일반',UNCOMMON:'고급',RARE:'희귀',LEGENDARY:'전설'};
const rarityOrder:Rarity[]=['COMMON','UNCOMMON','RARE','LEGENDARY'];
const itemPercentStats=new Set<keyof PlayerStats>(['damage','attackSpeed','meleeDamage','rangedDamage','criticalChance','criticalDamage','range','area','duration','projectileSpeed','dodge','lifesteal','currencyGain']);
function itemModifierValue(stat:keyof PlayerStats,operation:'add'|'multiply',value:number):string {
  const change=operation==='multiply'?value-1:value;
  return `${change>=0?'+':''}${number((operation==='multiply'||itemPercentStats.has(stat))?change*100:change)}${operation==='multiply'||itemPercentStats.has(stat)?'%':''}`;
}
function itemDetail(id:string):string {
  const item=items[id]??Object.values(items)[0];if(!item)return '';
  const modifiers=item.statModifiers.map(mod=>`<div><dt>${statNames[mod.stat]}</dt><dd>${itemModifierValue(mod.stat,mod.operation,mod.value)}</dd></div>`).join('');
  const effects=item.specialEffects.map(effect=>effect.type==='structureLimit'?`${capabilityNames[effect.tag]} 설치 한도 +${effect.value}`:effect.type==='projectileCount'?`${capabilityNames[effect.tag]} 공격 수 +${effect.value}`:'설치물 공격 흡혈 허용');
  return `<article class="archive-detail archive-item-detail"><header class="archive-detail-hero"><div class="archive-large-icon">${itemArt(item.id)}</div><div><span class="archive-record-type rarity-${item.rarity.toLowerCase()}">${rarityNames[item.rarity]} · ${item.rarity}</span><h1>${escapeHtml(item.name)}</h1><p>${escapeHtml(item.description)}</p></div></header><section class="archive-specs"><h2>상점 정보</h2><dl><div><dt>기본 가격</dt><dd>${item.basePrice} 마력석</dd></div><div><dt>판매 시작</dt><dd>Wave ${Math.max(SHOP_CONFIG.rarities[item.rarity].wave,item.unlockCondition?.wave??1)}</dd></div><div><dt>최대 보유</dt><dd>${item.maxStacks??'제한 없음'}</dd></div><div><dt>해금</dt><dd>${item.unlockCondition?.metaItemId?'협회 해금 필요':'기본'}</dd></div></dl></section><section class="archive-specs"><h2>능력치 변화</h2><dl>${modifiers}</dl></section>${effects.length?`<section class="archive-behavior"><h2>특수 효과</h2><p>${effects.map(escapeHtml).join(' · ')}</p></section>`:''}</article>`;
}

const statNames: Record<keyof PlayerStats, string> = {
  damage:'모든 피해',attackSpeed:'공격 속도',meleeDamage:'근접 피해',rangedDamage:'원거리 피해',criticalChance:'치명타 확률',criticalDamage:'치명타 피해',
  range:'사거리',area:'범위',duration:'지속시간',projectileSpeed:'투사체 속도',maxHp:'최대 체력',armor:'방어력',dodge:'회피',lifesteal:'흡혈',
  hpRegeneration:'초당 회복',moveSpeed:'이동 속도',currencyGain:'마력석 획득',pickupRange:'획득 범위',luck:'행운',curse:'저주',
};
function weeklyRows(trait: WeeklyGateRule): string {
  const rows: string[] = [];
  if (trait.penalty.enemyHp) rows.push(`<div><dt>적 최대 체력</dt><dd>+${Math.round((trait.penalty.enemyHp-1)*100)}%</dd></div>`);
  if (trait.penalty.enemyDamage) rows.push(`<div><dt>적 공격력</dt><dd>+${Math.round((trait.penalty.enemyDamage-1)*100)}%</dd></div>`);
  if (trait.penalty.enemySpeed) rows.push(`<div><dt>적 이동 속도</dt><dd>+${Math.round((trait.penalty.enemySpeed-1)*100)}%</dd></div>`);
  if (trait.penalty.spawn) rows.push(`<div><dt>적 생성 밀도</dt><dd>+${Math.round((trait.penalty.spawn-1)*100)}%</dd></div>`);
  if (trait.penalty.eliteChance) rows.push(`<div><dt>엘리트 확률</dt><dd>+${Math.round(trait.penalty.eliteChance*100)}%p</dd></div>`);
  return rows.join('');
}
function weeklyTraitDetail(id: string): string {
  const trait=weeklyGateRules[id]??Object.values(weeklyGateRules)[0]; if(!trait)return '';
  const style=`--rule-accent:${trait.palette.accent};--rule-glow:${trait.palette.glow};--rule-surface:${trait.palette.surface}`;
  return `<article class="archive-detail archive-rule-detail" style="${style}"><header class="archive-rule-hero"><img src="${images[trait.image].url}" alt=""><div><span class="archive-record-type">WEEKLY GATE RULE</span><h1>${escapeHtml(trait.name)}</h1><p>${escapeHtml(trait.description)}</p></div></header><section class="archive-specs rule-pair"><h2>위험과 가호</h2><dl>${weeklyRows(trait)}<div class="benefit"><dt>고정 베네핏</dt><dd>${escapeHtml(trait.benefitLabel)}</dd></div></dl></section><section class="archive-behavior"><h2>운영 규칙</h2><p>한국 시간 일요일 오전 5시에 자동 교체되며, 패널티와 베네핏은 항상 한 쌍으로 적용됩니다.</p><p>모든 규칙이 한 번씩 등장하기 전에는 같은 규칙이 반복되지 않습니다.</p></section></article>`;
}
function blessingDetail(id:string):string{
  const blessing=dangunBlessings[id]??Object.values(dangunBlessings)[0];if(!blessing)return '';
  return `<article class="archive-detail archive-rule-detail"><header class="archive-rule-hero blessing"><img src="${images[blessing.image].url}" alt=""><div><span class="archive-record-type">DANGUN'S BLESSING · 5 LEVELS</span><h1>${escapeHtml(blessing.name)}</h1><p>${escapeHtml(blessing.description)}</p></div></header><section class="archive-specs"><h2>레벨당 적용 수치</h2><dl>${blessing.modifiers.map(mod=>`<div><dt>${statNames[mod.stat]}</dt><dd>${mod.operation==='multiply'?`+${Math.round((mod.value-1)*100)}%`:`+${number(mod.value)}`}</dd></div>`).join('')}<div><dt>해금</dt><dd>조각 18</dd></div><div><dt>성장</dt><dd>30 / 45 / 65 / 90</dd></div></dl></section><section class="archive-behavior"><h2>출동 규칙</h2><p>미래전략지원실에서 조각으로 해금하고 성장시킵니다. 출동 전 보유 축복 중 하나를 선택하며, 게이트 안에서는 바꿀 수 없습니다.</p><p>보유 축복이 없으면 축복 없이 출동합니다.</p></section></article>`;
}

function entryList(category: ArchiveCategory, selectedId: string, ids:string[]): string {
  if(category==='items')return rarityOrder.map(rarity=>{
    const listed=ids.filter(id=>items[id]?.rarity===rarity);
    return listed.length?`<h3 class="archive-rarity-heading rarity-${rarity.toLowerCase()}">${rarityNames[rarity]} <small>${rarity}</small></h3>${listed.map(id=>`<button type="button" class="archive-entry archive-item-entry ${id===selectedId?'selected':''}" data-action="archive-entry:items,${id}">${itemArt(id)}<span>${escapeHtml(items[id]!.name)}</span></button>`).join('')}`:'';
  }).join('');
  return ids.map(id=>{
    if(category==='characters'){const value=characters[id]!;return `<button type="button" class="archive-entry ${id===selectedId?'selected':''}" data-action="archive-entry:${category},${id}">${portrait(value.portraitSprite??value.visual.sprite??'player','')}<span>${escapeHtml(value.name)}</span></button>`;}
    if(category==='weapons'){const value=weapons[id]!;return `<button type="button" class="archive-entry ${id===selectedId?'selected':''}" data-action="archive-entry:${category},${id}">${weaponDetailArt(id)}<span>${escapeHtml(value.name)}</span></button>`;}
    if(category==='enemies'){const value=enemies[id]!;return `<button type="button" class="archive-entry ${id===selectedId?'selected':''}" data-action="archive-entry:${category},${id}">${portrait(value.visual.sprite??'brute','')}<span>${escapeHtml(value.name)}</span></button>`;}
    if(category==='weeklyTraits'){const value=weeklyGateRules[id]!,style=`--rule-accent:${value.palette.accent};--rule-glow:${value.palette.glow};--rule-surface:${value.palette.surface}`;return `<button type="button" style="${style}" class="archive-entry archive-rule-entry weekly ${id===selectedId?'selected':''}" data-action="archive-entry:${category},${id}"><img class="archive-symbol" src="${images[value.image].url}" alt=""><span>${escapeHtml(value.name)}</span></button>`;}
    const value=dangunBlessings[id]!;return `<button type="button" class="archive-entry archive-rule-entry ${id===selectedId?'selected':''}" data-action="archive-entry:${category},${id}"><img class="archive-symbol blessing" src="${images[value.image].url}" alt=""><span>${escapeHtml(value.name)}</span></button>`;
  }).join('');
}

export function archiveScreen(view: ArchiveViewState): string {
  const mapIds=Object.keys(maps),mapId=mapIds.includes(view.mapId)?view.mapId:mapIds[0]??'seoul';
  const mapIndex=mapIds.indexOf(mapId);
  const validIds = archiveIds(view.category,mapId);
  const selectedId = validIds.includes(view.selectedId) ? view.selectedId : validIds[0] ?? '';
  const mapSwitcher=`<div class="archive-map-switcher"><button data-action="archive-map:${mapIds[mapIndex-1]??''}" ${mapIndex<=0?'disabled':''} aria-label="이전 맵">‹</button><span>${escapeHtml(maps[mapId]?.name??mapId)} <small>${mapIndex+1}/${mapIds.length}</small></span><button data-action="archive-map:${mapIds[mapIndex+1]??''}" ${mapIndex>=mapIds.length-1?'disabled':''} aria-label="다음 맵">›</button></div>`;
  const detail = !selectedId ? '<article class="archive-detail archive-empty">이 구역에 등록된 자료가 없습니다.</article>' : view.category === 'characters' ? characterDetail(selectedId) : view.category === 'weapons' ? weaponDetail(selectedId) : view.category === 'items' ? itemDetail(selectedId) : view.category === 'enemies' ? enemyDetail(selectedId) : view.category === 'weeklyTraits' ? weeklyTraitDetail(selectedId) : blessingDetail(selectedId);
  const tabs = (Object.keys(categoryNames) as ArchiveCategory[]).map(category => `<button type="button" class="archive-tab ${category === view.category ? 'selected' : ''}" data-action="archive-category:${category}" aria-pressed="${category === view.category}"><span>${categoryNames[category]}</span><small>${archiveIds(category,mapId).length}</small></button>`).join('');
  return `<section class="archive-screen" data-map-id="${escapeHtml(mapId)}" data-category="${view.category}"><header class="archive-header">${lobbyReturnButton()}<div><span>SEOUL HERO ARCHIVE</span><h1>게이트 대응 자료집</h1></div></header><div class="archive-book"><nav class="archive-tabs" aria-label="자료 분류">${tabs}</nav><section class="archive-index"><header><span>${categoryNames[view.category]}</span><b>${String(validIds.length).padStart(2,'0')} FILES</b></header><div class="archive-entry-grid">${entryList(view.category,selectedId,validIds)}</div>${mapSwitcher}</section>${detail}</div></section>`;
}

