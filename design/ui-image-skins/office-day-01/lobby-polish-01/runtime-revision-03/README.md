# 로비 변경 전후 실행 화면

모든 원본 캡처는 Godot 4.7.2 Compatibility의 실제 915×412 뷰포트에서 얻었습니다.
`before_lobby.png`는 런타임 코드 수정 전에 새로 촬영했으며, 당시 소스·셰이더는 상위 `_raw/baseline-revision-03/`에 보존했습니다.

## 파일

- `before_after.png`: 같은 대사·캐릭터 위치·시작 시점의 전체 전후 비교.
- `details.png`: 스피커 ON/OFF, 통신창, 메뉴판, 출동판과 장식 확대 비교.
- `after_menu_hover.png`, `after_menu_pressed.png`: 자료집 메뉴의 hover·눌림.
- `after_deploy_hover.png`, `after_deploy_pressed.png`: 출동판의 hover·눌림.
- `after_speaker_on.png`, `after_speaker_off.png`: 미리보기에서만 음향 아이콘 상태를 고정한 화면.
- `after_restored.png`: 버튼 상태 복귀 화면.
- `motion_preview.gif`: 6초, 15fps. 스피커 ON 0–2초 → OFF 2–3초 → ON 3–6초. 이와 함께 메뉴·출동 hover와 눌림, 통신창과 작전 장식의 움직임을 보여 줍니다.
- `capture_report.json`: 캡처 조건과 해당 화면의 상태 복귀 확인 결과.
- `frames/`: 캡처 도구가 GIF 제작 중에 생성하는 실제 뷰포트 원본 90장. 최종 GIF 확인 후 재생성 가능한 임시 프레임은 삭제합니다.

## 캡처 조건과 확인 범위

`--ui-preview --guild-office-preview`를 함께 사용해 Profile.writable=false를 확인합니다. 사용자 프로필을 읽지 않고 합성 메모리 프로필과 고정 난수 seed 20261011을 사용합니다. 캐릭터 네 명은 같은 위치에 고정하고, 대사·셰이더·장식의 시점을 캡처에서만 제어합니다. 실제 게임의 음향 판단은 변경하지 않습니다.

개별 스크린샷 크기 915×412, 최종 GIF 재생시간 6000ms를 확인했습니다. GIF 90장의 디코딩 결과가 팔레트 변환한 원본 프레임과 같은지도 확인했습니다. 시각적으로 스피커 형태와 상태, 본문 가독성, 메뉴·출동판의 hover/눌림·복귀를 확인합니다. 시작 전에 SD 방향 전환과 스쿼시를 중립 상태로 맞춰 변경 전후의 캐릭터 좌표와 자세를 일치시킵니다. 전체 테스트·전투 플레이·실제 모바일·청음 QA는 수행하지 않았습니다.

## 재생성

Godot 실행: `Godot_v4.7.2-stable_win64_console.exe --path godot --resolution 915x412 res://tools/lobby_polish_capture.tscn -- --ui-preview --guild-office-preview --stage=after --output=res://../design/ui-image-skins/office-day-01/lobby-polish-01/runtime-revision-03`

합성 보고: `python godot/tools/compose_lobby_polish_report.py --output design/ui-image-skins/office-day-01/lobby-polish-01/runtime-revision-03`

## 이번 수정의 렌더링 확인

메뉴와 출동판의 화면 샘플링 유리는 클립 그룹 없이 그립니다. 큰 영문 워터마크에는 글리프 알파만 제한하는 셰이더를 직접 적용해 닫힌 흰색 판이 생기지 않고 글자가 판 밖으로 나가지 않게 했습니다. 네이티브 메뉴 포커스를 캡처에서만 강제로 부여해 포커스 전후의 화면 픽셀이 같고 StyleBoxEmpty가 유지되는 것도 확인했습니다.

## 세 번째 수정의 확인 대상

왼쪽으로 옮긴 스피커와 낮춘 진동·짙은 음파, 배경과 충분히 분리되는 유리판, 출동판과 일치하는 메뉴 기울기, 고정된 메뉴 아이콘, 새 출동 게이트 그림과 정지한 한서아 얼굴을 실제 화면에서 비교합니다. 스피커 확대 영역은 런타임 버튼 좌표에 맞춰 조정합니다. 이전 버전의 캡처와 소재는 덮어쓰지 않습니다.

최종 확인: 메뉴와 출동판의 실제 셰이더 기울기는 모두 0.285714285714286입니다. 메뉴 아이콘 세 개·게이트 아이콘·한서아 얼굴의 로컬 위치와 크기는 수동 시간 진행 전후에 동일합니다. 음파는 어두운 색으로 간격을 넓혔고 스피커 진동은 줄였습니다. 메뉴의 hover 이동과 눌림은 유지되며 복귀·입력 영역·네이티브 포커스 확인을 통과했습니다. 기존 버전의 캡처와 변경 전 원본을 보존했습니다.
