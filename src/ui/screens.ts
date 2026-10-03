import { images } from '../data/images';
import type { RunState } from '../state/RunState';
import { button } from './helpers';

export type Screen = 'title' | 'lobby' | 'guild' | 'gateMap' | 'gateDepth' | 'gateCharacter' | 'gateWeapon' | 'gateBlessing' | 'gateConfirm'
  | 'growth' | 'association' | 'offline' | 'supply' | 'archive' | 'settings'
  | 'waveActive' | 'paused' | 'revivalChoice' | 'shop' | 'postWave' | 'result';

export function titleScreen(canContinue:boolean):string{return `<section class="title-screen" style="--title-city:url('${images.titleGate.url}')">
  <div class="title-atmosphere" aria-hidden="true"></div>
  <div class="title-heroes" aria-hidden="true"><img src="${images.titleAwakeners.url}" alt=""></div>
  <div class="title-content"><h1><span>서울</span><strong>히어로</strong></h1>
    <div class="title-actions">${canContinue?button('title-continue','이어하기','primary'):button('title-enter','게임 시작','primary')}</div>
  </div>
</section>`}
export { settingsScreen } from './SettingsScreen';
export function pauseScreen(continueLabel='전투 계속'):string{return `<section class="modal pause-modal"><h1>일시정지</h1><div class="stack">${button('resume',continueLabel,'primary')}${button('end-run','게임 종료','secondary')}</div></section>`}
export { resultScreen } from './ResultScreen';
export function postWaveScreen(run:RunState):string{return `<section class="modal post-wave-modal"><span class="phase-pill">WAVE ${run.currentWave}</span><h1>웨이브 종료</h1></section>`}
export { shopScreen } from './ShopScreen';
