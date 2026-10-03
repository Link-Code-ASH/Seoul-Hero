# 이미지 UI 시안용 폰트

이 폴더는 `design/ui-image-skins`의 승인 전 시안에만 사용합니다. 게임 런타임이나 exporter에 연결하지 않습니다. 모든 파일은 소유자 제공본 또는 프로젝트에 이미 보존된 폰트의 복사본이며, 새 다운로드는 없습니다. 폰트별 역할은 실제 파일로 구분하고 한 화면에서는 제목·본문·숫자의 위계를 유지합니다.

| 파일 | 시안 역할 | 복사 출처 |
| --- | --- | --- |
| `KMU80SungkokSerif.ttf` | A 섹션 제목 | `C:/Users/geniu/Downloads/KMU80SungkokHaeong_01/TTF/KMU80TTFSungkokSerif.ttf` |
| `SFSsaraknun.ttf` | A 큰 제목·타이틀 로고 | `assets/ui/fonts/SFSsaraknun.ttf` |
| `BMJUA.ttf` | B 큰 제목·타이틀 로고 | `assets/ui/fonts/BMJUA.ttf` |
| `Paperlogy-4Regular.ttf` | 본문 | `assets/ui/fonts/Paperlogy-4Regular.ttf` |
| `Paperlogy-5Medium.ttf` | 버튼·탭 | `godot/assets/ui/fonts/Paperlogy-5Medium.ttf` |
| `BarlowCondensed-SemiBold.ttf` | 숫자·계기 | `assets/ui/fonts/BarlowCondensed-SemiBold.ttf` |
| `KMU80HaeongSans.ttf` | B 섹션 제목 | `assets/ui/fonts/KMU80HaeongSans.ttf` |

Barlow의 두 형식에는 `BarlowCondensed-OFL.txt`의 SIL Open Font License 1.1이 적용됩니다. 나머지 제공본 출처는 함께 복사한 `SOURCES.md`를 따르며 원래 글꼴의 이름·저작권 메타데이터를 보존합니다. `OFL.txt`는 기존 Pretendard 배포본의 라이선스 사본이며 다른 폰트의 라이선스로 해석하지 않습니다. Barlow의 WOFF2→TTF 변환 기록과 Haeong TTF 출처는 `font-import-provenance.json`에 있습니다.

## 배치 참고

아래 값은 TTF hhea 메트릭을 16px로 환산한 참고 높이입니다. 실제 글꼴 엔진의 줄 높이·fallback·행간이 최종 기준이며 이 값만으로 고정된 박스에 강제하지 않습니다.

| 폰트 | unitsPerEm | ascender / descender / lineGap | 16px 참고 높이 |
| --- | --- | --- | --- |
| `KMU80SungkokSerif.ttf` | 1000 | 850 / -300 / 0 | 18.4px |
| `SFSsaraknun.ttf` | 1000 | 807 / -169 / 90 | 17.06px |
| `BMJUA.ttf` | 1000 | 800 / -200 / 30 | 16.48px |
| `Paperlogy-4Regular.ttf` | 900 | 880 / -180 / 0 | 18.84px |
| `Paperlogy-5Medium.ttf` | 900 | 880 / -180 / 0 | 18.84px |
| `BarlowCondensed-SemiBold.ttf` | 1000 | 1000 / -200 / 0 | 19.2px |
| `KMU80HaeongSans.ttf` | 1000 | 850 / -300 / 0 | 18.4px |

기능 텍스트는 HTML/Godot의 실제 텍스트로 렌더링하고, 이미지에 구매 가격·효과·상태 문구를 구워 넣지 않습니다. 본문은 14px 이상, 보조 문구 13px 이상, 조작 영역 44px 이상을 유지합니다.
