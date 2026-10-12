# 일시정지 · 밝은 유리 시안

2026-10-12 요청에 따른 시안이며 수정 02를 사용자가 승인했습니다.

2026-10-12 수정 02: 하단 안내 문구 삭제, 계속하기만 밝은 청회색 PNG로 교체했습니다. 이후 사용자의 적용 승인에 따라 `HeroCombatUI.pause_menu`에 동일 배치·소재·폰트를 연결했습니다. 기존 PNG 원본 시안은 보존합니다.

- [preview-02-915x412.png](preview-02-915x412.png): 수정 02의 최신 가로 시안.
- [preview-02-1830x824.png](preview-02-1830x824.png): 수정 02의 최신 2배 해상도 시안.
- [PROMPT-02.txt](PROMPT-02.txt): 계속하기 버튼 수정 프롬프트 기록.

- `preview-915x412.png`: Galaxy S24 Ultra 가로 기준 완성 시안.
- `preview-1830x824.png`: 동일 배치의 2배 해상도.
- `index.html`: PNG 표면과 실제 폰트로 구성한 독립 배치 원본. 저장소 루트를 정적 서버로 열면 표시됩니다. 버튼은 시안용이며 동작하지 않습니다.
- `render-preview.mjs`: 브라우저·게임 실행 없이 같은 배치를 Skia Canvas로 렌더링하는 소스. PNG 프레임·버튼은 그대로 사용하고 글자를 실제 폰트로 렌더링합니다.
- `pause-panel.png`: built-in ImageGen으로 새로 제작한 1448×1086 RGBA 소재. 410×308 고정 패널에 원래 비율로 표시합니다. 가변 9분할로 확장하기 전에 모서리·안전 여백을 별도로 정해야 합니다.
- `PROMPT.txt`: 제작에 사용한 최종 프롬프트 전문.

최신 `office-day-01/menu-unified-01`의 밝은 유리·남색 버튼, 출동의 산호색을 따릅니다. 승인된 `glass_row.png`, `glass_button_navy.png`, `glass_button.png`를 재사용했습니다. 기존 광화문03 전투 캡처 `vfx-reborn-01/slash.png` 위에 남색 베일을 깔고 지도·층수·웨이브·계속하기·출동 종료를 유지합니다. 예시 정보는 광화문 광장 6층, 1/20웨이브입니다.

제목 Paperlogy ExtraBold, 본문 Paperlogy Regular, 버튼 Paperlogy SemiBold, 숫자 Barlow Condensed Bold를 사용했습니다. 새 프레임·광택을 CSS나 벡터로 그리지 않았습니다. 입력 영역은 계속하기 354×48, 출동 종료 354×44입니다.

새 소재 생성 원본: `C:\Users\geniu\.codex\generated_images\01a12eab-c944-74b2-93ad-fe45da680358\exec-9240dae5-0f75-478a-83c0-3804e76053d2.png` (프로젝트에 사본 보존).

시안 이미지의 글자·배치는 육안으로 확인했습니다. 실제 게임 실행·저장·테스트·플레이 QA는 수행하지 않았습니다. 최종 PNG는 브라우저 캡처가 아닌 정적 UI 렌더 결과입니다.

승인 적용 후 Godot 4.7.2의 headless editor import가 오류 없이 완료되었으며 새 PNG 옆의 `.import` 설정을 보존했습니다. 실제 플레이·터치·마력석 연출 재생 QA는 실행하지 않았습니다.

수정 02의 `continue-soft-blue-02.png`는 built-in ImageGen으로 기존 버튼의 색·명도를 편집한 2169×725 RGBA 원본입니다. 원본 생성 경로는 `C:\Users\geniu\.codex\generated_images\01a12eab-c944-74b2-93ad-fe45da680358\exec-0b327287-f312-4b6d-ae08-73584c60aaa0.png`이며 프로젝트 사본을 보존합니다. 좌우 14.0625%, 상하 12.5% 영역을 18px/5px 표시 여백으로 분할합니다. 기존 시안 PNG 두 장은 보존하고 HTML·렌더 소스는 수정 02를 표시합니다.

2026-10-12 수정 02 승인 적용 소재: `prepare-runtime.mjs`가 `pause-panel.png` 1448×1086 원본을 `godot/assets/ui/pause-glass-01/`에 그대로 복사하고, `continue-soft-blue-02.png` 2169×725 원본을 승인 시안과 같은 9분할(원본 좌우 `width × 72/512`, 상하 `height × 20/160` → 표시 18px/5px)로 354×48 표시 영역의 4배 PNG 마스터 `continue-button.png` 1416×192로 확장합니다. 새 프레임·광택을 코드로 그리지 않으며 원본·프롬프트는 이 시안 폴더에 보존합니다. 재생성은 `node design/ui-image-skins/pause-glass-01/prepare-runtime.mjs <@napi-rs/canvas 모듈 경로>`로 실행합니다. Godot 가져오기 파일은 엔진에서 생성합니다.
