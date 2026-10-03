# 파일 정리 · 2026-10-03

현행 Godot SD/단일 이미지 표시 구조를 기준으로 사용처를 확인했다. 기존 작업 트리의 변경은 유지했으며 게임 규칙·밸런스·저장 형식을 바꾸지 않았다.

## 현재 소유권

| 위치 | 용도 |
| --- | --- |
| `godot/scripts`, `godot/data/visuals` | 현행 Godot 규칙·표시·UI |
| `src/data` | 공용 콘텐츠·밸런스 원본 |
| 나머지 `src`·`public` | 보존된 웹 실행·저장·배포 경로 |
| `assets` | 사용 중인 이미지·음원·폰트의 원본과 제작 출처 |
| `godot/assets`·`godot/design` | Godot이 사용하는 가져오기 사본과 전용 효과 |
| `design` | 승인 시안·고해상도 미술 원본·확인 갤러리 |
| `archive` | 퇴역 원화·파츠 리그·제작 원본과 복구 목록 |
| `godot/exports` | 확인용 출력. `.gdignore`로 게임 리소스 가져오기에서 제외 |

## 정리한 코드와 도구

- 구형 `HeroActorVisual` Skeleton2D/Bone2D 리그·씬·UID와 미사용 `slash_reveal` 셰이더 제거. 전투와 그래픽 샘플은 SD/단일 이미지 렌더러를 재사용한다.
- 현재 배경에 포함된 동상·차량을 별도 표시하던 경로와 반복 바닥 타일 경로 제거. 고정 카메라·단일 배경 중앙 크롭은 유지한다.
- 미사용 방향 메타데이터·표시 상태·`Content.facility_icon`·`Content.ui_region` 제거. 동적 UI 소재·상태 테이블은 유지한다.
- 웹 체크포인트 복원 후 캐릭터 표시 정보만 현재 콘텐츠 정의로 재연결한다. 오래된 이미지 ID가 되살아나지 않으며 체력·장비·재화·진행과 저장 형식은 그대로다.
- 웹의 더 이상 설정되지 않는 scooter/truck 표시 타입과 트럭 조건 분기를 제거. 잘못 남은 이미지 이름 `kangTaehoonTruck`는 `kangTaehoonBody`로 통일하고 그림자 데이터/제작 도구/기존 테스트 참조도 맞췄다.
- `prepare_visual_assets.py`, `combat_art_capture`, `display_qa`, `optimize_mobile_art.py` 퇴역. 구형 부위 리그를 다시 만들거나 현행 `actors.json`을 덮어쓰는 도구는 남기지 않는다.
- `godot/tools/prepare_vfx_assets.py`는 보관된 VFX 원본에서 현재 쓰는 shockwave/smoke/spark/debris/contact shadow만 추출한다. 캐릭터·몬스터·맵 데이터는 수정하지 않는다. 현행 확인 도구는 `ui_preview`, `image_skin_capture`, `combat_feedback_capture`와 런타임 graphics/SD sample이다.

## 원화·사본·출력

- 미사용 이미지 manifest 29개 제거. Godot에서는 웹 전용 타이틀·길드 그림 10종, 퇴역 premium 표면 7종, 구형 불투명 인벤토리 사본을 더 이상 복사하지 않는다. 사용 중인 로비 배경과 투명 인벤토리는 유지한다.
- 퇴역 원화·리그·바닥·VFX 314파일(94.53MiB)은 `archive/retired-art`와 `archive/legacy-godot-visuals`로 이동했다. 삭제 대신 원본·출처를 보존하고 [이동 목록](../archive/relocations-2026-10-03.json)에 원래 경로·현재 경로·SHA-256을 기록했다.
- 원본과 같은 Godot 사본 47개와 가져오기 메타 제거: 28.51MiB. [삭제 목록](../archive/deleted-copies-2026-10-03.json)의 원본에서 복구할 수 있다.
- 최종 combat-feedback 캡처에 통합된 slash-debug/slash-flow-07/orbit-height-07 임시 출력 151파일 제거: 101.84MiB. JSON/MD 메타데이터는 `godot/exports/combat-feedback/history-metadata`에 보존했다. 최종 PNG·애니메이션 갤러리는 유지한다.
- 원화 이동을 제외한 실제 제거 용량은 약 130.4MiB다.

웹의 길드 포고 레이어, 기존 CSS 프레임·전투 그림은 웹에서 실제 사용되므로 유지했다. 옛 `godot/assets/visuals/resources/magic_stone_casual.png`도 phase3의 역사 시안 재생성에서 직접 참조하므로 남겼다. 웹의 비테스트 모듈 143개는 진입점에서 import/re-export/타입 의존으로 모두 도달한다. 단순 파일 크기를 이유로 사용 중인 화면·상태 코드를 다시 나누지 않았다.

## 필요한 오류 확인

- 콘텐츠 exporter 1회: 캐릭터4·무기10·몬스터19·아이템55, 가져온 파일314, 누락 이미지0. 이미지 이외 콘텐츠 섹션은 정리 전후 동일하다. Godot images 키는243→197이다.
- 남은 literal 이미지 연결201개와 Godot 직접 리소스 참조397개: 누락0. 이동 원본314개 및 삭제 사본의 원본47개 SHA-256 불일치0.
- 수정한 TypeScript의 문법 진단0. Godot 가져오기와 저장 쓰기 차단 시작 확인은 exit0, 스크립트 실행 차단 오류0.
- 환경의 인증서 저장소 읽기 및 외부 Godot 편집기 설정 저장 권한 메시지는 남았지만 프로젝트 가져오기·시작은 완료됐다. 로그는 `godot/exports/cleanup-import.log`, `cleanup-startup.log`다.
- 전체 테스트·lint·typecheck·빌드·전투 플레이·실기기·성능 검사는 실행하지 않았다. 사용자 저장을 쓰지 않았다.
