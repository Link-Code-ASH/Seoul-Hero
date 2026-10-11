# 밸런스·콘텐츠 검토 시안

2026-10-07. 전체 점검 보고서는 [BALANCE_CONTENT_REVIEW.md](../../../godot/docs/BALANCE_CONTENT_REVIEW.md), 화면별 문제·제안·개발 과제는 [갤러리](index.html)에서 확인한다.

## 제작 범위

Godot 4.7.2 Standard / 2D Compatibility에서 915×412 합성 상태를 렌더링한다. 이 폴더의 독립 프로젝트는 게임의 Content·Profile·Sound autoload, 저장 어댑터, 전투 시뮬레이션을 불러오지 않는다. 기존 게임의 수치·보상·화면을 변경하는 작업은 포함하지 않는다.

| 캡처 | 상태 |
|---|---|
| `captures/01-deploy.png` | 심도 1~20·심도 3 도전·대표 위협·최초 보상·지정 목표 |
| `captures/02-deploy-locked.png` | 심도 21~40·잠금 이유·후속 콘텐츠 변화 후보 |
| `captures/03-shop-weapons.png` | 게이트24 무기 4칸·다음 위협·보유 빌드·구매 변화 |
| `captures/04-shop-items.png` | 아이템 4칸·효과와 패널티·빌드 역할 |
| `captures/05-shop-detail.png` | 선택 상세·강화 전후 효과·분기 비교 |
| `captures/06-result-clear.png` | 심도 3 최초 완료·정산·기여도·다음 행동 |
| `captures/07-result-death.png` | 심도 3·완료 10웨이브 후 사망·정산·목표·재도전 |

무기 비교는 송진우·해당 레벨·협회/영구 무기/아이템/축복/길드/주간 추가 보정 없음의 합성 예시다. 기존 타격 계산의 송진우 특성과 전역 피해 배율을 반영하며, 실제 적중률이나 클리어 성능을 뜻하지 않는다.

최초 완료·사망의 코인과 길드 보상은 현재 규칙에 맞춘다. 지정 무기 조각 12개·선택 축복 조각 18개·계정 목표와 심도 25/30/40 변화는 미승인 기획 후보이며 정산과 분리한다. 완료·사망 진척은 계정 목표 제안의 예시이고, 반복 또는 사망 보상을 변경하지 않는다.

## 원본과 소재

- `materials.json`: 기존 `godot/data/visuals/ui_materials.json`의 소재 정의와 9분할·안전 여백·출처를 보존한 시안용 스냅샷.
- `common.gd`: 원본 PNG와 실제 폰트를 읽어 네이티브 Control 텍스트·입력·배치를 구성하는 독립 시안 도구.
- `preview.gd`·`main.tscn`·`project.godot`: 일곱 합성 상태와 독립 렌더 진입점.
- 실제 소재: 기존 `godot/assets/ui/image-skin/operations-standard-01`, `operations-light-controls-02` 및 상점 `cstore` 소재. 새 프레임 원화는 생성하지 않았다.
- 원화·아이콘: `godot/data/content.json`과 `godot/data/visuals/actors.json`의 기존 승인 에셋 경로. 생성 원본·프롬프트·라이선스는 기존 `assets` 출처 기록을 유지한다.
- 폰트: BMJUA·KMU80HaeongSans·Paperlogy Regular/Medium·Barlow Condensed SemiBold. 기존 `godot/assets/ui/fonts`와 원본 라이선스를 사용한다.

## 다시 렌더링

저장소 최상위의 PowerShell에서 아래처럼 실행한다. 로그·`.godot`는 재생성 산출물이며 커밋하지 않는다. `--capture`는 합성 화면만 저장하고 종료한다.

```powershell
$balancePreviewRoot = (Resolve-Path 'design/ui-image-skins/balance-content-01').Path
$balanceEnginePath = 'C:/Users/geniu/Documents/GitHub/Godot/Godot_v4.7.2-stable_win64_console.exe'
$balancePreviewArgs = @('--path', $balancePreviewRoot, '--', '--capture')
Start-Process -FilePath $balanceEnginePath -ArgumentList $balancePreviewArgs -WindowStyle Hidden -Wait
```

독립 프로젝트를 편집기에서 열면 `1` 출동 준비·`2` 상점·`3` 결과로 이동한다. 화면의 페이지·탭·상세 조작은 합성 상태를 바꾸며 구매와 지급을 실행하지 않는다. HTML 갤러리는 화면별 상태 전환 버튼과 PNG 원본 링크를 제공한다.

## 확인 범위

원본 코드·데이터 읽기, 정적 비용·시간·효과 계산, 독립 화면 렌더와 캡처 확인을 수행한다. 시안 자체의 필요한 문법 오류만 수정한다. 자동 테스트·전체 빌드·실제 플레이·터치·Android 실기기·사용자 저장 조회 및 이관 QA는 수행하지 않는다. 플레이 확인 항목은 보고서에 정리한다.

최종 PNG 7장 모두 915×412이며 캡처의 글자 영역 문제와 44px 미만 입력 영역은 각각 0건이다. 스크립트·소재·폰트 로드 오류를 수정한 최종 캡처를 사용한다. 재사용 원본 39개와 PNG·데이터의 SHA-256은 `provenance.json`에 기록했다. 이번 작업 시작·종료의 게임 코드·공용 데이터·콘텐츠 JSON·프로젝트 설정·exporter 96개 파일 해시는 모두 같았다.

새 화면은 게임에 연결하지 않는다. 실제 적용은 보고서 검토와 `godot/docs/UI_GUIDE.md`의 새 배치 시안 승인을 거친 후 진행한다.
