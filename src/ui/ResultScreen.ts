import type { BalanceRunSummary } from '../analytics/BalanceTelemetry';
import { images } from '../data/images';
import { weapons } from '../data/weapons';
import { characters } from '../data/characters';
import { calculateStageReward } from '../meta/StageReward';
import type { RunState } from '../state/RunState';
import { button, escapeHtml, formatTime } from './helpers';
import { weaponDetailArt } from './InventoryArt';
export function resultScreen(run:RunState,summary:BalanceRunSummary|null=null):string {
  const clear=run.phase==='stageClear', reward=run.reward??calculateStageReward(run);
  const recorded=summary?.weapons.filter(w=>w.damage>0)??[];
  const total=recorded.reduce((n,w)=>n+w.damage,0);
  const contribution=recorded.sort((a,b)=>b.damage-a.damage).slice(0,3).map(w=>`<div class="result-weapon">${weaponDetailArt(w.id)}<span><b>${escapeHtml(weapons[w.id]?.name??w.id)}</b><small>Lv.${w.level}${w.branchId?' · '+w.branchId:''}</small><meter min="0" max="${total}" value="${w.damage}" aria-label="기록된 피해 비중"></meter></span><strong>${Math.round(w.damage/total*100)}%</strong></div>`).join('');
  const character=characters[run.characterId];
  return `<section class="operation-result ${clear?'victory':''}"><div class="result-portrait"><img src="${images[character?.portraitSprite??'player'].url}" alt=""><span>DEPTH ${run.gateDepth}</span></div><div class="result-report"><header><small>${clear?'GATE SECURED':'OPERATION ENDED'}</small><h1>${clear?'게이트 봉쇄 완료':'출동 종료'}</h1></header><div class="result-award"><img src="${images.associationCoin.url}" alt="협회 코인"><strong>+${Math.floor(run.earnedAssociationCoins)}</strong></div><div class="result-facts"><span><b>${reward.completedWaves}/${run.totalWaves}</b>완료 Wave</span><span><b>${run.kills}</b>처치</span><span><b>${formatTime(run.stageCombatTime)}</b>전투 시간</span></div><section class="result-contributions"><h2>기록된 무기 피해</h2>${contribution||'<p>기록된 피해가 없습니다.</p>'}</section><footer>${button('gateMap','다시 출동','primary')}${button('association','협회')}${button('lobby','이전','quiet')}</footer></div></section>`;
}
