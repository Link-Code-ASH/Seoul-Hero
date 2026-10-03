# 에셋 구성

- `characters-sd/`, `monsters-sd/`: Godot 현행 빈손 SD 캐릭터·다리 없는 몬스터 원화와 생성 출처.
- `visuals/structures/`: 지뢰·마력장 설치물 원화. Godot 공용 그림자와 애니메이션으로 표현합니다.
- `environment-sd/`: 현행 고정 광화문 배경. `projectiles/`, `effects/`, `pickups/`: 공격·자원 이미지.
- `ui/`: 래스터 PNG 스킨, 고해상도 원본, 역할별 폰트와 아이템/시설 원화.
- `combat-chibi/`, `guild/`, 기존 `characters/`와 `ui/materials/`: 별도 보존하는 웹 원본이 실제 사용하는 이미지. 현행 Godot의 SD 리그와 혼동하지 않습니다.
- `audio/`: 원본·출처와 실제 재생 manifest. 미사용 여부는 이미지와 별도로 판단합니다.

`src/data/images.ts`가 현행 이미지 연결이며 `scripts/export-godot-content.mjs`가 Godot 복사본을 만듭니다. 모든 웹용 이미지를 Godot에 복사하지는 않습니다.

2026-10-03 미사용 초기 원화·장신 파츠·트럭 원화·이전 바닥은 저장소 루트 `archive/`로 분리했습니다. 원본과 출처는 보존하며 `archive/relocations-2026-10-03.json`으로 기존 경로를 찾을 수 있습니다. 원본과 바이트가 같은 불필요한 Godot 복사본만 삭제했고 목록은 `archive/deleted-copies-2026-10-03.json`에 있습니다.

생성 프롬프트와 출처는 폴더의 provenance 기록 및 `image-provenance.json`, `combat-art-provenance.json`, `vfx-art-provenance.json`에 남깁니다. 시안·승인 갤러리와 현행 4배 PNG 원본은 원래 위치를 유지합니다. 연결 규칙은 `docs/VISUAL_GUIDE.md`, `docs/AUDIO_GUIDE.md`, `godot/docs/SD_PIPELINE.md`를 참고하세요.
