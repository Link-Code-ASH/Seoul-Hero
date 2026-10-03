# Pickup art provenance

2026-09-19 built-in `image_gen`으로 생성했으며 원본은 Codex `generated_images`에 보존한다.

- `pickups/pickup_magic_stone_01.png`: 코인·경험치 결정·마석을 통합한 연한 라벤더색 결정. 투명 배경의 세로 실루엣과 절제된 내부 발광을 사용한다. 생성 원본: `exec-7f4054aa-1804-4d62-bc7c-b9b3f637daee.png`.

프롬프트: polished semi-realistic 2D game pickup sprite, pale lavender/violet breakthrough gate material crystal, vertical faceted silhouette, restrained glow, transparent background, no coin, no text, readable at small size.

프롬프트의 공통 원칙은 반실사 2D 게임 스프라이트, 30~40px 가독성, 과도한 광택·블룸·입자 금지, 충분한 투명 여백이다.

공용 연결 정리: `pickups/pickup_magic_stone_02.png`는 기존 `godot/assets/visuals/resources/magic_stone_casual.png`를 바이트 그대로 복사한 새 공용 경로다. 새 이미지를 생성하지 않았으며 구버전 `pickup_magic_stone_01.png`와 기존 Godot 원본을 보존한다. 생성 프롬프트·출처는 `godot/assets/visuals/resources/source/provenance.json`과 `magic-stone-original.png`에 남아 있다. 캔버스 371×384px, 알파 32 초과의 검토 표시 영역 `[96,97,204,203]`, 표시 영역 높이/너비 `203/204`다. 복사 SHA-256: `498f36df222f2d37b5df28cb694cce30bd9928c9c5decb529047cf43a411fe3c`.

Manifest의 `region`은 위 검토 영역을 사용한다. 실제 종횡비는 약 `0.995098`이며, `heightRatio: 3.15`는 종횡비가 아니라 픽업 반경 대비 표시 높이 배율이므로 기존 표시 크기를 유지한다. Godot 리소스 override와 공용 이미지 ID `magicStone`은 모두 `assets/pickups/pickup_magic_stone_02.png`로 연결한다.

웹 Pixi 텍스처와 HUD·가격·회수 비행 아이콘은 같은 `region`을 잘라 표시한다. `sourceSize: [371,384]`는 DOM의 기존 배경 이미지 crop 계산을 위한 원본 캔버스 크기이며 표시 배율을 바꾸지 않는다.
