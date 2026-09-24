import { AppController } from './core/AppController';
import { enableMobileFullscreenOnTouch } from './ui/MobileFullscreen';
import './styles/main.css';
import './styles/lobby-redesign.css';
import './styles/meta-facilities.css';
import './styles/survival.css';
import './styles/ui-wide.css';
import './styles/ui-modern.css';
import './styles/archive.css';
import './styles/gate-lobby.css';
import './styles/interface-overhaul.css';
import './styles/interface-materials.css';
import './styles/interface-followup.css';
import './styles/account.css';
import './styles/mobile-viewport.css';
import './styles/typography.css';

const world = document.querySelector<HTMLElement>('#world');
const ui = document.querySelector<HTMLElement>('#ui');
if (!world || !ui) throw new Error('게임 화면을 찾을 수 없습니다.');
const game = new AppController(world, ui);
const stopMobileFullscreen = enableMobileFullscreenOnTouch();
game.start().catch((error: unknown) => {
  console.error('Game initialization failed', error);
  ui.textContent = '게임 화면을 시작할 수 없습니다. 최신 Chrome 또는 Edge에서 하드웨어 가속을 켜고 새로고침해 주세요. 저장 기록은 유지됩니다.';
  ui.className = 'startup-error';
});
if (import.meta.hot) import.meta.hot.dispose(() => { stopMobileFullscreen(); game.destroy(); });

if (import.meta.env.PROD && 'serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    void navigator.serviceWorker.register(`${import.meta.env.BASE_URL}sw.js`, {
      scope: import.meta.env.BASE_URL,
    }).catch(error => console.warn('앱 설치 지원을 활성화하지 못했습니다.', error));
  });
}
