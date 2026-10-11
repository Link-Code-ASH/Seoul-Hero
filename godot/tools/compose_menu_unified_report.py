"""Compose approval or applied UI evidence; never modifies source artwork or runtime UI."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


PROJECT = Path(__file__).resolve().parents[2]
DEFAULT_RUNTIME = PROJECT / "design/ui-image-skins/office-day-01/menu-unified-01/runtime"
FONT_PATH = Path("C:/Windows/Fonts/malgun.ttf")
BG = "#E9EEF2"
INK = "#23364D"
ACCENT = "#217F80"
SCREEN_KEYS = ["settings", "archive-characters", "association-draw", "gate-formation"]
SCREEN_LABELS = ["설정", "자료집", "협회", "출동 준비 · 편성"]
STEP_KEYS = ["map", "floor", "character", "weapon", "blessing", "formation"]
STEP_LABELS = ["01 맵 선택", "02 층 선택", "03 각성자 선택", "04 시작 무기 선택", "05 단군의 축복 선택", "06 편성 확인"]


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    return ImageFont.truetype(str(FONT_PATH), size) if FONT_PATH.exists() else ImageFont.load_default()


def open_rgb(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGB")


def grid(items: list[tuple[Image.Image, str]], columns: int, destination: Path, title: str, width: int = 915) -> None:
    gap, label_height, top = 14, 38, 58
    images = []
    for image, caption in items:
        height = round(image.height * width / image.width)
        images.append((image.resize((width, height), Image.Resampling.LANCZOS), caption))
    rows = (len(images) + columns - 1) // columns
    row_heights = [max(image.height for image, _ in images[row*columns:(row+1)*columns]) + label_height for row in range(rows)]
    sheet = Image.new("RGB", (columns * width + (columns + 1) * gap, top + sum(row_heights) + (rows + 1) * gap), BG)
    draw = ImageDraw.Draw(sheet)
    draw.text((gap, 13), title, font=font(25), fill=INK)
    for index, (image, caption) in enumerate(images):
        x = gap + (index % columns) * (width + gap)
        row = index // columns
        y = top + gap + sum(row_heights[:row]) + row * gap
        draw.text((x, y + 4), caption, font=font(19), fill=INK)
        sheet.paste(image, (x, y + label_height))
    sheet.save(destination, optimize=True)


def gif(frames_dir: Path, destination: Path) -> dict:
    paths = sorted(frames_dir.glob("frame_*.png"))
    if len(paths) != 90:
        raise ValueError(f"Expected 90 real viewport frames, found {len(paths)}")
    # One balanced palette prevents the static office photograph from shimmering
    # between independently quantized frames. Include every screen and button state.
    samples = [open_rgb(paths[i]).resize((458, 206), Image.Resampling.LANCZOS) for i in range(0, 90, 4)]
    palette_sheet = Image.new("RGB", (458 * 4, 206 * ((len(samples) + 3) // 4)), BG)
    for i, sample in enumerate(samples):
        palette_sheet.paste(sample, ((i % 4) * 458, (i // 4) * 206))
    palette = palette_sheet.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    indexed = [open_rgb(path).quantize(palette=palette, dither=Image.Dither.NONE) for path in paths]
    durations = [60, 70, 70] * 30
    indexed[0].save(destination, save_all=True, append_images=indexed[1:], duration=durations, loop=0, disposal=1, optimize=True)
    with Image.open(destination) as decoded:
        frame_count, duration, source_index, exact = decoded.n_frames, 0, 0, True
        for i in range(decoded.n_frames):
            decoded.seek(i)
            frame_duration = int(decoded.info.get("duration", 0))
            duration += frame_duration
            frame_rgb = decoded.convert("RGB")
            elapsed = 0
            while source_index < len(indexed) and elapsed < frame_duration:
                exact = exact and frame_rgb.tobytes() == indexed[source_index].convert("RGB").tobytes()
                elapsed += durations[source_index]
                source_index += 1
    return {"sourceFrames":90,"gifFrames":frame_count,"durationMs":duration,"sharedPalette":True,"decodedMatchesQuantizedLatestFrames":exact,"decodedCoversSourceFrames":source_index == 90,"bytes":destination.stat().st_size,"sourceFrameSha256":[hashlib.sha256(path.read_bytes()).hexdigest() for path in paths]}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime", type=Path, default=DEFAULT_RUNTIME)
    parser.add_argument("--stage", choices=["preview", "applied"], default="preview")
    parser.add_argument("--report-only", action="store_true", help="Merge a fresh focused check without replacing verified images or GIF")
    args = parser.parse_args()
    runtime = args.runtime.resolve()
    before, preview = runtime / "before", runtime / args.stage
    report_dir = runtime if args.stage == "preview" else preview
    applied = args.stage == "applied"
    shown_label = "적용 후" if applied else "시안"
    baseline = json.loads((before / "manifest.json").read_text(encoding="utf-8"))
    proposed = json.loads((preview / "manifest.json").read_text(encoding="utf-8"))
    focus_path = preview / "focus_check.json"
    focused = json.loads(focus_path.read_text(encoding="utf-8")) if applied and focus_path.exists() else None
    if focused:
        checked_titles = {check["title"] for check in proposed["checks"]}
        proposed["checks"] += [check for check in focused["checks"] if check["title"] not in checked_titles]
    if not args.report_only:
        grid([(open_rgb(preview / f"{key}.png"), label) for key, label in zip(SCREEN_KEYS, SCREEN_LABELS)], 2, report_dir / "contact_sheet.png", "적용된 메뉴 · 로비와 같은 운영 UI" if applied else "승인 전 시안 · 현재 로비와 같은 운영 UI")
    pairs = []
    for key, label in zip(SCREEN_KEYS, SCREEN_LABELS):
        pairs += [(open_rgb(before / f"{key}.png"), f"변경 전 · {label}"), (open_rgb(preview / f"{key}.png"), f"{shown_label} · {label}")]
    if not args.report_only:
        grid(pairs, 2, report_dir / "before_after.png", "현재 적용 전후 · 동일 합성 프로필" if applied else "현재 실행 화면과 승인 전 시안 · 동일 합성 프로필")
        grid([(open_rgb(preview / f"gate-{key}.png"), label) for key, label in zip(STEP_KEYS, STEP_LABELS)], 2, report_dir / "deployment_steps.png", "출동 준비 · 기존 여섯 단계 유지")
    state_items = [
        ("settings-slider", "네이티브 음량 조작 · 즉시 반영", (0, 50, 540, 412)),
        ("association-no-funds", "재화 부족 · 모집 비활성", (330, 50, 915, 412)),
        ("association-complete", "모두 해금 · 중복 모집 차단", (330, 50, 915, 412)),
        ("association-blessing-draw-result" if applied else "association-reward-settled", "협회 결과 · 연출 후 확인 상태", (80, 35, 835, 395)),
        ("gate-blessing-locked", "잠금 항목 · 상세 열람과 선택 분리", (565, 50, 915, 350)),
        ("gate-floor-page", "21–40층 페이지 · 잠금과 진행 표시", (0, 50, 915, 345)),
        ("gate-blessing-none", "축복 없음 · 선택 후 진행 가능", (0, 50, 915, 345)),
        ("gate-primary-hover", "주 행동 · hover", (610, 335, 915, 412)),
        ("gate-primary-pressed", "주 행동 · 눌림", (610, 335, 915, 412)),
    ]
    if applied:
        state_items[4:4] = [
            ("association-character-draw-result", "각성자 모집 · 큰 원화와 이름 공개", (80, 35, 835, 395)),
            ("association-weapon-draw-result", "무기 보급 · 획득한 무기 공개", (80, 35, 835, 395)),
            ("association-upgrade-vitality-complete", "협회 강화 · 수치 증가와 완료 안내", (330, 50, 915, 360)),
            ("association-upgrade-circuit-complete", "영구 해금 · 완료 안내", (330, 50, 915, 360)),
        ]
    if args.report_only:
        existing = json.loads((report_dir / "capture_report.json").read_text(encoding="utf-8"))
        gif_result = existing["motion"]
        latest_frame_hashes = [hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted((preview / "frames").glob("frame_*.png"))]
        if latest_frame_hashes != gif_result["sourceFrameSha256"]:
            raise ValueError("Report-only requires the same previously verified motion frames")
    else:
        grid([(open_rgb(preview / f"{key}.png").crop(rect), label) for key, label, rect in state_items], 2, report_dir / "details.png", "조작·선택·협회 연출 확대 · 실제 Godot 화면" if applied else "조작·선택 상태 확대 · 실제 Godot 화면", width=600)
        gif_result = gif(preview / "frames", report_dir / "motion_preview.gif")
    image_sizes = {}
    for folder, manifest in [(before, baseline), (preview, proposed)]:
        for shot in manifest["shots"]:
            path = folder / shot["file"]
            with Image.open(path) as image:
                image_sizes[str(path.relative_to(runtime))] = list(image.size)
    logs = []
    for path in sorted(runtime.glob("applied*engine*.log" if applied else "*engine*.log")):
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if re.search(r"(SCRIPT ERROR|Parse Error|Shader compilation failed|Error loading|Failed loading|Could not load)", line, re.I):
                logs.append({"file":path.name,"line":line})
    same_profiles = baseline["profile"] == proposed["profile"]
    same_baseline_states = []
    by_name = {shot["file"]:shot for shot in proposed["shots"]}
    for shot in baseline["shots"]:
        other = by_name.get(shot["file"], {})
        same_baseline_states.append({"file":shot["file"],"same":all(shot.get(key) == other.get(key) for key in ["screen","gateStep","draft","archive","associationId","coins"])})
    report = {
        "approvalStageOnly":not applied,"productionPresentationDefault":proposed.get("productionPresentationDefault", False),
        "captureStage":args.stage,"presentationOverride":proposed.get("presentationOverride", True),
        "baselineFreshFromProductionMain":baseline["productionMainScene"],
        "sameSyntheticProfiles":same_profiles,"sameBaselineSelections":same_baseline_states,
        "allViewportPngs915x412":all(size == [915,412] for size in image_sizes.values()),
        "userProfileRead":False,"saveWrites":False,"combatStarted":False,"userFileActionsInvoked":False,
        "nativeUiChecks":proposed["checks"],"scriptShaderLoadErrors":logs,
        "motion":gif_result,"pngSizes":image_sizes,
        "baselineManifestSha256":hashlib.sha256((before / "manifest.json").read_bytes()).hexdigest(),
        "previewManifestSha256":hashlib.sha256((preview / "manifest.json").read_bytes()).hexdigest(),
        "focusedApplicationValidation":focused,
        "sourceCodeSha256":{name:hashlib.sha256((PROJECT / name).read_bytes()).hexdigest() for name in [
            "godot/scripts/core/main.gd","godot/scripts/ui/desk_kit.gd","godot/scripts/ui/archive.gd",
            "godot/scripts/ui/gate_screen.gd","godot/scripts/ui/meta_screens.gd","godot/scripts/ui/economy_ui.gd",
            "godot/scripts/ui/association_feedback.gd","godot/tools/menu_unified_capture.gd"] if (PROJECT / name).exists()},
    }
    (report_dir / "capture_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    failures = [check for check in proposed["checks"] if not check["passed"]]
    readme = f"""# 메뉴 통일 · 승인 전 실제 화면 시안

현재 로비의 밝은 사무실·비스듬한 유리·기능별 포인트 색을 설정/자료집/협회/출동 준비에 적용한 시안입니다. **실제 게임의 기본 디자인은 변경하지 않았습니다.** `HeroDesk.presentation` 기본값은 `false`이며 이 캡처의 `--stage=preview`에서만 켭니다.

- `before/`: 새 도구가 변경 전 실제 main 씬으로 촬영한 15장. 기존 저장 이미지를 대신 사용하지 않았습니다.
- `preview/`: 동일 프로필·선택값의 시안 15장과 조작/잠금/재화/층 페이지 상태. 협회 결과는 초기 `association-reward.png`와 보상 연출을 진행한 `association-reward-settled.png`를 구분합니다.
- `contact_sheet.png`: 네 화면 시안. `before_after.png`: 네 화면 전후 비교.
- `deployment_steps.png`: 출동 준비 여섯 단계. `details.png`: 조작과 상태 확대.
- `motion_preview.gif`: 실제 Godot viewport {gif_result['sourceFrames']}개 프레임, {gif_result['durationMs']}ms. 저장/전투 동작 없이 hover·눌림·복귀와 유리 연출을 보여 줍니다.

캡처는 915×412, seed {baseline['seed']}, 고정 주차 {baseline['fixedWeek']}를 사용했습니다. 코인 1850, 네 각성자와 일곱 시작 무기, 첫 축복 하나 해금, 최고 해금 25층인 합성 메모리 상태이며 선택은 광화문/1층/송진우/마력탄/첫 축복입니다. 전후 합성 프로필 일치: `{same_profiles}`. 전후 선택값 일치: `{all(item['same'] for item in same_baseline_states)}`.

두 플래그 `--ui-preview --guild-office-preview`를 강제하고 `Profile.writable=false`를 확인했습니다. 플레이어 프로필/백업/체크포인트 내용을 읽거나 쓰지 않았고, 저장 폴더·백업·가져오기 버튼을 실행하지 않았습니다. 전투 시작과 뽑기/구매 지급은 실행하지 않았습니다. 네이티브 슬라이더, 자료집 분류/항목/상세, 층 페이지, 잠금 상세, 축복 없음, 편성 수정, 버튼 입력 크기·복귀·포커스만 시안에서 확인했습니다. 협회 팝업은 합성 payload로 표시한 뒤 기존 LootShower의 `advance()`로 3초 진행하고 확인 버튼을 눌렀으며, 표시·연출·닫기 전후 프로필 일치를 확인했습니다.

확인 실패 {len(failures)}개, 스크립트/셰이더/소재 로딩 오류 {len(logs)}개. GIF는 공통 팔레트로 정적 배경의 색 흔들림을 줄였으며 최신 소스 프레임과 디코딩 RGB 일치: `{gif_result['decodedMatchesQuantizedLatestFrames']}`. 전체 테스트·전투 플레이·실기기/청음 검증은 하지 않았습니다. 자세한 체크와 PNG 크기는 `capture_report.json`, 선택값은 각 폴더의 `manifest.json`에 있습니다.

도구: `godot/tools/menu_unified_capture.tscn -- --ui-preview --guild-office-preview --stage=preview`; 합성 전후 캡처 조합은 `godot/tools/compose_menu_unified_report.py`입니다. 소재 원본·프롬프트는 상위 시안 폴더에서 보존합니다.
"""
    if applied:
        readme = f"""# 메뉴 통일 · 실제 적용 화면과 협회 연출

설정/자료집/협회/출동 준비에 승인된 사무실 유리 UI를 적용한 실제 main 씬 캡처입니다. `HeroDesk.presentation=true` 기본값을 그대로 사용했고 캡처에서 디자인 플래그를 덮어쓰지 않았습니다. 소재는 내부 `res://assets/ui/office-day-01/menu-unified-01/`에서 불러옵니다.

- `../before/`: 변경 전에 새로 촬영한 원래 실행 화면 15장. 수정하지 않았습니다.
- `../preview/`와 상위 승인용 보고서: 이전 승인 시안 보존.
- 이 폴더: 동일 합성 프로필의 적용 화면 15장과 조작/잠금/재화/층 페이지/협회 결과 상태.
- `contact_sheet.png`: 네 화면, `before_after.png`: 네 화면 전후, `deployment_steps.png`: 출동 여섯 단계, `details.png`: 상태·연출 확대.
- `motion_preview.gif`: 실제 Godot viewport 90프레임, {gif_result['durationMs']}ms. hover·눌림·복귀, 뽑기 2초, 스탯 강화와 해금 각 0.8초를 담습니다. `frames/`에 최신 원본을 보존합니다.

915×412, seed {baseline['seed']}, 고정 주차 {baseline['fixedWeek']}, 코인 1850, 네 각성자·일곱 시작 무기·첫 축복·최고 25층인 합성 상태를 사용했습니다. 대표 화면은 전후 프로필 일치 `{same_profiles}`, 15개 선택값 일치 `{all(item['same'] for item in same_baseline_states)}`입니다. 협회 결과 상태만 종류별 미해금 후보 하나 또는 강화 대상을 메모리에 구성했습니다.

`--ui-preview --guild-office-preview`와 `Profile.writable=false`를 강제했습니다. 사용자 프로필·백업·체크포인트 내용 읽기, 실제 저장·가져오기·외부 폴더 열기·전투 시작은 수행하지 않았습니다. 메인의 실제 `_association_transaction()`에 메모리 fake commit을 넣어 각성자/무기/축복 뽑기와 스탯/해금 성공의 1회 차감·1회 commit, 부족 재화·전체 해금 거절, commit 실패 롤백을 확인했습니다. 실제 저장 콜백을 호출하는 결제 UI 요청은 읽기 전용 경계에서 차단했습니다.

뽑기 결과는 실제 `HeroAssociationFeedback.draw()` 연결로 보여 줬습니다. 첫 확인/뒤로가기는 즉시 공개, 두 번째는 닫기를 확인했습니다. busy 중 분류·반복 요청은 프로필과 선택을 유지했고 포커스 상실은 완성 상태로 정리되어 남은 광택/입자가 숨겨지며 소리 상태를 바꾸지 않았습니다. 강화는 실제 payload의 이전/다음 수치를 `play()`에 넘겨 0.8초 진행·입력 복귀·완료 안내를 확인했습니다. 출동의 독립 안내 줄·하단 설명 제거, 기존 6단계·잠금 상세·편성 수정·44px 입력·상태 복귀도 확인했습니다. 마지막 새 프로세스에서는 앱 포커스 상실 시 1.5px 눌림·광택·Tween을 즉시 정리하고 복귀 후 기본 위치를 유지하는 좁은 확인을 추가했습니다. 시각 변경이 없어 검증된 PNG/GIF는 유지했습니다.

확인 {len(proposed['checks'])}개 중 실패 {len(failures)}개, 스크립트/셰이더/소재 로딩 오류 {len(logs)}개. 공통 GIF 팔레트를 사용했고 최신 90개 프레임을 디코딩 RGB로 검증한 결과 `{gif_result['decodedMatchesQuantizedLatestFrames']}`입니다. 전체 테스트·전투 플레이·실기기/청음 검증은 하지 않았습니다. 상세 확인·PNG 크기·프레임 해시는 `capture_report.json`과 `manifest.json`에 있습니다.

재생성: `godot/tools/menu_unified_capture.tscn -- --ui-preview --guild-office-preview --stage=applied`, 보고서 조합: `godot/tools/compose_menu_unified_report.py --stage=applied`.
"""
    (report_dir / "README.md").write_text(readme, encoding="utf-8")
    print(json.dumps({"runtime":str(report_dir),"nativeCheckCount":len(proposed["checks"]),"nativeCheckFailures":failures,"scriptShaderLoadErrors":logs,"sameSyntheticProfiles":same_profiles,"sameBaselineSelections":all(item["same"] for item in same_baseline_states),"motion":{key:value for key,value in gif_result.items() if key != "sourceFrameSha256"}}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
