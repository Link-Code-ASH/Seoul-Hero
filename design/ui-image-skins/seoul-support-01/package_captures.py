"""Package approved runtime Godot captures, without painting over any frame.

Run after both the 915x412 captures and the 4x native stills have finished.
The production game, source art, asset manifest and prompts are never modified.
"""
from hashlib import sha256
from html import escape
import json
from pathlib import Path
from shutil import copyfile

from PIL import Image


TARGET = Path(__file__).resolve().parent
REPO = TARGET.parents[2]
CAPTURES = TARGET / "runtime-captures"
MASTERS = TARGET / "runtime-masters"
SIZE = (915, 412)
MASTER_SIZE = (3660, 1648)
FRAME_COUNT = 66
STILLS = (
    "recovery-ready", "supply-ready", "recovery-empty",
    "recovery-claimed", "supply-insufficient",
    "supply-result1", "supply-result10",
)
CLIPS = {
    "recovery-idle": ("지면에 놓인 패키지와 낮게 부유하는 드론", "패키지는 바닥에 안정적으로 놓이고 드론만 낮게 부유합니다. 느린 표시등 변화와 함께 글자·정보판은 고정됩니다."),
    "recovery-claim": ("회수 패키지 착지 마무리", "수령 콜백이 성공한 뒤 짧은 착지 마무리와 작은 획득빛을 표시합니다. 이 캡처의 콜백은 실제 저장·지급을 차단한 고정 검토 상태입니다."),
    "supply-idle": ("보급 패키지의 대기", "봉인 표시등의 은은한 변화만 보여줍니다."),
    "supply-open": ("1회 개봉", "봉인 해제 → 분리된 뚜껑 열림 → 내부빛 → 결과 등장. 실제 게임은 이미 지급·저장한 추첨 결과를 표시하며, 이 캡처는 지급을 차단한 고정 결과입니다."),
    "supply-ten": ("10회 묶음 개봉", "개봉 연출은 한 번만 진행하고 묶음 결과를 보여줍니다. 실제 게임은 10회 추첨 결과를 사용하며, 캡처에서는 추첨·소비·지급을 하지 않습니다."),
}
SOURCE_ART = (
    ("recovery_background.png", "회수 · 서울 골목 배송 거점"),
    ("recovery_drone.png", "회수 · 작은 배송 드론"),
    ("recovery_package.png", "회수 · 분류 패키지"),
    ("supply_background.png", "보급 · 동네 협회 데스크"),
    ("supply_package_body.png", "보급 · 상자 본체"),
    ("supply_package_lid.png", "보급 · 분리된 뚜껑"),
    ("package_ground_shadow.png", "공용 · 패키지 바닥 접촉 그림자"),
    ("support_glass_panel.png", "공용 · 얇은 유리 정보판"),
)


def image_size(path: Path, expected: tuple[int, int]) -> None:
    if not path.is_file():
        raise RuntimeError(f"Missing native image: {path}")
    with Image.open(path) as image:
        if image.size != expected:
            raise RuntimeError(f"Wrong native image size: {path.name}: {image.size}, expected {expected}")


def validate_report(path: Path, expected_size: tuple[int, int], animated: bool) -> dict:
    report = json.loads(path.read_text(encoding="utf-8"))
    if report.get("size") != list(expected_size):
        raise RuntimeError(f"Capture report has wrong viewport size: {path}")
    if report.get("stage") != "approved-runtime":
        raise RuntimeError("Only approved runtime captures may be packaged here.")
    if report.get("runtimeConnected") is not True or report.get("fixtureCallbacks") is not True:
        raise RuntimeError("Captures must use connected runtime classes with isolated fixture callbacks.")
    if report.get("silent") is not True or report.get("passed") is not True:
        raise RuntimeError("Captures must be silent and their scoped diagnostics must pass.")
    for boundary in ("saveWrites", "rewardAssignment", "simulation"):
        if report.get(boundary) is not False:
            raise RuntimeError(f"Capture boundary is not explicitly false: {boundary}")
    checks = report.get("checks", [])
    if len(checks) != (12 if animated else 7):
        raise RuntimeError(f"Incomplete capture diagnostics: {len(checks)} checks in {path}")
    failures = []
    for check in checks:
        if check.get("fitIssues") or check.get("missingArt"):
            failures.append(check)
    if failures:
        raise RuntimeError(f"Capture layout or artwork diagnostics failed: {json.dumps(failures, ensure_ascii=False)}")
    if animated:
        lifecycle = report.get("lifecycle", [])
        if len(lifecycle) != 12 or any(check.get("passed") is not True for check in lifecycle):
            raise RuntimeError("The twelve scoped lifecycle checks must pass.")
        records = {record["id"]: record for record in report.get("scenes", [])}
        if set(records) != set(CLIPS):
            raise RuntimeError("The five runtime animation records are incomplete.")
        for name, record in records.items():
            if record.get("frames") != FRAME_COUNT:
                raise RuntimeError(f"Incomplete animation record: {name}")
            if record.get("maximumParticles", 0) > 48:
                raise RuntimeError(f"Menu particle limit exceeded: {name}")
    return report


def validate_inputs() -> dict:
    report = validate_report(CAPTURES / "capture.json", SIZE, animated=True)
    validate_report(MASTERS / "capture.json", MASTER_SIZE, animated=False)
    for name in STILLS:
        image_size(CAPTURES / f"{name}.png", SIZE)
        image_size(MASTERS / f"{name}.png", MASTER_SIZE)
    for folder in ("revision-01", "revision-02"):
        for kind in ("recovery", "supply"):
            image_size(TARGET / folder / f"{kind}-ready.png", SIZE)
    for name in CLIPS:
        paths = sorted((CAPTURES / name).glob("*.png"))
        expected = [f"{index:03d}.png" for index in range(FRAME_COUNT)]
        if [path.name for path in paths] != expected:
            raise RuntimeError(f"Animation must contain exactly 000.png–065.png: {name}")
        for path in paths:
            image_size(path, SIZE)
    for name, _ in SOURCE_ART:
        if not (TARGET / "source" / name).is_file():
            raise RuntimeError(f"Missing source PNG: {name}")
    for name in ("asset_manifest.json", "prompts.json"):
        json.loads((TARGET / "source" / name).read_text(encoding="utf-8"))
    return report


def encode_clip(name: str) -> None:
    frames = []
    try:
        for index in range(FRAME_COUNT):
            with Image.open(CAPTURES / name / f"{index:03d}.png") as image:
                frames.append(image.convert("RGBA"))
        frames[0].save(
            TARGET / f"{name}.webp", save_all=True, append_images=frames[1:],
            duration=[33, 33, 34] * 22, loop=0, lossless=True, method=4,
        )
    finally:
        for frame in frames:
            frame.close()


def image_tag(path: str, alt: str, revision: str, lazy: bool = True) -> str:
    loading = ' loading="lazy"' if lazy else ' fetchpriority="high"'
    return (f'<img{loading} src="{path}?v={revision}" width="915" height="412" '
            f'alt="{escape(alt)}">')


def clip_section(name: str, revision: str) -> str:
    title, description = CLIPS[name]
    return (f'<article id="{name}" class="clip"><h3>{title}</h3><p>{description}</p>'
            f'{image_tag(name+".webp", title+" · 적용된 Godot 화면 애니메이션", revision)}'
            f'<p class="meta"><a href="{name}.webp?v={revision}" target="_blank">무손실 애니메이션 원본</a>'
            f' · <a href="runtime-captures/{name}/" target="_blank">네이티브 프레임</a> · 30fps · 2.2초 반복 · 무음</p></article>')


def still_section(kind: str, title: str, description: str, revision: str) -> str:
    return (f'<section id="{kind}"><p class="eyebrow">APPROVED RUNTIME 03 · 실제 게임 연결 완료</p><h2>{title}</h2>'
            f'<p>{description}</p>{image_tag(kind+"-ready.png", title+" · 915×412 실제 화면", revision, lazy=False)}'
            f'<p class="meta"><a href="{kind}-ready.png?v={revision}" target="_blank">915×412 적용 결과</a>'
            f' · <a href="runtime-masters/{kind}-ready.png?v={revision}" target="_blank">4배 네이티브 합성 원본 · 3660×1648</a></p>')


def write_gallery(report: dict) -> None:
    revision_hash = sha256()
    for path in (CAPTURES / "capture.json", CAPTURES / "recovery-ready.png", CAPTURES / "supply-ready.png"):
        revision_hash.update(path.read_bytes())
    revision = revision_hash.hexdigest()[:10]
    page = '''<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>서울 히어로 · 회수와 보급 실제 적용 · Approved Runtime 03</title><style>
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:#edf2f2;color:#213b47;font:16px/1.7 system-ui,"Malgun Gothic",sans-serif}
main{width:min(1011px,100%);margin:auto;padding:32px 48px 64px}h1{font-size:30px;line-height:1.4;margin:8px 0 16px}h2{font-size:25px;line-height:1.4;margin:4px 0 12px}h3{font-size:19px;margin:0 0 6px}
p{margin:10px 0 16px}a{color:#27716e;text-underline-offset:3px}nav{display:flex;flex-wrap:wrap;gap:10px 22px;padding:16px 0;margin:22px 0 32px;border-block:1px solid #c6d7d7}
img{display:block;width:100%;height:auto;background:#e2e9e9}section{margin:42px 0 56px}.clip{margin:30px 0}.meta{font-size:13px;color:#61767d}.eyebrow{font-size:13px;letter-spacing:.08em;color:#4c8580;margin-bottom:4px}
.notice{padding:16px 20px;background:#f9fcfb;border-left:4px solid #6caaa0}.notice strong{display:block;margin-bottom:4px}.states details{margin:14px 0}details{padding:14px 0;border-top:1px solid #cbd9da}summary{cursor:pointer;font-weight:600;color:#27716e}.comparison img{margin:14px 0}.assets{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:18px;margin-top:20px}.assets figure{margin:0}.assets img{height:128px;object-fit:contain;background:#dfe9e7}.assets figcaption{font-size:13px;margin-top:5px}.footer{border-top:1px solid #c6d7d7;padding-top:20px}
@media(max-width:760px){main{padding:24px 12px 40px}h1{font-size:25px}h2{font-size:22px}.assets{grid-template-columns:repeat(2,minmax(0,1fr))}}
</style></head><body><main><header><p class="eyebrow">2026.10.05 · SEOUL SUPPORT 01 · APPROVED RUNTIME 03</p>
<h1>서울 지원 거점,<br>승인한 화면을 실제 게임으로</h1><p>접지감을 개선한 Revision 02를 회수·보급의 실제 운영 화면에 연결했습니다. 작은 드론과 바닥 패키지, 데스크에 놓인 가벼운 보급 상자를 현재 아이보리·유리 UI와 함께 사용합니다.</p>
<div class="notice"><strong>실제 게임 연결을 완료했습니다.</strong>아래는 저장 쓰기·보상 지급·추첨·전투 시뮬레이션을 차단한 실제 운영 화면 클래스의 캡처입니다. 캡처 수량과 결과는 고정 검토용 콜백(fixture)을 사용하며, 게임에서는 기존 규칙의 실제 대기 보상과 추첨 결과를 지급·저장한 뒤 연출합니다. 영상은 무음이며 청감 확인을 대신하지 않습니다.</div>
</header><nav><a href="#recovery">회수</a><a href="#supply">보급</a><a href="#states">상태·결과 비교</a><a href="#revision-02">승인 시안과 비교</a><a href="#revision-01">첫 시안</a><a href="#before">기존 화면</a><a href="#sources">PNG 원본·출처</a></nav>'''
    page += still_section("recovery", "회수 · 바닥에 놓인 서울 배송 패키지", "승인한 접촉 그림자·패키지 위치·낮은 드론 부유를 실제 회수 화면에 적용했습니다. 실제 대기 보상은 오른쪽 정보판에 표시하고, 수령 성공 후 완료 상태로 갱신합니다.", revision)
    page += clip_section("recovery-idle", revision) + clip_section("recovery-claim", revision) + "</section>"
    page += still_section("supply", "보급 · 데스크에 닿는 협회 보급 상자", "데스크와 닿는 그림자·분리 뚜껑·내부빛을 실제 보급 화면에 적용했습니다. 기존 1회·10회 개봉과 실제 결과 표시를 유지하며, 개봉 중에는 두 버튼의 중복 요청을 막습니다.", revision)
    page += "".join(clip_section(name, revision) for name in ("supply-idle", "supply-open", "supply-ten")) + "</section>"
    page += '<section id="states" class="states"><h2>상태별 적용 화면</h2><p>실제 화면 클래스에서 빈 보상·수령 완료·보급권 부족·1회 및 10회 결과를 비교합니다. 아래 수량과 결과는 지급·저장이 없는 검토용 상태입니다.</p>'
    for name, title in (("recovery-empty", "회수 · 대기 보상 없음"), ("recovery-claimed", "회수 · 수령 완료"), ("supply-insufficient", "보급 · 보급권 부족"), ("supply-result1", "보급 · 1회 결과"), ("supply-result10", "보급 · 10회 묶음 결과")):
        page += (f'<details><summary>{title}</summary>{image_tag(name+".png", title, revision)}'
                 f'<p class="meta"><a href="{name}.png?v={revision}" target="_blank">915×412 원본</a>'
                 f' · <a href="runtime-masters/{name}.png?v={revision}" target="_blank">4배 합성 원본</a></p></details>')
    page += '</section><section id="revision-02" class="comparison"><h2>승인한 Revision 02와 비교</h2><p>승인 시안을 별도로 보존했습니다. 위의 실제 화면과 원화·접지감·배치를 비교할 수 있습니다.</p>'
    for kind, title in (("recovery", "회수 · 승인 Revision 02"), ("supply", "보급 · 승인 Revision 02")):
        page += (f'<details><summary>{title}</summary>'
                 + image_tag(f"revision-02/{kind}-ready.png", title+" 보존 시안", revision)
                 + f'<p class="meta"><a href="revision-02/{kind}-ready.png?v={revision}" target="_blank">승인 시안 PNG</a></p></details>')
    page += '</section><section id="revision-01" class="comparison"><h2>Revision 01과 접지감 비교</h2><p>공중에 떠 보였던 첫 시안도 보존했습니다. 승인된 접촉 그림자·패키지 위치·드론 높이와 비교할 수 있습니다.</p>'
    for kind, title in (("recovery", "회수 · 이전 Revision 01"), ("supply", "보급 · 이전 Revision 01")):
        page += (f'<details><summary>{title}</summary>'
                 + image_tag(f"revision-01/{kind}-ready.png", title+" 보존 시안", revision)
                 + f'<p class="meta"><a href="revision-01/{kind}-ready.png?v={revision}" target="_blank">이전 시안 PNG</a></p></details>')
    page += '</section><section id="before" class="comparison"><h2>기존 게임 화면과 비교</h2><p>색감·무게감·장면 구성의 변화를 비교하기 위한 보존 캡처입니다.</p>'
    page += ('<details><summary>이전 회수 화면 · 구형 UI 캡처</summary><p class="meta">display-qa/final-ui-915의 구형 기록입니다. 현재 런타임의 최신 배치와는 일부 차이가 있습니다.</p>'
             + image_tag("before/recovery.png", "구형 회수 UI 비교 캡처", revision) + '</details>')
    page += ('<details><summary>이전 보급 화면 · VFX REBORN 01</summary>'
             + image_tag("before/supply.png", "이전 보급 UI 비교 캡처", revision) + '</details></section>')
    page += '<section id="sources"><h2>사용한 PNG와 제작 기록</h2><p>아래는 실제 화면에서 사용한 분리 PNG입니다. 기능 글자는 이미지에 구워 넣지 않고 Godot에서 렌더링했습니다.</p><p class="meta">배경 생성 원본은 1919×820·1866×843으로 약 2배 해상도입니다. 요청한 4배 배경 원본에는 미달하며, 3660×1648 합성 마스터와 구분해 보존했습니다. 분리 장치와 정보판은 실제 표시 원화 크기의 4배 이상입니다.</p>'
    page += '<p class="meta"><a href="source/asset_manifest.json" target="_blank">원본·표시 크기·안전 영역</a> · <a href="source/prompts.json" target="_blank">제작 프롬프트·출처</a> · <a href="capture.json" target="_blank">915×412 런타임 캡처·수명 확인</a> · <a href="runtime-masters/capture.json" target="_blank">4배 런타임 캡처 확인</a></p><div class="assets">'
    for name, title in SOURCE_ART:
        page += (f'<figure><a href="source/{name}" target="_blank"><img loading="lazy" src="source/{name}" alt="{title}"></a>'
                 f'<figcaption>{title}<br><a href="source/{name}" target="_blank">분리 PNG 원본</a></figcaption></figure>')
    page += '</div></section>'
    maximum_particles = max(scene.get("maximumParticles", 0) for scene in report["scenes"])
    page += (f'<footer class="footer meta">정적 화면 7장·움직임 5개·네이티브 프레임 330장. 915×412 배치 확인 {len(report["checks"])}개와 4배 배치 확인 7개에서 누락 원화·텍스트 배치 오류가 없으며 메뉴 순간 입자는 최대 {maximum_particles}개입니다. '
             '중복 요청·숨김·화면 이탈 등 해당 UI 수명 확인 12개를 검토용 콜백으로 확인했습니다. 원본 프레임을 덧그리거나 보정하지 않고 무손실 WebP로 묶었습니다. '
             '실제 저장·지급·추첨은 캡처에서 차단했습니다. 전체 테스트·전투 플레이·모바일 터치·실기기·성능·청감 검사는 수행하지 않았습니다.</footer></main></body></html>')
    (TARGET / "index.html").write_text(page, encoding="utf-8")


def main() -> None:
    report = validate_inputs()
    previous = (
        (REPO / "godot/exports/display-qa/final-ui-915/offline.png", "recovery.png"),
        (REPO / "design/ui-image-skins/vfx-reborn-01/supply.png", "supply.png"),
    )
    for source, _ in previous:
        image_size(source, SIZE)
    # All required inputs pass before any packaged output is replaced.
    for name in STILLS:
        copyfile(CAPTURES / f"{name}.png", TARGET / f"{name}.png")
    for name in CLIPS:
        encode_clip(name)
    (TARGET / "before").mkdir(exist_ok=True)
    for source, name in previous:
        copyfile(source, TARGET / "before" / name)
    copyfile(CAPTURES / "capture.json", TARGET / "capture.json")
    write_gallery(report)
    print(json.dumps({"gallery": str(TARGET / "index.html"), "stills": len(STILLS), "clips": len(CLIPS), "nativeFrames": FRAME_COUNT * len(CLIPS), "checks": len(report["checks"]), "lifecycle": len(report["lifecycle"]), "runtimeConnected": True, "fixtureCallbacks": True}, ensure_ascii=False))


if __name__ == "__main__":
    main()
