import { images, type ImageId } from '../data/images';
import type { MetaState } from '../state/MetaState';
const menus: readonly {action:string;title:string;image:ImageId;scene:ImageId;position?:string}[] = [
  {action:'gateMap',title:'게이트 출동',image:'lobbyGate',scene:'seoulIntersection',position:'center 8%'},
  {action:'guild',title:'길드 본부',image:'guildOperatorLobbyFace',scene:'guildCafeBackdrop',position:'center 16%'},
  {action:'growth',title:'미래전략지원실',image:'lobbyFutureStrategy',scene:'metaGrowthLab'},
  {action:'association',title:'협회',image:'lobbyAssociation',scene:'metaAssociationOffice'},
  {action:'offline',title:'오프라인 보상',image:'lobbyRecoveryUnit',scene:'metaOfflineTerminal'},
  {action:'supply',title:'보급 상자',image:'lobbySupplyVault',scene:'metaSupplyVault'},
];
export function lobbyScreen(meta:MetaState):string {
  return `<section class="headquarters" style="--scene:url('${images.titleGate.url}')">
    <header class="hq-header"><div class="hq-resources"><span><img src="${images.associationCoin.url}" alt="협회 코인"><b>${meta.wallet.associationCoins.toLocaleString()}</b></span><span><img src="${images.supplyTicket.url}" alt="보급권"><b>${meta.wallet.supplyTickets.toLocaleString()}</b></span></div><nav><button data-action="archive">자료집</button><button data-action="settings">설정</button></nav></header>
    <main class="hq-content"><div class="hq-brief"><span class="overline">GWANGHWAMUN</span><h1>서울의 밤은<br>아직 끝나지 않았다.</h1></div>
      <nav class="hq-menu" aria-label="주요 메뉴">${menus.map(menu=>`<button data-action="${menu.action}" style="--card-scene:url('${images[menu.scene].url}');--card-position:${menu.position??'center'}"><img src="${images[menu.image].url}" alt=""><span class="hq-menu-copy"><strong>${menu.title}</strong></span></button>`).join('')}</nav>
    </main>
  </section>`;
}
