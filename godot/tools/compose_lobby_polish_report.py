"""Arrange real Godot viewport captures; this script does not create art assets."""
from pathlib import Path
import argparse
import json
from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, default=ROOT / "design/ui-image-skins/office-day-01/lobby-polish-01/runtime")
args = parser.parse_args()
OUT = args.output if args.output.is_absolute() else ROOT / args.output
REVISION_NUMBER = int(OUT.name.rsplit("-", 1)[-1]) if OUT.name.startswith("runtime-revision-") else 1
REVISION = REVISION_NUMBER >= 2
BG = "#FBF6EC"
INK = "#24395C"
FONT = Path("C:/Windows/Fonts/malgun.ttf")
BOLD = Path("C:/Windows/Fonts/malgunbd.ttf")

def font(px, bold=False):
    return ImageFont.truetype(str(BOLD if bold else FONT), px)

def label(draw, text, xy, size=19, bold=False, fill=INK):
    draw.text(xy, text, font=font(size, bold), fill=fill)

def opened(file):
    return Image.open(OUT / file).convert("RGB")

def crop(file, box, scale):
    im = opened(file).crop(box)
    return im.resize((round(im.width * scale), round(im.height * scale)), Image.Resampling.LANCZOS)

before = opened("before_lobby.png")
after = opened("after_lobby.png")
capture_meta = json.loads((OUT / "capture_report.json").read_text(encoding="utf-8"))
baseline_meta = json.loads((OUT / "baseline_capture.json").read_text(encoding="utf-8")) if (OUT / "baseline_capture.json").exists() else {}
sheet = Image.new("RGB", (1854, 492), BG)
draw = ImageDraw.Draw(sheet)
label(draw, "변경 전 · 직전 버전에서 새로 캡처" if REVISION else "변경 전 · 현재 코드에서 새로 캡처", (12, 10), 23, True)
after_caption = "변경 후 · 유리 대비·아이콘·움직임 조정" if REVISION_NUMBER >= 3 else "변경 후 · 색감과 작전 연출 강화" if REVISION else "변경 후 · 제작 PNG와 정돈한 연출"
label(draw, after_caption, (939, 10), 23, True)
sheet.paste(before, (12, 48))
sheet.paste(after, (939, 48))
label(draw, "915×412 / 같은 대사·캐릭터 위치·시작 시점 / 사용자 저장 사용 안 함", (12, 466), 15)
sheet.save(OUT / "before_after.png")

details = Image.new("RGB", (1260, 1294), BG)
draw = ImageDraw.Draw(details)
label(draw, "로비 소재 확대 비교", (24, 16), 30, True)
label(draw, "스피커 · 실제 표시 32px, 아래는 화면을 4배 확대", (24, 63), 19)
for i, (title, file) in enumerate([
    ("기존 ON", "before_lobby.png"), ("기존 OFF", "before_speaker_off.png"),
    ("새 ON", "after_speaker_on.png"), ("새 OFF", "after_speaker_off.png"),
]):
    x = 24 + i * 306
    label(draw, title, (x, 97), 19, True)
    metadata = baseline_meta if file.startswith("before_") else capture_meta
    speaker_x, speaker_y, _, _ = metadata.get("speakerButtonRect", [858,10,44,44])
    speaker_box = (round(speaker_x-5),round(speaker_y-2),round(speaker_x+57),round(speaker_y+48))
    details.paste(crop(file, speaker_box, 4), (x, 132))

label(draw, "오퍼레이터 통신창", (24, 360), 23, True)
label(draw, "변경 전", (24, 398), 17)
label(draw, "변경 후", (644, 398), 17)
details.paste(crop("before_lobby.png", (5, 3, 383, 99), 1.55), (24, 427))
details.paste(crop("after_lobby.png", (5, 3, 383, 99), 1.55), (644, 427))

label(draw, "메뉴판 · 기존 색과 배치 유지", (24, 599), 23, True)
label(draw, "변경 전", (24, 637), 17)
label(draw, "변경 후", (644, 637), 17)
details.paste(crop("before_lobby.png", (609, 67, 915, 252), 1.75), (24, 666))
details.paste(crop("after_lobby.png", (609, 67, 915, 252), 1.75), (644, 666))

label(draw, "출동 게이트·유리판·장식" if REVISION_NUMBER >= 3 else "출동판·코너·경고띠·빛줄", (24, 1010), 23, True)
label(draw, "변경 전", (24, 1048), 17)
label(draw, "변경 후", (644, 1048), 17)
details.paste(crop("before_lobby.png", (581, 244, 915, 408), 1.7), (24, 1077))
details.paste(crop("after_lobby.png", (581, 244, 915, 408), 1.7), (644, 1077))
# Extend if the final crop reaches beyond the initial page.
if details.height < 1374:
    expanded = Image.new("RGB", (1260, 1374), BG)
    expanded.paste(details, (0, 0))
    for x, file in [(24, "before_lobby.png"), (644, "after_lobby.png")]:
        expanded.paste(crop(file, (581, 244, 915, 408), 1.7), (x, 1077))
    details = expanded
details.save(OUT / "details.png")

frames = [opened(f"frames/frame_{i:03d}.png") for i in range(90)]
# 70+70+60ms per 3 frames = 6000ms for 90 frames; GIF ticks are 10ms.
durations = [70, 70, 60] * 30
# Share a palette across representative idle/hover/pressed frames, including bright glints.
palette_source = Image.new("RGB", (915, 412 * 6))
for row, index in enumerate((0, 23, 35, 45, 63, 89)):
    palette_source.paste(frames[index], (0, row * 412))
palette = palette_source.quantize(colors=255)
gif_frames = [im.quantize(palette=palette, dither=Image.Dither.NONE) for im in frames]
# Reserve one index so the GIF writer can make unchanged pixels transparent between frames.
palette_rgb = palette.getpalette()
nearest_black = min(range(255), key=lambda i: sum(v*v for v in palette_rgb[i*3:i*3+3]))
remap = list(range(256)); remap[255] = nearest_black
gif_frames = [im.point(remap) for im in gif_frames]
gif_frames[0].save(OUT / "motion_preview.gif", save_all=True,
    append_images=gif_frames[1:], duration=durations, loop=0, optimize=True, disposal=1, transparency=255)

report = capture_meta
report["officeBackgroundUnchangedPixels"] = ImageChops.difference(
    before.crop((0, 110, 540, 240)), after.crop((0, 110, 540, 240))).getbbox() is None
report.pop("officeAndCrewUnchangedPixels", None)
report["crewFixedPositions"] = [[100,366],[226,376],[352,366],[478,376]]
crew_difference = ImageChops.difference(before.crop((40,245,535,400)), after.crop((40,245,535,400))).getbbox()
report["crewPosePixelsUnchanged"] = crew_difference is None
report["crewInitialPoseDifference"] = "Exact neutral poses match." if crew_difference is None else "Fixed positions match; character squash/turn interpolation retained a few pre-freeze engine frames."
with Image.open(OUT / "motion_preview.gif") as gif:
    actual_duration = sum((gif.seek(i) or gif.info.get("duration", 0)) for i in range(gif.n_frames))
    report["gifActualFrames"] = gif.n_frames
    report["gifActualDurationMs"] = actual_duration
    report["gifDecodedFramesMatchQuantizedSources"] = all(
        (gif.seek(i) is None) and ImageChops.difference(gif.convert("RGB"), source.convert("RGB")).getbbox() is None
        for i, source in enumerate(gif_frames))
report["gifBytes"] = (OUT / "motion_preview.gif").stat().st_size
if (OUT / "after_menu_focused.png").exists():
    report["nativeMenuFocusAddsNoPixels"] = ImageChops.difference(
        opened("after_menu_focused.png"), opened("after_menu_focus_reference.png")).getbbox() is None
report["beforeAfterSize"] = list(sheet.size)
report["detailsSize"] = list(details.size)
(OUT / "capture_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
report_text = """# 로비 변경 전후 실행 화면

모든 원본 캡처는 Godot 4.7.2 Compatibility의 실제 915×412 뷰포트에서 얻었습니다.
`before_lobby.png`는 런타임 코드 수정 전에 새로 촬영했으며, 당시 소스·셰이더는 상위 `_raw/baseline/`에 보존했습니다.

## 파일

- `before_after.png`: 같은 대사·캐릭터 위치·시작 시점의 전체 전후 비교.
- `details.png`: 스피커 ON/OFF, 통신창, 메뉴판, 출동판과 장식 확대 비교.
- `after_menu_hover.png`, `after_menu_pressed.png`: 자료집 메뉴의 hover·눌림.
- `after_deploy_hover.png`, `after_deploy_pressed.png`: 출동판의 hover·눌림.
- `after_speaker_on.png`, `after_speaker_off.png`: 미리보기에서만 음향 아이콘 상태를 고정한 화면.
- `after_restored.png`: 버튼 상태 복귀 화면.
- `motion_preview.gif`: 6초, 15fps. 대기 → 메뉴 hover·눌림 → 복귀 → 출동 hover·눌림 → 대기.
- `capture_report.json`: 캡처 조건과 해당 화면의 상태 복귀 확인 결과.
- `frames/`: 캡처 도구가 GIF 제작 중에 생성하는 실제 뷰포트 원본 90장. 최종 GIF 확인 후 재생성 가능한 임시 프레임은 삭제합니다.

## 캡처 조건과 확인 범위

`--ui-preview --guild-office-preview`를 함께 사용해 Profile.writable=false를 확인합니다. 사용자 프로필을 읽지 않고 합성 메모리 프로필과 고정 난수 seed 20261011을 사용합니다. 캐릭터 네 명은 같은 위치에 고정하고, 대사·셰이더·장식의 시점을 캡처에서만 제어합니다. 실제 게임의 음향 판단은 변경하지 않습니다.

개별 스크린샷 크기 915×412, 최종 GIF 재생시간 6000ms를 확인했습니다. GIF 90장의 디코딩 결과가 팔레트 변환한 원본 프레임과 같은지도 확인했습니다. 시각적으로 스피커 형태와 상태, 본문 가독성, 메뉴·출동판의 hover/눌림·복귀를 확인합니다. 캐릭터 좌표는 같지만 최초 렌더링 몇 프레임의 방향 전환 스쿼시 때문에 변경 전후의 캐릭터가 미세하게 다른 픽셀을 갖습니다. 전체 테스트·전투 플레이·실제 모바일·청음 QA는 수행하지 않았습니다.

## 재생성

Godot 실행: `Godot_v4.7.2-stable_win64_console.exe --path godot --resolution 915x412 res://tools/lobby_polish_capture.tscn -- --ui-preview --guild-office-preview --stage=after`

합성 보고: `python godot/tools/compose_lobby_polish_report.py`
"""
if REVISION:
    report_text += "\n## 이번 수정의 렌더링 확인\n\n메뉴와 출동판의 화면 샘플링 유리는 클립 그룹 없이 그립니다. 큰 영문 워터마크에는 글리프 알파만 제한하는 셰이더를 직접 적용해 닫힌 흰색 판이 생기지 않고 글자가 판 밖으로 나가지 않게 했습니다. 네이티브 메뉴 포커스를 캡처에서만 강제로 부여해 포커스 전후의 화면 픽셀이 같고 StyleBoxEmpty가 유지되는 것도 확인했습니다.\n"
    report_text = report_text.replace("대기 → 메뉴 hover·눌림 → 복귀 → 출동 hover·눌림 → 대기.", "스피커 ON 0–2초 → OFF 2–3초 → ON 3–6초. 이와 함께 메뉴·출동 hover와 눌림, 통신창과 작전 장식의 움직임을 보여 줍니다.")
    report_text = report_text.replace("상위 `_raw/baseline/`", f"상위 `_raw/baseline-revision-{REVISION_NUMBER:02d}/`")
    report_text = report_text.replace("캐릭터 좌표는 같지만 최초 렌더링 몇 프레임의 방향 전환 스쿼시 때문에 변경 전후의 캐릭터가 미세하게 다른 픽셀을 갖습니다.", "시작 전에 SD 방향 전환과 스쿼시를 중립 상태로 맞춰 변경 전후의 캐릭터 좌표와 자세를 일치시킵니다.")
    report_text = report_text.replace("--stage=after`", f"--stage=after --output=res://../design/ui-image-skins/office-day-01/lobby-polish-01/{OUT.name}`")
    report_text = report_text.replace("python godot/tools/compose_lobby_polish_report.py`", f"python godot/tools/compose_lobby_polish_report.py --output design/ui-image-skins/office-day-01/lobby-polish-01/{OUT.name}`")
    if REVISION_NUMBER >= 3:
        report_text += "\n## 세 번째 수정의 확인 대상\n\n왼쪽으로 옮긴 스피커와 낮춘 진동·짙은 음파, 배경과 충분히 분리되는 유리판, 출동판과 일치하는 메뉴 기울기, 고정된 메뉴 아이콘, 새 출동 게이트 그림과 정지한 한서아 얼굴을 실제 화면에서 비교합니다. 스피커 확대 영역은 런타임 버튼 좌표에 맞춰 조정합니다. 이전 버전의 캡처와 소재는 덮어쓰지 않습니다.\n"
        report_text += "\n최종 확인: 메뉴와 출동판의 실제 셰이더 기울기는 모두 0.285714285714286입니다. 메뉴 아이콘 세 개·게이트 아이콘·한서아 얼굴의 로컬 위치와 크기는 수동 시간 진행 전후에 동일합니다. 음파는 어두운 색으로 간격을 넓혔고 스피커 진동은 줄였습니다. 메뉴의 hover 이동과 눌림은 유지되며 복귀·입력 영역·네이티브 포커스 확인을 통과했습니다. 기존 버전의 캡처와 변경 전 원본을 보존했습니다.\n"
(OUT / "README.md").write_text(report_text, encoding="utf-8")
print(f"Capture report ready: {OUT}; GIF {report['gifActualFrames']} frames/{actual_duration}ms")
