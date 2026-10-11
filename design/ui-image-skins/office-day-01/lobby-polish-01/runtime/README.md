# 로비 변경 전후 실행 화면

모든 원본 캡처는 Godot 4.7.2 Compatibility의 실제 915×412 뷰포트에서 얻었습니다.
`before_lobby.png`는 런타임 코드 수정 전에 새로 촬영했으며, 당시 소스·셰이더는 상위 `_raw/baseline/`에 보존했습니다.

## 파일

- `before_after.png`: 같은 대사·캐릭터 위치·시작 시점의 전체 전후 비교.
- `details.png`: 스피커 ON/OFF, 통신창, 메뉴판, 출동판과 장식 확대 비교.
- `after_menu_hover.png`, `after_menu_pressed.png`: 자료집 메뉴의 hover·눌림.
- `after_deploy_hover.png`, `after_deploy_pressed.png`: 출동판의 hover·눌림.
- `after_speaker_on.png`, `after_speaker_off.png`: 미리보기에서만 음향 아이콘 상태를 고정한 화면.
- `after_restored.png`: 버튼 상태 복귀 화면.
- `motion_preview.gif`: 6초, 15fps. 대기 → 메뉴 hover·눌림 → 복귀 → 출동 hover·눌림 → 대기.
- `capture_report.json`: 캡처 조건과 해당 화면의 상태 복귀 확인 결과.
- `frames/`: 캡처 도구가 GIF 제작 중에 생성하는 실제 뷰포트 원본 90장. 최종 GIF 확인 후 재생성 가능한 임시 프레임은 삭제합니다.

## 캡처 조건과 확인 범위

`--ui-preview --guild-office-preview`를 함께 사용해 Profile.writable=false를 확인합니다. 사용자 프로필을 읽지 않고 합성 메모리 프로필과 고정 난수 seed 20261011을 사용합니다. 캐릭터 네 명은 같은 위치에 고정하고, 대사·셰이더·장식의 시점을 캡처에서만 제어합니다. 실제 게임의 음향 판단은 변경하지 않습니다.

개별 스크린샷 크기 915×412, 최종 GIF 재생시간 6000ms를 확인했습니다. GIF 90장의 디코딩 결과가 팔레트 변환한 원본 프레임과 같은지도 확인했습니다. 시각적으로 스피커 형태와 상태, 본문 가독성, 메뉴·출동판의 hover/눌림·복귀를 확인합니다. 캐릭터 좌표는 같지만 최초 렌더링 몇 프레임의 방향 전환 스쿼시 때문에 변경 전후의 캐릭터가 미세하게 다른 픽셀을 갖습니다. 전체 테스트·전투 플레이·실제 모바일·청음 QA는 수행하지 않았습니다.

## 재생성

Godot 실행: `Godot_v4.7.2-stable_win64_console.exe --path godot --resolution 915x412 res://tools/lobby_polish_capture.tscn -- --ui-preview --guild-office-preview --stage=after`

합성 보고: `python godot/tools/compose_lobby_polish_report.py`
