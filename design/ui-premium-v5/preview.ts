import { weapons } from '../../src/data/weapons';
import { images, type ImageId } from '../../src/data/images';
import { tags, appliedStats, resolved, growthRows } from './weapon-info';
import { weaponNotes } from './weapon-notes';
import { mountAtmosphere } from './atmosphere';
import type { Weapon } from '../../src/data/types';

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
const weaponOrder = ['manaSword', 'guardianDaggers', 'manaBolt', 'piercingShot', 'chainLightning', 'manaBombard', 'manaShotgun'];
const position = (x: number, y: number, w: number, h: number) => `left:${x}px;top:${y}px;width:${w}px;height:${h}px`;

let selectedWeapon='manaSword';
let archiveWeapon='manaSword';
let branch: string|undefined;
let detailTab='overview';
let growthPage=0;
const tagHTML=(weapon:Weapon)=>{const traits=tags(weapon);return `<div class="trait-family"><strong>${escape(traits[0]??'공용')}</strong><span>전투 장비</span></div><div class="trait-detail">${traits.slice(1).map(escape).join(' · ')}</div>`;};
function dockIcon(index:number){
  const [x,y,w,h]=[[0,150,445,480],[450,150,360,480],[825,150,362,480],[1190,150,405,480],[1595,264,388,370]][index]!;
  const scale=Math.min(56/w,60/h),width=w*scale,height=h*scale;
  return `<span class="dock-icon" style="left:${(58-width)/2}px;top:${55-height}px;width:${width}px;height:${height}px;background-size:${1983*scale}px ${793*scale}px;background-position:${-x*scale}px ${-y*scale}px"></span>`;
}
const sceneNames=['rain','wind','energy','checkpoint','rooftop'];
const effectNames=['rain','wind','energy','snow','mist','embers'];
const requestedEffect=new URLSearchParams(location.search).get('effect');
const effect=effectNames.includes(requestedEffect??'')?requestedEffect!:effectNames[Math.floor(Math.random()*effectNames.length)]!;
const chosenScene=new URLSearchParams(location.search).get('scene');
const scene=sceneNames.includes(chosenScene??'')?chosenScene!:sceneNames[Math.floor(Math.random()*sceneNames.length)]!;
function lobby(){
  const destinations=['길드 본부','성장','협회','오프라인 보상','보급 상자'];
  return `<section class="artboard lobby" data-scene="${scene}" style="background-image:url(./assets/lobby-${scene}.png)"><canvas class="atmosphere" width="915" height="412" aria-hidden="true"></canvas><h1 class="lobby-title">서울 히어로</h1>
    <header class="lobby-controls"><div class="resource">${img('associationCoin')}<b>0</b></div><div class="resource">${img('supplyTicket')}<b>0</b></div><a href="?screen=archive">자료집</a><button>설정</button><button>음악 <b>ON</b></button></header>
    <nav class="facility-dock" aria-label="시설">${destinations.map((name,i)=>`<button aria-label="${name}" title="${name}" class="dock-button">${dockIcon(i)}</button>`).join('')}</nav>
    <a class="deploy-button" href="?screen=weapons"><img class="gate-emblem" src="./assets/deployment.png" alt=""><span>작전 투입</span></a>
  </section>`;
}
function weaponSelection(){
  const x=[18,167,314,461];const w=weapons[selectedWeapon]!;
  return `<section class="artboard weapons"><header class="equipment-header"><a class="text-control back" href="?screen=lobby">‹ 이전</a><h1>시작 무기</h1><span>편성 04 / 06</span></header>
  ${weaponOrder.map((id,index)=>`<button data-weapon="${id}" class="weapon-slot ${id===selectedWeapon?'selected':''}" style="${position(x[index%4]!,index<4?54:211,135,137)}" aria-label="${escape(weapons[id]!.name)}" aria-pressed="${id===selectedWeapon}">${img(weaponImages[id]!,'weapon-art')}<span class="weapon-name">${escape(weapons[id]!.name)}</span></button>`).join('')}
  <aside class="selected-weapon">${img(weaponImages[w.id]!,'selected-weapon-art')}<h2>${escape(w.name)}</h2><div class="weapon-traits">${tagHTML(w)}</div></aside>
  <button class="weapon-confirm">선택</button>
  </section>`;
}
function growthTable(weapon:Weapon){
  const angle=(s:ReturnType<typeof resolved>)=>weapon.behavior==='slash'?s.attackAngle*180/Math.PI:weapon.behavior==='bombard'?s.blastRadius:s.projectileCount;
  const columns=[{title:'피해',value:(s:ReturnType<typeof resolved>)=>s.damage},{title:'주기(초)',value:(s:ReturnType<typeof resolved>)=>s.cooldown},{title:'사거리',value:(s:ReturnType<typeof resolved>)=>s.range},{title:weapon.behavior==='slash'?'각도(°)':weapon.behavior==='bombard'?'반경':'개수',value:angle},{title:'반복',value:(s:ReturnType<typeof resolved>)=>s.repeatCount}];
  return `<table><thead><tr><th>Lv.</th>${columns.map(c=>`<th>${c.title}</th>`).join('')}</tr></thead><tbody>${growthRows(weapon,branch).slice(growthPage*3,growthPage*3+3).map(row=>`<tr><th>${row.level}</th>${columns.map(c=>{const val=c.value(row.stats),delta=row.previous?val-c.value(row.previous):0;return `<td>${num(val)}${Math.abs(delta)>.001?`<small>${delta>0?'+':''}${num(delta)}</small>`:''}</td>`}).join('')}</tr>`).join('')}</tbody></table>`;
}
function archive(){
  const w=weapons[archiveWeapon]!;const note=weaponNotes[w.id];const stats=resolved(w,1);const chosen=w.branches.find(b=>b.id===branch);
  return `<section class="artboard archive"><header class="archive-header"><h1>자료집</h1><a class="document-back" href="?screen=lobby">‹ 이전</a></header>
  <nav class="archive-tabs">${['캐릭터','무기','몬스터','아이템','주간 특성','단군의 축복'].map((name,i)=>`<button class="archive-tab ${i===1?'selected':''}" style="top:${78+i*48}px">${name}</button>`).join('')}</nav>
  <div class="archive-index"><header><h1>무기</h1><span>${Object.keys(weapons).length}</span></header><div class="archive-names">${Object.values(weapons).map(item=>`<button data-archive="${item.id}" class="archive-name ${item.id===w.id?'selected':''}" aria-pressed="${item.id===w.id}">${escape(item.name)}</button>`).join('')}</div></div>
  <nav class="map-control"><button disabled>‹</button><span>광화문</span><button disabled>›</button></nav>
  <article class="archive-document mode-${detailTab==='overview'?'overview':'stats'}"><header><h2>${escape(w.name)}</h2></header>
  <nav class="detail-tabs" aria-label="상세 정보"><button data-detail="overview" aria-pressed="${detailTab==='overview'}">특징</button><button data-detail="common" aria-pressed="${detailTab==='common'}">기본 성장</button>${w.branches.map(b=>`<button data-detail="${b.id}" aria-pressed="${detailTab===b.id}">분기 ${b.id}</button>`).join('')}</nav>
  ${detailTab==='overview'?`<div class="detail-overview"><div class="overview-art">${img(weaponImages[w.id]!)}</div><div class="overview-copy"><h3>${escape(w.description)}</h3>${tagHTML(w)}<p>${escape(note?.note??w.description)}</p><p class="applied">적용 능력 · ${appliedStats(w).map(escape).join(' · ')}</p></div><blockquote>“${escape(note?.quote??'현장의 기록은 다음 출동을 지킵니다.')}”</blockquote></div>`:
  `<section class="detail-growth"><h3>${chosen?escape(chosen.name):'공통 성장'}</h3><p class="branch-description">${chosen?escape(chosen.description):'분기 전 기본 강화 · 증감은 직전 레벨 대비'}</p>${growthTable(w)}<nav class="level-pages">${Array.from({length:Math.ceil(growthRows(w,branch).length/3)},(_,i)=>{const rows=growthRows(w,branch).slice(i*3,i*3+3);return `<button data-growth-page="${i}" aria-pressed="${growthPage===i}">Lv.${rows[0]!.level}–${rows[rows.length-1]!.level}</button>`}).join('')}</nav></section>`}
  </article></section>`;
}
const screens={lobby,weapons:weaponSelection,archive};
const titles={lobby:'01 / 로비',weapons:'02 / 무기 선택',archive:'03 / 자료집'};
const subtitles={lobby:'열린 서울 배경 · 시설 아이콘 · 별도 출동',weapons:'장비 특성 · 간결한 선택',archive:'특징과 현장 한 줄 · 하단 성장 수치'};
const params=new URLSearchParams(location.search);
const screen=params.get('screen')||'lobby';
branch=params.get('branch')||undefined;
if(params.has('growth'))detailTab=branch??'common';
const exporting=params.has('export');
document.body.classList.toggle('export',exporting);
document.body.classList.toggle('comparison',screen==='compare');
const ids=screen in screens?[screen as keyof typeof screens]:Object.keys(screens) as (keyof typeof screens)[];
const root=document.querySelector<HTMLElement>('#preview')!;
let stopAtmosphere=()=>{};
function render(){stopAtmosphere();root.innerHTML=ids.map(id=>`<section class="preview-card"><header class="caption"><strong>${titles[id]}</strong><span>${subtitles[id]}</span></header><div class="artboard-viewport">${screens[id]()}</div></section>`).join('');const canvas=root.querySelector<HTMLCanvasElement>('.atmosphere');if(canvas)stopAtmosphere=mountAtmosphere(canvas,effect);}
function resize(){const comparison=screen==='compare',mobile=innerWidth<=1000;const scale=exporting?(comparison?2/3:2):comparison?Math.min(1,(innerWidth-64)/3/915):Math.min(2,(innerWidth-(mobile?0:40))/915,(innerHeight-(mobile?44:140))/412);root.style.setProperty('--art-scale',String(scale));root.style.setProperty('--art-width',`${915*scale}px`);root.style.setProperty('--art-height',`${412*scale}px`);}
root.addEventListener('click',event=>{const button=(event.target as HTMLElement).closest<HTMLElement>('button');if(!button)return;
  if(button.dataset.weapon){selectedWeapon=button.dataset.weapon;render();}
  if(button.dataset.archive){const scroll=root.querySelector('.archive-names')?.scrollTop??0;archiveWeapon=button.dataset.archive;branch=undefined;detailTab='overview';growthPage=0;render();root.querySelector('.archive-names')!.scrollTop=scroll;}
  if(button.dataset.branch!==undefined){const scroll=root.querySelector('.archive-names')?.scrollTop??0;branch=button.dataset.branch||undefined;render();root.querySelector('.archive-names')!.scrollTop=scroll;}
  if(button.dataset.detail){detailTab=button.dataset.detail;branch=['overview','common'].includes(detailTab)?undefined:detailTab;growthPage=0;render();}
  if(button.dataset.growthPage!==undefined){growthPage=Number(button.dataset.growthPage);render();}
});
render();resize();addEventListener('resize',resize);
await document.fonts.ready;await Promise.all(Array.from(document.images).map(image=>image.decode().catch(()=>{})));document.documentElement.dataset.ready='true';


for(const [id,key,value] of [['background-choice','scene',scene],['effect-choice','effect',effect]]){const select=document.getElementById(id!) as HTMLSelectElement;select.value=value!;select.addEventListener('change',()=>{const url=new URL(location.href);url.searchParams.set('screen','lobby');if(select.value)url.searchParams.set(key!,select.value);else url.searchParams.delete(key!);location.href=url.href;});}
