# 고정 관리 패널 길드 본부

2026-10-05 사용자가 design/ui-image-skins/guild-offices-01의 수정 시안을 승인했다. 같은 날 사용자 요청으로 055e 워크트리의 리뉴얼을 본 개발 폴더에 병합했다. 기존 실행 파일과 main의 `guild` 경로는 이 화면을 로드한다. 이전 걷기/2.5D 시안은 제작 기록으로 보존한다.

## 화면과 입력

HeroGuildOfficeScreen이 915×412에서 왼쪽547×335 건물과 오른쪽330×335 전용 공간을 고정한다. 선택이 없으면 오른쪽은 빈 배경이며 패널 개폐로 건물 배율·스크롤은 바뀌지 않는다. 하단 단축 버튼은 없다. 왼쪽은 8px 세로 드래그/휠과 사무실 선택, 오른쪽은 관리·직원·작업 탭과 내부 스크롤을 맡는다. Escape는 패널을 먼저 닫는다.

기존 HeroGuildScreen의 경영 내용을 재사용하고 Profile.guild_action으로 명령한다. 운영실은 전체 직원·채용·교육·작업·보상 수령·출동, 다른 시설은 해당 시설 내용이다. 선택시설ID/탭/스크롤은 실행 중 UI 상태로만 유지한다.

## 표시와 저장

HeroGuildOfficeWorld는 연결된 층당3칸, 기존 시설/빈방/공사 PNG와 SD 직원/접지 그림자/앞쪽 가림을 맡는다. 직원ID 노드를 유지하며 배치·연구·교육·탐험과 공사 완료를 목적지 갱신으로 반영한다. 이동은 경영 작업 시각에 영향을 주지 않는다. 기존 PNG 아틀라스4열은 Lv.1/4/7/10 원화 변형이고 방 배치3열과 다르다.

공용 콘텐츠의 roomsPerFloor3/floorUnlockOfficeLevels[1,2,3]과 HeroGuildState의 공용 층 계산을 사용한다. 영구 저장v3의 unlockedFloors는 감소하지 않는다. v2는 옛4/8칸 검증 후 현재시설·공사·재화·직원·작업시각을 보존하고 최소2/3층을 추가한다. 사용자 저장을 복사하거나 초기화하지 않는다. 출동 체크포인트는 기존v3이다.

## 좁은 확인

`tools/guild_floor_save_check.tscn -- --ui-preview --guild-floor-save-check`는 실제 저장을 읽거나 쓰지 않고 이관을 메모리에서 확인한다. `tools/guild_office_preview.tscn -- --ui-preview --guild-office-preview`는 실제 화면을 별도 메모리 상태로 캡처한다. 전체 테스트·자동 플레이·수동 플레이 QA는 수행하지 않는다.

본 폴더 병합에서 메모리 이관 31항목, 읽기 전용 main 길드 로드, 915×412 실제 화면 6장을 확인했다. 기존 VFX·회수·보급 연결은 보존했다. 병합 원본과 복구 경로는 [GUILD_INTEGRATION.md](GUILD_INTEGRATION.md)를 참고한다. 옛 `guild_save_check`와 `checkpoint_qa`의 형식 v2 기대값은 현재 저장 v3 확인에 사용하지 않는다.
