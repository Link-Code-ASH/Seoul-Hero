import { images, type ImageId } from '../data/images';
import { maps } from '../data/maps';
import type { MetaState } from '../state/MetaState';
import { escapeHtml } from './helpers';

interface LobbyTile {
  action: 'growth' | 'association' | 'offline' | 'supply';
  title: string;
  image: ImageId;
}

const tiles: readonly LobbyTile[] = [
  { action: 'growth', title: '미래전략지원실', image: 'lobbyFutureStrategy' },
  { action: 'association', title: '협회', image: 'lobbyAssociation' },
  { action: 'offline', title: '오프라인 보상', image: 'lobbyRecoveryUnit' },
  { action: 'supply', title: '보급 상자', image: 'lobbySupplyVault' },
];

export function lobbyScreen(meta: MetaState): string {
  const last = meta.statistics.lastRun;
  const lastMap = last ? maps[last.mapId] : undefined;
  const recent = last
    ? `${escapeHtml(lastMap?.name ?? last.mapId)} · 심도 ${last.gateDepth} · WAVE ${last.reachedWave}`
    : '아직 등록된 작전 기록이 없습니다.';
  const support = tiles.map(tile => `<button class="lobby-module" data-action="${tile.action}">
    <img src="${images[tile.image].url}" alt="">
    <span><b>${tile.title}</b><em aria-hidden="true">↗</em></span>
    <i aria-hidden="true"></i>
  </button>`).join('');

  return `<section class="meta-lobby lobby-command" style="--lobby-bg:url('${images.seoulIntersection.url}')">
    <header class="lobby-head command-head">
      <div class="lobby-identity"><img src="${images.brandPortrait.url}" alt=""><div><h1>서울 히어로</h1><p>게이트 너머, 서울을 지킬 준비를.</p></div></div>
      <nav aria-label="보조 메뉴">
        <button class="lobby-tool" data-action="archive"><img src="${images.lobbyArchive.url}" alt=""><span>자료집</span></button>
        <button class="lobby-tool" data-action="settings"><img src="${images.lobbySettings.url}" alt=""><span>설정</span></button>
      </nav>
    </header>
    <div class="command-status" aria-label="작전 현황">
      <div><img src="${images.lobbyGate.url}" alt=""><span>최고 심도</span><b>${meta.gateProgression.highestUnlockedDepth}</b></div>
      <div><img src="${images.associationCoin.url}" alt=""><span>협회 코인</span><b>${meta.wallet.associationCoins.toLocaleString()}</b></div>
      <div><img src="${images.supplyTicket.url}" alt=""><span>보급권</span><b>${meta.wallet.supplyTickets.toLocaleString()}</b></div>
    </div>
    <main class="command-deck">
      <button class="gate-command-card" data-action="gateMap">
        <img class="gate-command-bg" src="${images.seoulIntersection.url}" alt="">
        <span class="gate-command-shade"></span>
        <img class="gate-command-device" src="${images.lobbyGate.url}" alt="">
        <span class="gate-command-copy"><small>광화문 작전 구역</small><b>게이트 출동</b><em>심도 ${meta.gateProgression.highestUnlockedDepth}까지 진입 가능</em><strong>출동 준비 <span aria-hidden="true">↗</span></strong></span>
        <span class="gate-command-record"><small>최근 작전</small><b>${recent}</b></span>
      </button>
      <div class="command-modules">${support}</div>
    </main>
  </section>`;
}
