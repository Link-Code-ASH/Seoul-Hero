import { weapons } from '../../src/data/weapons';
import { images, type ImageId } from '../../src/data/images';

// Read-only design study: no controller, storage, audio or gameplay imports.
const weaponImages: Record<string, ImageId> = {
  manaSword: 'weaponManaSword', guardianDaggers: 'weaponGuardianShuriken',
  manaBolt: 'weaponManaBolt', manaShotgun: 'weaponManaShotgun',
  piercingShot: 'weaponPiercingShot', chainLightning: 'weaponChainLightning',
  manaBombard: 'weaponManaBombard', autoTurret: 'weaponAutoTurret',
  mineLayer: 'weaponMineLayer', manaField: 'weaponManaField',
};
const escape = (value: string) => value.replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]!);
const img = (id: ImageId, className = '', alt = '') => `<img class="${className}" src="${images[id].url}" alt="${escape(alt)}" draggable="false">`;
const num = (n: number) => new Intl.NumberFormat('ko-KR', { maximumFractionDigits: 2 }).format(n);
const sword = weapons.manaSword!;
const weaponOrder = ['manaSword', 'guardianDaggers', 'manaBolt', 'piercingShot', 'chainLightning', 'manaBombard', 'manaShotgun'];
const position = (x: number, y: number, w: number, h: number) => `left:${x}px;top:${y}px;width:${w}px;height:${h}px`;

function lobby() {
  const menus: { name: string; image: ImageId; scene?: ImageId; x: number; y: number }[] = [
    { name: '게이트 출동', image: 'lobbyGate', x: 24, y: 52 },
    { name: '길드 본부', image: 'guildOperatorLobbyFace', scene: 'guildCafeBackdrop', x: 322, y: 52 },
    { name: '미래전략지원실', image: 'lobbyFutureStrategy', x: 622, y: 52 },
    { name: '협회', image: 'lobbyAssociation', x: 24, y: 216 },
    { name: '오프라인 보상', image: 'lobbyRecoveryUnit', x: 322, y: 216 },
    { name: '보급 상자', image: 'lobbySupplyVault', x: 622, y: 216 },
  ];
  return `<section class="artboard lobby" aria-label="로비 시안">
    <header class="lobby-header"><h1>서울 히어로</h1>
      <div class="lobby-resources">${img('associationCoin')}<span>0</span>${img('supplyTicket')}<span>0</span></div>
      <button class="text-control">자료집</button><button class="text-control">설정</button><button class="text-control music">음악 <b>ON</b></button>
    </header>
    ${menus.map((menu, index) => `<button class="glass-menu menu-${index}" style="${position(menu.x,menu.y,268,137)}" aria-label="${menu.name}">
      ${menu.scene ? img(menu.scene, 'menu-scene') : ''}
      ${img(menu.image, 'menu-object')}
      <span class="menu-title">${menu.name}</span><span class="menu-arrow" aria-hidden="true">›</span>
    </button>`).join('')}
  </section>`;
}

function weaponSelection() {
  const x = [18, 167, 314, 461];
  return `<section class="artboard weapons" aria-label="무기 선택 시안">
    <header class="equipment-header"><button class="text-control back">‹ 이전</button><h1>시작 무기</h1><span>편성 04 / 06</span></header>
    ${weaponOrder.map((id, index) => {
      const weapon = weapons[id]!;
      return `<button class="weapon-slot ${index === 0 ? 'selected' : ''}" style="${position(x[index%4]!, index<4?54:211, 135, 137)}" aria-pressed="${index===0}">
        ${img(weaponImages[id]!, 'weapon-art', weapon.name)}
        ${index === 0 ? '<span class="selection-word">선택됨</span>' : ''}
        <span class="weapon-name">${escape(weapon.name)}</span>
      </button>`;
    }).join('')}
    <div class="spare-slot" style="${position(461,211,135,137)}"><span>장비 대기</span></div>
    <aside class="selected-weapon">
      <div class="weapon-detail-top"><span>근접 · 범위 공격</span><b>Lv.1</b></div>
      ${img('weaponManaSword','selected-weapon-art')}
      <h2>${escape(sword.name)}</h2>
      <p>${escape(sword.description)}</p>
      <dl class="weapon-specs"><div><dt>기본 피해</dt><dd>${num(sword.base.damage)}</dd></div><div><dt>공격 주기</dt><dd>${num(sword.base.cooldown)}<small>초</small></dd></div><div><dt>사거리</dt><dd>${num(sword.base.range)}</dd></div></dl>
    </aside>
    <button class="weapon-confirm">이 무기 선택 <span>›</span></button>
    <footer class="equipment-footer"><span>공용 전투 장비</span><span>선택한 무기 Lv.1 지급</span></footer>
  </section>`;
}

function archive() {
  const categories = ['캐릭터', '무기', '몬스터', '아이템', '주간 특성', '단군의 축복'];
  return `<section class="artboard archive" aria-label="자료집 시안">
    <header class="archive-header"><h1>자료집</h1><button class="document-back">‹ 이전</button></header>
    <nav class="archive-tabs" aria-label="분류">${categories.map((name,index)=>`<button class="archive-tab ${index===1?'selected':''}" style="top:${78+index*48}px" aria-pressed="${index===1}">${name}</button>`).join('')}</nav>
    <div class="archive-index"><header><h1>무기</h1><span>${Object.keys(weapons).length}</span></header><div class="archive-names">${Object.values(weapons).map(w=>`<button class="archive-name ${w.id==='manaSword'?'selected':''}" aria-pressed="${w.id==='manaSword'}">${escape(w.name)}</button>`).join('')}</div></div>
    <nav class="map-control" aria-label="맵 전환"><button disabled aria-label="이전 맵">‹</button><span>광화문</span><button disabled aria-label="다음 맵">›</button></nav>
    <article class="archive-document">
      <header><h2>${escape(sword.name)}</h2><span>Lv.${sword.branchAtLevel} 분기 · 최대 Lv.${sword.maxLevel}</span></header>
      <div class="document-hero">${img('weaponManaSword')}<div><span class="document-type">근접 · 범위 · 치명타</span><p>${escape(sword.description)}</p></div></div>
      <div class="document-stats"><h3>Lv.1 기본 수치</h3><dl><div><dt>피해량</dt><dd>${num(sword.base.damage)}</dd></div><div><dt>공격 주기</dt><dd>${num(sword.base.cooldown)}초</dd></div><div><dt>사거리</dt><dd>${num(sword.base.range)}</dd></div><div><dt>검격 각도</dt><dd>${num((sword.attackAngle??Math.PI/3)*180/Math.PI)}°</dd></div></dl></div>
      <section class="document-branches"><header><h3>성장 분기</h3><span>Lv.${sword.branchAtLevel} 선택 · 최대 Lv.${sword.maxLevel}</span></header>${sword.branches.map(branch=>`<div class="branch"><strong>${branch.id} <span>${escape(branch.name)}</span></strong><p>${escape(branch.description)}</p></div>`).join('')}</section>
    </article>
  </section>`;
}

const screens = { lobby, weapons: weaponSelection, archive };
const titles = { lobby: '01 / 로비', weapons: '02 / 무기 선택', archive: '03 / 자료집' };
const subtitles = { lobby: '위기의 서울 · 길드만 따뜻한 쉼터', weapons: '장비 / 명판 / 수치 / 조작 분리', archive: '분류 / 목록 / 이미지 / 정보 구획' };
const params = new URLSearchParams(location.search);
const screen = params.get('screen') || 'lobby';
const exporting = params.has('export');
document.body.classList.toggle('export', exporting);
document.body.classList.toggle('comparison', screen === 'compare');
const ids = screen in screens ? [screen as keyof typeof screens] : Object.keys(screens) as (keyof typeof screens)[];
const root = document.querySelector<HTMLElement>('#preview')!;
root.innerHTML = ids.map(id=>`<section class="preview-card"><header class="caption"><strong>${titles[id]}</strong><span>${subtitles[id]}</span></header><div class="artboard-viewport">${screens[id]()}</div></section>`).join('');

function resize() {
  const comparison = document.body.classList.contains('comparison');
  const mobile = innerWidth <= 1000;
  const scale = exporting ? (comparison ? 2/3 : 2) : comparison ? Math.min(1,(innerWidth-64)/3/915) : Math.min(2,(innerWidth-(mobile?0:40))/915,(innerHeight-(mobile?44:140))/412);
  root.style.setProperty('--art-scale', String(scale));
  root.style.setProperty('--art-width', `${915*scale}px`);
  root.style.setProperty('--art-height', `${412*scale}px`);
}
addEventListener('resize', resize);
resize();
await document.fonts.ready;
await Promise.all(Array.from(document.images).map(image => image.decode().catch(()=>{})));
document.documentElement.dataset.ready = 'true';
