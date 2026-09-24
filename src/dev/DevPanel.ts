import { items } from '../data/items';
import { metaUpgrades } from '../data/meta';
import { weapons } from '../data/weapons';
import { WEAPON_CONFIG } from '../data/weaponConfig';
import { eliteModifiers } from '../data/eliteModifiers';
import { DEFAULT_STATS } from '../data/stats';
import { maps } from '../data/maps';
import { sfx } from '../data/audio';
import { enemies } from '../data/enemies';
import { SAVE_VERSION } from '../save/SaveData';
import { REVIVAL_STONES } from '../data/revivalStones';
import type { RunState } from '../state/RunState';
import { button, formatTime } from '../ui/helpers';
export interface DebugMetrics { fps: number; frameTime: number; timeScale: number; saveStatus: string; audio: string }
export class DevPanel {
  readonly element = document.createElement('aside');
  private readonly stats: HTMLElement;
  private readonly playerStats: HTMLElement;
  constructor() {
    this.element.className = 'dev-panel';
    this.element.hidden = true;
    this.element.innerHTML = `<details open><summary>개발자 도구 <span>F3</span></summary><pre></pre><div class="dev-controls">${button('dev:balance-export','밸런스 기록 내보내기')}${button('dev:balance-clear','밸런스 기록 초기화')}${button('dev:offline-1h','오프라인 +1시간')}${button('dev:offline-12h','오프라인 +12시간')}${button('dev:offline-generate','미수령 보상 생성')}${button('dev:supply-tickets','보급권 +10')}${button('dev:walk-left', '← 걷기 2초')}${button('dev:walk-right', '걷기 2초 →')}${button('dev:wave-end', '현재 Wave 종료')}${button('dev:wave-next', '다음 Wave 이동')}<label>Wave 번호<input id="dev-wave" aria-label="이동할 Wave 번호" type="number" min="1" value="10"></label>${button('dev:wave-go', '지정 Wave 이동')}${button('dev:invincible', '무적 전환')}<select id="dev-weapon" aria-label="시험할 무기">${Object.values(weapons).map(w => `<option value="${w.id}">${w.name}${w.signatureOwnerId ? ' (고유)' : ''}</option>`).join('')}</select>${button('dev:weapon-get', '일반 무기 획득')}${button('dev:weapon-up', '보유 무기 강화')}${button('dev:branch-test', '선택 무기 Lv.5 분기')}${button('dev:max-a', '모든 무기 Lv.10 A')}${button('dev:max-b', '모든 무기 Lv.10 B')}${button('dev:structure-place','설치물 즉시 생성')}${button('dev:structure-clear','설치물 제거')}<label>설치물 최대 수 추가<input id="dev-structure-limit" type="number" min="0" max="20" value="1"></label>${button('dev:structure-limit','최대 수 보정 적용')}<small>포탑: Damage/공속/원거리/치명/사거리/탄속 · 지뢰: Damage/Area/설치 공속 · 마력장: Damage/Area/Duration/tick 공속. 이동·방어·회피·재생·획득범위·흡혈 기본 미적용.</small>${button('dev:weapon-reset', '시작 무기만 남기기')}<input id="dev-luck" aria-label="시험 Luck" type="number" min="0" value="100">${button('dev:luck', 'Luck 적용')}${button('dev:heal', 'HP 회복')}${button('dev:run-money','이번 판 마력석 +500')}${button('dev:shop-open','상점 강제 열기')}<select id="dev-item" aria-label="시험 아이템">${Object.values(items).map(i=>'<option value="'+i.id+'">'+i.name+'</option>').join('')}</select>${button('dev:item-add','선택 아이템 지급')}${button('dev:item-clear','Run 아이템 전체 제거')}<select id="dev-rarity" aria-label="상품 등급 시험">${['COMMON','UNCOMMON','RARE','LEGENDARY'].map(r=>'<option>'+r+'</option>').join('')}</select>${button('dev:shop-rarity','등급 상품 전시')}<small>전시 시험은 해금 전에도 보이지만 구매 규칙은 유지합니다.</small><select id="dev-meta-upgrade" aria-label="코인샵 상품 시험">${Object.values(metaUpgrades).map(m=>'<option value="'+m.id+'">'+m.name+'</option>').join('')}</select>${button('dev:meta-upgrade','코인샵 상품 지급')}<select id="dev-unlock-target" aria-label="해금 종류"><option value="character">캐릭터</option><option value="weapon">무기</option><option value="item">아이템</option></select><input id="dev-unlock-id" aria-label="해금 ID" value="">${button('dev:unlock','ID 해금')}${button('dev:force-clear','Stage Clear 강제')}${button('dev:force-over','Game Over 강제')}${button('dev:reward-preview','보상 재계산 미리보기')}<small>Curse는 아래 공통 스탯에서 curse 선택. 저장 백업/복원/초기화는 메인 설정에서 제공합니다.</small>${button('dev:currency', '마력석 +500')}${button('dev:clear', '모든 적 처치')}${button('dev:boss', 'Boss Wave 이동')}<select id="dev-enemy" aria-label="생성할 적">${Object.values(enemies).map(enemy => `<option value="${enemy.id}">${enemy.name}</option>`).join('')}</select><select id="dev-elite" aria-label="엘리트 보정"><option value="">일반</option>${Object.keys(eliteModifiers).map(id => `<option value="${id}">${id}</option>`).join('')}</select>${button('dev:spawn', '선택한 적 생성')}${button('dev:stress','일반 적 500 생성')}<select id="dev-sound" aria-label="테스트 효과음">${Object.entries(sfx).map(([id, sound]) => `<option value="${id}">${sound.label}</option>`).join('')}</select>${button('dev:sound', '선택 효과음 재생')}<label>현재 Wave 경과(초)<input id="dev-time" aria-label="게임 시간 초" type="number" min="0" max="86400" value="0"></label>${button('dev:time', '시간 이동')}<label>게임 속도<select id="dev-speed" aria-label="게임 속도">${[0.5, 1, 2, 5, 10].map(speed => `<option value="${speed}" ${speed === 1 ? 'selected' : ''}>${speed}×</option>`).join('')}</select></label></div><details><summary>공통 스탯 20개</summary><pre id="dev-player-stats"></pre><select id="dev-stat" aria-label="변경할 스탯">${Object.keys(DEFAULT_STATS).map(id => `<option value="${id}">${id}</option>`).join('')}</select><input id="dev-stat-value" aria-label="스탯 가산값" type="number" step="0.05" value="0.5">${button('dev:stat-apply', '스탯 가산 적용')}${button('dev:stat-reset', '테스트 스탯 초기화')}<small>배율 +0.5는 +50%p. HP·Armor·속도는 수치 가산.</small></details><small>적 처치는 마력석을 지급합니다.<br>Wave 이동은 적과 투사체를 정리하고 무기·아이템을 유지합니다.</small></details>`;
    this.element.querySelector('.dev-controls')?.insertAdjacentHTML('afterbegin',
      `<label>생환석<select id="dev-revival-grade">${Object.entries(REVIVAL_STONES).map(([grade,stone])=>`<option value="${grade}">${stone.name}</option>`).join('')}</select></label>${button('dev:revival-add','생환석 +1')}${button('dev:revival-down','쓰러짐 시험')}`);
    this.stats = this.element.querySelector('pre')!;
    this.playerStats = this.element.querySelector('#dev-player-stats')!;
  }
  update(run: RunState | null, metrics: DebugMetrics): void {
    if (this.element.hidden) return;
    this.playerStats.textContent = run ? Object.entries(run.calculatedStats).map(([key, value]) => key + ': ' + value.toFixed(2)).join('\n') : '전투 시작 후 표시';
    this.stats.textContent = `마력석 드랍 100% · 무기와 아이템 상점 구매\nFPS ${metrics.fps.toFixed(0)} · ${metrics.frameTime.toFixed(1)} ms\n속도 ${metrics.timeScale}× · Save v${SAVE_VERSION}\n${run ? `시간 ${formatTime(run.stageCombatTime)} · ${run.phase}\n설치물 ${run.structures.length} · 무기 슬롯 ${run.ownedWeapons.length}/${WEAPON_CONFIG.maxSlots} · Luck ${run.calculatedStats.luck}\n${run.ownedWeapons.map(w => (weapons[w.id]?.signatureOwnerId ? "[고유] " : "") + weapons[w.id]?.name + " Lv." + w.level + (w.branchId ? " / " + w.branchId : "")).join(" / ")}\nHP ${Math.ceil(run.player.hp)}/${run.player.maxHp}\n적 ${run.enemies.length} · 탄 ${run.projectiles.length} / 적 탄 ${run.hostileProjectiles.length} / 예고 ${run.hazards.length} · 픽업 ${run.pickups.length}\n좌표 ${run.player.x.toFixed(0)}, ${run.player.y.toFixed(0)}\n아레나 ${maps[run.mapId]!.arenaWidth} × ${maps[run.mapId]!.arenaHeight}\nWAVE ${run.currentWave}/${run.totalWaves} · 남은 ${formatTime(Math.ceil(run.waveRemainingTime))}\n무적 ${run.invincible ? 'ON' : 'OFF'}` : '메뉴 · 전투 시작 후 조작 가능'}\n저장 ${metrics.saveStatus}\n오디오 ${metrics.audio}`;
  }
}





