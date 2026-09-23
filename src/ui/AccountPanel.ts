import type { SaveData } from '../save/SaveData';
import { escapeHtml } from './helpers';

export interface AccountChoice { local: SaveData; remote: SaveData | null; reason: 'first' | 'conflict' }
export interface AccountView { email: string; status: string; choice: AccountChoice | null }

const summary = (save: SaveData) => `심도 ${save.meta.gateProgression.highestUnlockedDepth} · 협회 코인 ${save.meta.wallet.associationCoins.toLocaleString()} · 출동 ${save.meta.statistics.runs}회`;

export function accountPanel(view: AccountView): string {
  const signedIn = Boolean(view.email);
  return `<div class="account-strip"><span><b>${signedIn ? escapeHtml(view.email) : '게스트'}</b><small>${escapeHtml(view.status)}</small></span>
    <button type="button" data-action="${signedIn ? 'account-signout' : 'account-signin'}">${signedIn ? '로그아웃' : 'Google 로그인'}</button></div>
    ${view.choice ? `<div class="account-choice-backdrop"><section class="account-choice" role="dialog" aria-modal="true" aria-label="저장 기록 선택">
      <h2>${view.choice.reason === 'conflict' ? '두 기기의 기록이 다릅니다' : '사용할 진행 기록 선택'}</h2>
      <p>선택하지 않은 기록은 이 기기에 백업됩니다. 자동으로 합치지 않습니다.</p>
      <div><button type="button" data-action="account-use-cloud" ${view.choice.remote ? '' : 'disabled'}><b>클라우드 기록</b><small>${view.choice.remote ? summary(view.choice.remote) : '기록 없음'}</small></button>
      <button type="button" data-action="account-upload-local"><b>이 기기 기록</b><small>${summary(view.choice.local)}</small></button></div>
      <button type="button" class="account-choice-export" data-action="export">선택 전 JSON 백업</button>
    </section></div>` : ''}`;
}
