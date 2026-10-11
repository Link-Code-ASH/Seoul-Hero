# 메뉴 통일 · 승인 전 실제 화면 시안

현재 로비의 밝은 사무실·비스듬한 유리·기능별 포인트 색을 설정/자료집/협회/출동 준비에 적용한 시안입니다. **실제 게임의 기본 디자인은 변경하지 않았습니다.** `HeroDesk.presentation` 기본값은 `false`이며 이 캡처의 `--stage=preview`에서만 켭니다.

- `before/`: 새 도구가 변경 전 실제 main 씬으로 촬영한 15장. 기존 저장 이미지를 대신 사용하지 않았습니다.
- `preview/`: 동일 프로필·선택값의 시안 15장과 조작/잠금/재화/층 페이지 상태. 협회 결과는 초기 `association-reward.png`와 보상 연출을 진행한 `association-reward-settled.png`를 구분합니다.
- `contact_sheet.png`: 네 화면 시안. `before_after.png`: 네 화면 전후 비교.
- `deployment_steps.png`: 출동 준비 여섯 단계. `details.png`: 조작과 상태 확대.
- `motion_preview.gif`: 실제 Godot viewport 90개 프레임, 6000ms. 저장/전투 동작 없이 hover·눌림·복귀와 유리 연출을 보여 줍니다.

캡처는 915×412, seed 20261011, 고정 주차 2961를 사용했습니다. 코인 1850, 네 각성자와 일곱 시작 무기, 첫 축복 하나 해금, 최고 해금 25층인 합성 메모리 상태이며 선택은 광화문/1층/송진우/마력탄/첫 축복입니다. 전후 합성 프로필 일치: `True`. 전후 선택값 일치: `True`.

두 플래그 `--ui-preview --guild-office-preview`를 강제하고 `Profile.writable=false`를 확인했습니다. 플레이어 프로필/백업/체크포인트 내용을 읽거나 쓰지 않았고, 저장 폴더·백업·가져오기 버튼을 실행하지 않았습니다. 전투 시작과 뽑기/구매 지급은 실행하지 않았습니다. 네이티브 슬라이더, 자료집 분류/항목/상세, 층 페이지, 잠금 상세, 축복 없음, 편성 수정, 버튼 입력 크기·복귀·포커스만 시안에서 확인했습니다. 협회 팝업은 합성 payload로 표시한 뒤 기존 LootShower의 `advance()`로 3초 진행하고 확인 버튼을 눌렀으며, 표시·연출·닫기 전후 프로필 일치를 확인했습니다.

확인 실패 0개, 스크립트/셰이더/소재 로딩 오류 0개. GIF는 공통 팔레트로 정적 배경의 색 흔들림을 줄였으며 최신 소스 프레임과 디코딩 RGB 일치: `True`. 전체 테스트·전투 플레이·실기기/청음 검증은 하지 않았습니다. 자세한 체크와 PNG 크기는 `capture_report.json`, 선택값은 각 폴더의 `manifest.json`에 있습니다.

도구: `godot/tools/menu_unified_capture.tscn -- --ui-preview --guild-office-preview --stage=preview`; 합성 전후 캡처 조합은 `godot/tools/compose_menu_unified_report.py`입니다. 소재 원본·프롬프트는 상위 시안 폴더에서 보존합니다.
