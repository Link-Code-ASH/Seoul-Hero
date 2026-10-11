# 회수·보급 — 서울 생활 지원 거점 시안

## 승인 후 실제 연결 — 2026-10-05

사용자가 Revision 02를 승인해 실제 Godot 화면에 연결했다. 최신 갤러리는 `HeroMetaScreens.build`로 만든 운영 `HeroRecoveryScreen`·`HeroSupplyScreen`을 캡처한다. 초기 시안/승인 시안은 `revision-01/`·`revision-02/`, 초기 4배 합성은 `masters/`에 보존한다. 아래 초기 시안 경계는 제작 당시의 기록이다.

- 승인 PNG 원본은 `assets/ui/image-skin/seoul-support/`에 보존하고 공용 이미지 manifest/exporter를 통해 Godot으로 가져온다. UI 소재는 `support/panel`, 런타임 원화는 `support*` 이미지 ID 8개다.
- 두 화면은 실제 pending rewards/보급권을 사용한다. 기존 `claimOffline`·`supplyOpen`이 한 번 지급·저장한 뒤 반환한 결과만 연출하며, 완료/확인은 지급을 호출하지 않는다. 버튼 요청 가드와 코어 콜백 가드를 함께 사용한다.
- `HeroSupportPresentation`이 낮은 드론 부유·패키지 착지·봉인/뚜껑/내부빛을 소유한다. 숨김/앱 중단에는 시간을 멈추고 이탈에는 완료 신호를 취소한다. 개봉 latch/fanfare는 기존 cue를 같은 개봉에 한 번씩 사용한다. 순간 입자는 기존 공용 `HeroUIEffects`를 재사용한다.
- 보급 결과는 실제 반환 배열을 종류/콘텐츠별로 합산하고 긴 목록만 정보판 안에서 스크롤한다. 개발자 시간 추가·보급권 추가 기능도 유지한다.
- `godot/tools/support_runtime_capture.tscn -- --ui-preview --output=<이 폴더/runtime-captures>`가 915×412 정적 7상태와 움직임 5종을 만든다. `--density=4 --output=<이 폴더/runtime-masters>`는 정적 7장을 4배 viewport로 렌더링한다. 실제 운영 클래스지만 캡처 콜백은 고정 in-memory 결과이며 지급/RNG/저장을 실행하지 않는다. 게임에서는 기존 실제 추첨/지급 콜백이 사용된다.

2026-10-04 사용자 계획의 **시안 승인 전 단계**다. 게임 화면 라우팅·콘텐츠 manifest·보상/추첨·사운드·저장에는 연결하지 않았다. 승인된 기존 로비 배경과 시설 아이콘도 유지한다.

- 회수: 밝은 서울 골목 배송 거점 + 작은 빈손 드론 + 바닥에 놓인 별도 회수 패키지. 드론만 3px 부유, 짐은 2px 착지 마무리, 0.45초 획득빛을 사용한다.
- 보급: 동네 택배 데스크 + 가벼운 아이보리 패키지. 봉인빛과 분리 뚜껑, 내부빛, 약 0.85초 후 결과를 사용한다.
- 기능 글자는 native Godot Label/Button이며 BMJUA·해옹산스·Paperlogy·Barlow 역할을 유지한다. 새 유리판은 imagegen PNG 9분할이며 기존 나사 없는 편의점 버튼 PNG를 재사용한다.

## 시안 실행과 재생성

Godot 프로젝트를 `--path godot`으로 실행하면서 `--script`에 이 폴더의 `preview-capture.gd` 절대경로, 사용자 인수에 `-- --ui-preview`를 전달한다. `--density=4 --output=<이 폴더/masters>`는 3660×1648 정적 시안 5장을 만든다. 운영 게임에 이 씬을 등록하지 않는다.

`package_captures.py`는 네이티브 프레임을 보정 없이 무손실 WebP로 묶고 `index.html`을 만든다. 수량·보상은 고정된 표시 예시이며 실제 확률이나 지급 약속이 아니다. `source/prompts.json`은 built-in imagegen 프롬프트·원본 경로, `source/asset_manifest.json`은 원본 SHA-256·해상도·배치·안전 여백·뚜껑 접합 좌표를 보존한다.

## 승인 후 연결 경계

회수·보급을 각각 별도 화면 모듈로 옮기고 기존 `claimOffline/supplyOpen` 콜백을 연결한다. 회수는 성공 반환값 확인 뒤 실제 pending 상태를 갱신한다. 보급은 지급·저장 후 반환된 결과만 연출하며 개봉 중 1회/10회 버튼을 함께 잠근다. 화면용 개봉 컴포넌트는 숨김 시 정지, 화면 이탈 시 취소하고 재지급하지 않는다. 보상 이름/이미지는 기존 `reward_display`를 사용한다. 승인 전에는 이 연결을 수행하지 않는다.

## 해상도 구분

새 투명 장치와 정보판은 실제 표시 원화 크기의 4배 이상 고유 해상도를 갖는다. 두 배경은 built-in 도구가 요청한 3840×1728보다 작은 약 2배 PNG로 반환했다. 반환된 원본을 그대로 보존하고, 4배 **합성 시안마스터**와 구분해 기록했다. 4배 합성은 새로운 배경 세부 묘사를 생성하거나 원본 해상도 미달을 해결하지 않는다.

## Revision 02 — 접지 개선 (2026-10-05)

상자 밑면의 사선 원근을 따라가는 접촉·투영 그림자 PNG를 built-in imagegen으로 새로 제작했다. 보급은 기존 본체·뚜껑의 등록을 유지하면서 양쪽 하단 접면과 오른쪽 아래 짧은 투영을 연결했다. 회수는 패키지를 26px 내려 지면에 고정하고 드론을 23px 내려 낮은 호버만 남겼다. 최초 시안은 `revision-01/`에 보존하며, 이번에도 승인 전 시안으로 게임에는 연결하지 않는다.
