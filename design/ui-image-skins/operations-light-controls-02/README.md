# 가벼운 조작 프레임 · 실제 적용

2026-10-05 사용자의 **“구현해”** 승인으로 런타임에 연결했다. 현재 `index.html`은 실제 게임 화면 클래스의 캡처이며, 승인 시안은 `approved-drafts.html`에 보존한다. 실제 소재 역할은 `compact/back`·`compact/secondary`·`compact/tab`·`compact/primary`이다. 아래 `light/*` 표기는 독립 시안의 원래 역할명이다.

2026-10-05 피드백: 타이틀을 도시 작전풍에 맞추고, 뒤로가기와 게이트24의 짧은 조작에 쓰는 프레임을 얇게 바꾼다.

큰 정보판·상세창·팝업과 게이트24의 전용 진열 원화는 유지한다. 조작만 장식 밀도를 낮춘다. 새 프레임은 imagegen으로 제작한 래스터 PNG이며, 글자는 기존 실제 폰트를 사용하는 네이티브 Label이다.

| 소재 | 용도 | 내용 여백 |
|---|---|---|
| `light/back` | 44px 정사각형 복귀 조작 | 좌우 8px·상하 6px |
| `light/secondary` | 리롤·전체 스탯·보유 목록·조합·보조 행동 | 좌우 6px·상하 4px |
| `light/tab` | 무기/아이템 등 짧은 탭 | 좌우 8px·상하 4px |
| `light/primary` | 타이틀 시작/이어하기·다음 웨이브 | 좌우 10px·상하 4px |

- 테두리는 표시 크기에서 약 1~2px로 읽히도록 만든다. 모서리 분할은 원본 24px, 표시 6px이다.
- 선택 상태는 같은 탭 PNG에 민트 색조만 적용한다. 조작 크기·배경 형상·글자 위치는 고정한다.
- 버튼 입력 영역은 44px 이상이다. 버튼·탭 16px, 타이틀 시작/이어하기/새로하기 19px을 유지한다.
- 타이틀 로고 면은 승인된 `ops/info` 정보판으로 맞추며, 전투 원화·로고 글꼴·이어하기 조건은 유지한다.
- 원본 생성 시트, 추출 원본, 4배 표시용 마스터를 각각 보존한다. 4배 마스터는 원본의 높이를 정규화하고 조용한 중앙만 래스터 9분할로 확장한 결과다. 모델이 새 4K 세부를 생성한 것으로 기록하지 않는다.

독립 시안 프로젝트에는 게임·오디오·저장 autoload가 없다. 승인 후 `connect_assets.py`가 원본·출처·공용 이미지 manifest·소재 역할을 연결하고 기존 exporter로 Godot 사본을 갱신했다. 실제 화면 확인은 게임의 `image_skin_capture.tscn -- --ui-preview --guild-office-preview --compact-controls-preview`로 수행했다. 가격·규칙·사용자 저장은 변경하지 않았다.

원본·편집 영역·안전 여백은 `provenance.json`, 프롬프트는 `prompts.json`, 배치 측정은 `captures/layout.json`에 보존한다.

`check_preview.py`와 `runtime-before.json`은 게임을 바꾸기 전 시안의 검사 기록이다. 실제 연결 이후에는 그 이전/이후 동일성 검사를 재실행하지 않는다. 승인 후 기록은 `runtime/QA.md`·`runtime/verification.json`, 갤러리 갱신은 `publish_runtime.py`를 사용한다.
