# 직접 걷는 길드 본부

> 이전 승인 구현 기록이다. 2026-10-05 고정 관리 패널 리뉴얼로 교체되어 현재 main의 `guild`는 `HeroGuildOfficeScreen`을 사용한다. 아래 경로·이동·v2 저장 설명은 당시 구현 기준이며 현행 내용은 [GUILD_OFFICES.md](GUILD_OFFICES.md)를 따른다.

2026-10-04 사용자가 걷는 길드 시안의 현재 워크트리 연결을 승인했다. main의 `guild` 경로는 `HeroGuildWalkScreen.create`로 연결하며 선택한 각성자와 임시 UI 상태를 전달한다. 경영 명령은 기존 `Profile.guild_action`을 사용한다. 길드 저장 v2·출동 v3, 시설 배치와 경영 수치는 그대로이며 현재 길드를 다시 초기화하지 않는다.

- `HeroGuild`: 연속된 2층·8칸 월드, 방 앞 보행선과 오른쪽 승강기 경로, 플레이어·직원·공사 인물, 전체 보기와 추적 카메라를 소유한다. 기존 표시 원본은 시안 폴더 `legacy-guild.gd.txt`에 보존한다.
- `HeroGuildMovement`: 전투 입력과 분리된 키보드·터치/마우스 입력. 8px 이하 탭은 목적지, 드래그는 조이스틱이며 UI와 포인터 취소를 구분한다.
- `HeroGuildWalkScreen`: 기존 시설·직원·탐험·작업·공방 본문을 재사용한다. 월드와 인물 위치를 유지한 채 HUD·관리창을 갱신하며 `close_management()`가 Escape 우선 닫기를 제공한다.

입구에서 시작해 방을 선택하면 걸어가 관리창을 연다. A/D·좌우키로 직접 걷고, E로 근처 시설을 이용한다. 승강기 앞에서 위/아래 입력으로 층을 오간다. 직원·작업·수령은 운영실, 작전 투입은 출입구로 이동한다. 직접 입력은 자동 이동을 취소한다. 관리창은 플레이어만 정지시키며 직원과 경영 시간은 계속 흐른다.

이동 위치는 `guild_ui.walk`에만 둔다. 같은 실행 중 재방문에는 유지하되 재실행 시 입구에서 시작한다. 직원 이동·탐험 출입은 영구 배치와 작업 상태의 시각화이며 이동 시간은 생산량이나 작업 시간에 영향을 주지 않는다.

추가 구조 PNG·명시 atlas 영역·image_gen 프롬프트·승인 시안은 `design/ui-image-skins/guild-walk-01`에 보존한다. 승인된 구조 원화는 `assets/ui/guild-walk`에서 exporter를 통해 `godot/assets/ui/guild-walk`로 가져오며 `data/visuals/guild.json.walk`가 영역과 역할을 기록한다. 기존 방·빈 방·공사 PNG와 SD는 재사용한다.

기존 실행용 파일로 현재 게임을 실행한다. `Preview-Guild-Walk.cmd`는 `tools/guild_walk_preview.tscn -- --ui-preview --guild-walk-preview`로 독립 메모리 본부를 열며 프로필·출동 저장을 쓰지 않는다. 같은 씬을 `-- --ui-preview`로 실행하면 915×412 시안 네 장을 캡처하고 종료한다.

연결 후 필수 확인: 승인 구조 PNG 가져오기와 실제 main의 `--open=guild` 읽기 전용 로드 90프레임 통과. 전체 테스트·자동 플레이·수동 플레이·모바일 실기기 QA는 수행하지 않았다.
