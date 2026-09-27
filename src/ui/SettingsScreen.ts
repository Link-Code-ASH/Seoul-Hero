import type { MetaState } from '../state/MetaState';
import { images } from '../data/images';
import { button } from './helpers';
import { lobbyReturnButton } from './LobbyNavigation';
export function settingsScreen(meta:MetaState):string {
  const s=meta.settings;
  const slider=(id:string,label:string,value:number)=>`<label class="setting-row"><span>${label}</span><div class="volume-control"><input aria-label="${label}" type="range" min="0" max="1" step="0.05" value="${value}" data-setting="${id}"><output>${Math.round(value*100)}%</output></div></label>`;
  return `<section class="settings-facility"><header>${lobbyReturnButton()}<h1>설정</h1></header><main class="settings-console"><aside class="settings-hero"><img src="${images.lobbySettings.url}" alt=""><nav>${([['audio','음향'],['display','화면'],['account','계정'],['data','데이터']] as const).map(([id,label])=>button('settings-tab:'+id,label,'settings-tab',`aria-pressed="${id==='audio'}"`)).join('')}</nav></aside><div class="settings-panels">
    <section class="settings-card" data-settings-panel="audio"><h2>음향</h2>${slider('masterVolume','전체 음량',s.masterVolume)}${slider('musicVolume','음악',s.musicVolume)}${slider('combatVolume','전투 효과음',s.combatVolume)}${slider('uiVolume','UI 효과음',s.uiVolume)}<label class="setting-row"><span>배경음악 끄기</span><input type="checkbox" data-setting="muted" ${s.muted?'checked':''}></label></section>
    <section class="settings-card" data-settings-panel="display" hidden><h2>화면</h2><label class="setting-row"><span>고해상도</span><input type="checkbox" data-setting="highResolution" ${s.highResolution?'checked':''}></label><label class="setting-row"><span>개발자 모드</span><input type="checkbox" data-setting="developerMode" ${s.developerMode?'checked':''}></label>${button('fullscreen','화면 채우기')}</section>
    <section class="settings-card" data-settings-panel="account" hidden><h2>계정 동기화</h2><div class="settings-account-slot"></div></section>
    <section class="settings-card" data-settings-panel="data" hidden><h2>진행 기록</h2><div class="button-row">${button('export','백업 내보내기')}<label class="button file-button">백업 가져오기<input id="save-file" type="file" accept="application/json,.json"></label></div><div class="danger-zone">${button('reset','저장 초기화','danger')}<p>모든 영구 진행 기록을 지웁니다.</p></div></section>
    </div></main></section>`;
}
