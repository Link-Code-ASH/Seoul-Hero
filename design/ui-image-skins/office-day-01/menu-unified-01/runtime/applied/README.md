# 메뉴 통일 · 실제 적용 화면과 협회 연출

설정/자료집/협회/출동 준비에 승인된 사무실 유리 UI를 적용한 실제 main 씬 캡처입니다. `HeroDesk.presentation=true` 기본값을 그대로 사용했고 캡처에서 디자인 플래그를 덮어쓰지 않았습니다. 소재는 내부 `res://assets/ui/office-day-01/menu-unified-01/`에서 불러옵니다.

- `../before/`: 변경 전에 새로 촬영한 원래 실행 화면 15장. 수정하지 않았습니다.
- `../preview/`와 상위 승인용 보고서: 이전 승인 시안 보존.
- 이 폴더: 동일 합성 프로필의 적용 화면 15장과 조작/잠금/재화/층 페이지/협회 결과 상태.
- `contact_sheet.png`: 네 화면, `before_after.png`: 네 화면 전후, `deployment_steps.png`: 출동 여섯 단계, `details.png`: 상태·연출 확대.
- `motion_preview.gif`: 실제 Godot viewport 90프레임, 6000ms. hover·눌림·복귀, 뽑기 2초, 스탯 강화와 해금 각 0.8초를 담습니다. `frames/`에 최신 원본을 보존합니다.

915×412, seed 20261011, 고정 주차 2961, 코인 1850, 네 각성자·일곱 시작 무기·첫 축복·최고 25층인 합성 상태를 사용했습니다. 대표 화면은 전후 프로필 일치 `True`, 15개 선택값 일치 `True`입니다. 협회 결과 상태만 종류별 미해금 후보 하나 또는 강화 대상을 메모리에 구성했습니다.

`--ui-preview --guild-office-preview`와 `Profile.writable=false`를 강제했습니다. 사용자 프로필·백업·체크포인트 내용 읽기, 실제 저장·가져오기·외부 폴더 열기·전투 시작은 수행하지 않았습니다. 메인의 실제 `_association_transaction()`에 메모리 fake commit을 넣어 각성자/무기/축복 뽑기와 스탯/해금 성공의 1회 차감·1회 commit, 부족 재화·전체 해금 거절, commit 실패 롤백을 확인했습니다. 실제 저장 콜백을 호출하는 결제 UI 요청은 읽기 전용 경계에서 차단했습니다.

뽑기 결과는 실제 `HeroAssociationFeedback.draw()` 연결로 보여 줬습니다. 첫 확인/뒤로가기는 즉시 공개, 두 번째는 닫기를 확인했습니다. busy 중 분류·반복 요청은 프로필과 선택을 유지했고 포커스 상실은 완성 상태로 정리되어 남은 광택/입자가 숨겨지며 소리 상태를 바꾸지 않았습니다. 강화는 실제 payload의 이전/다음 수치를 `play()`에 넘겨 0.8초 진행·입력 복귀·완료 안내를 확인했습니다. 출동의 독립 안내 줄·하단 설명 제거, 기존 6단계·잠금 상세·편성 수정·44px 입력·상태 복귀도 확인했습니다. 마지막 새 프로세스에서는 앱 포커스 상실 시 1.5px 눌림·광택·Tween을 즉시 정리하고 복귀 후 기본 위치를 유지하는 좁은 확인을 추가했습니다. 시각 변경이 없어 검증된 PNG/GIF는 유지했습니다.

확인 155개 중 실패 0개, 스크립트/셰이더/소재 로딩 오류 0개. 공통 GIF 팔레트를 사용했고 최신 90개 프레임을 디코딩 RGB로 검증한 결과 `True`입니다. 전체 테스트·전투 플레이·실기기/청음 검증은 하지 않았습니다. 상세 확인·PNG 크기·프레임 해시는 `capture_report.json`과 `manifest.json`에 있습니다.

재생성: `godot/tools/menu_unified_capture.tscn -- --ui-preview --guild-office-preview --stage=applied`, 보고서 조합: `godot/tools/compose_menu_unified_report.py --stage=applied`.
