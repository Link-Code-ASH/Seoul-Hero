import { REVIVAL_STONE_GRADES, REVIVAL_STONES, REVIVAL_STONE_LORE } from '../data/revivalStones';
import { images } from '../data/images';
import type { MetaState } from '../state/MetaState';
import { button, escapeHtml } from './helpers';

export function revivalScreen(meta: MetaState): string {
  const choices = REVIVAL_STONE_GRADES.map(grade => {
    const stone = REVIVAL_STONES[grade];
    const count = meta.wallet.revivalStones[grade];
    return `<button class="revival-choice ${grade}" data-action="revival-use:${grade}" ${count < 1 ? 'disabled' : ''} aria-label="${stone.name} 사용, 체력 ${Math.round(stone.healthFraction * 100)}%로 부활, 보유 ${count}개">
      <span class="revival-grade">${stone.grade}</span><img src="${images[stone.image].url}" alt=""><strong>${stone.name}</strong>
      <span class="revival-recovery">체력 ${Math.round(stone.healthFraction * 100)}%</span><small>보유 ${count}</small>
    </button>`;
  }).join('');
  return `<section class="revival-screen" aria-labelledby="revival-title"><header><span>AWAKENER RECOVERY</span><h1 id="revival-title">마력핵 붕괴</h1><p>${escapeHtml(REVIVAL_STONE_LORE)}</p></header>
    <div class="revival-choices">${choices}</div><footer>${button('revival-decline','부활하지 않고 출동 종료','revival-decline')}</footer></section>`;
}
