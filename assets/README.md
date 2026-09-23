현재 아레나/Wave 개편: 기존 에셋을 재사용합니다. 각성 에셋과 효과음은 제거했습니다. 생성 출처만 archive에 보존합니다. 배경은 고정 아레나 범위에 배치합니다.

# 에셋

- characters / enemies / bosses: 생성한 주인공·일반 적·보스 PNG.
- projectiles / pickups: 마력탄과 단일 재화·경험치 픽업인 마력석 PNG.
- environment: 게이트와 서울 생활 소품 5종 PNG.
- ui: 직접 작성한 SVG 체력 아이콘. 다른 UI 아이콘은 위 이미지를 재사용.
- audio/sfx: 원본 합성 효과음 10개 WAV.
- audio/bgm: 원본 합성 음악 루프 3개 WAV.

이미지는 OpenAI 내장 이미지 생성 도구로 제작했습니다. `image-provenance.json`에 각 파일의 프롬프트가 있습니다. 오디오는 `scripts/generate-audio.mjs`로 재생성할 수 있습니다. 게임은 외부 서버나 생성 도구의 원본 경로에 의존하지 않습니다.

연결 규칙은 `docs/VISUAL_GUIDE.md`, `docs/AUDIO_GUIDE.md`를 참고하세요.

주인공은 `characters/player_plaza_01.png` 원본에서 만든 `.webp` 정적 스프라이트와 코드 기반 이동 모션을 사용합니다. 적·보스·광화문 배경도 모바일 전송용 `.webp`를 읽고 고해상도 PNG 원본은 같은 폴더에 보존합니다. `scripts/optimize_mobile_art.py`로 파생 이미지를 다시 만들 수 있습니다. 폐기한 걷기 시트의 생성 이력은 `animation-provenance.json`에만 남깁니다.

제거된 에셋의 생성 출처는 archive/awakening-provenance.json에 역사 기록으로만 보관합니다. 해당 PNG와 효과음은 게임에서 사용하지 않습니다.
