import { images, type ImageId } from '../data/images';
import { maps } from '../data/maps';
import type { MetaState } from '../state/MetaState';
import { escapeHtml } from './helpers';
const facilities: readonly {action:string;title:string;image:ImageId}[] = [
  {action:'growth',title:'미래전략지원실',image:'lobbyFutureStrategy'},
  {action:'association',title:'협회',image:'lobbyAssociation'},
  {action:'offline',title:'오프라인 보상',image:'lobbyRecoveryUnit'},
  {action:'supply',title:'보급 상자',image:'lobbySupplyVault'},
];
export function lobbyScreen(meta:MetaState):string {
  const last=meta.statistics.lastRun;
  const recent=last?`${escapeHtml(maps[last.mapId]?.name??last.mapId)} · 심도 ${last.gateDepth} · WAVE ${last.reachedWave}`:'';
  return `<section class="headquarters" style="--scene:url('${images.titleGate.url}')">
    <header class="hq-header"><div class="hq-resources"><span><img src="${images.associationCoin.url}" alt="협회 코인"><b>${meta.wallet.associationCoins.toLocaleString()}</b></span><span><img src="${images.supplyTicket.url}" alt="보급권"><b>${meta.wallet.supplyTickets.toLocaleString()}</b></span></div><nav><button data-action="archive">자료집</button><button data-action="settings">설정</button></nav></header>
    <main class="hq-scene"><div class="hq-brief"><span class="overline">GWANGHWAMUN</span><h1>서울의 밤은<br>아직 끝나지 않았다.</h1><p>${recent?`최근 작전 · ${recent}`:'게이트 너머, 서울을 지킬 준비를.'}</p></div>
      <button class="hq-guild" data-action="guild"><img src="${images.guildOperatorLobbyFace.url}" alt="한서아"><span>길드 본부 <b>↗</b></span></button>
      <button class="hq-deploy" data-action="gateMap"><img src="${images.lobbyGate.url}" alt=""><span><small>심도 ${meta.gateProgression.highestUnlockedDepth}까지 개방</small><strong>게이트 출동</strong></span><b>→</b></button>
    </main><nav class="hq-facilities" aria-label="시설">${facilities.map(f=>`<button data-action="${f.action}"><img src="${images[f.image].url}" alt=""><span>${f.title}</span><b>↗</b></button>`).join('')}</nav>
  </section>`;
}
