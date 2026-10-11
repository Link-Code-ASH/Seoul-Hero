"""Package native Godot frames without redrawing or retouching the game."""
from pathlib import Path
from shutil import copyfile
from hashlib import sha256
import json
import sys
from PIL import Image

target = Path(__file__).resolve().parent
repo = target.parents[2]
source = repo / "godot/exports/vfx-reborn-01"
selected = {name for arg in sys.argv[1:] if arg.startswith("--scenes=") for name in arg.split("=",1)[1].split(",")}
scenes = [
    ("slash", "01 · 마력검", "주 검흔과 두 보조 검흔이 시간차로 이어지고, 흰 중심과 청록 외곽이 사라집니다. 8방향과 Lv.1 실제 쿨타임 간격을 표시합니다.", 4),
    ("chain", "02 · 연쇄번개", "적의 접점을 따라 이어지는 번개와 도착 방전입니다. 실제 연결 길이를 유지하고 움직이는 대상을 따라갑니다.", 3),
    ("projectiles", "03 · 마력탄·관통탄·산탄·포탑·적 탄", "종류별 원화와 색, 이동을 보간하는 최대 8지점 리본입니다. 적 탄은 독립 표시 ID로 잔상을 유지합니다.", 24),
    ("orbit", "04 · 수호 표창", "현재 머리 위 궤도를 유지하면서 회전 잔광을 연결했습니다.", 20),
    ("bombard", "05 · 마력 폭격", "포물선 발사 뒤 착탄빛·충격파·연기가 시간차로 이어집니다.", 23),
    ("installations", "06 · 마력장·지뢰·포탑", "설치 등장과 장치 발동빛, 낮은 지뢰 폭발을 구분합니다. 마력장은 캐릭터와 적 뒤에서 천천히 흐릅니다.", 60),
    ("enemy-actions", "07 · 적 행동과 보스", "실제 방향을 쓰는 돌진 예고, 원형 위험 영역, 지원 시전과 보스 발동입니다.", 22),
    ("pickups", "08 · 마력석과 지갑", "획득 접점의 작은 금빛과 지갑 회수 반응입니다. 실제 게임의 HUD 비행 목적지는 유지합니다.", 9),
    ("dense", "09 · 무기 6개·몬스터 19종", "고정된 혼합 장면에서 주 공격·위험 예고·적 탄·HUD의 가독성을 비교합니다. 실제 전투 시뮬레이션은 실행하지 않습니다.", 4),
    ("lobby", "10 · 로비", "기존 환경 레이어와 작전 단말의 순차 점등·스캔 흐름입니다. 승인된 화면 구성과 그림은 그대로입니다.", 14),
    ("selection", "11 · 각성자 선택", "배경 위치를 고정하고 선택 가장자리와 상세 원화에만 짧은 반응을 표시합니다.", 8),
    ("shop", "12 · 게이트24", "실제 상품 원화 영역의 획득빛과 잠금 테두리 반응입니다. 구매·리롤·잠금 규칙은 유지합니다.", 8),
    ("growth", "13 · 성장", "성공한 성장의 원화에 짧은 광편을 연결했습니다.", 9),
    ("supply", "14 · 보급", "기존 상자와 보상 원화에 사용하는 후광·광편입니다. 런타임의 실제 개봉 Tween과 함께 연결됩니다.", 9),
    ("result", "15 · 결과", "성공 결과의 실제 보상 원화 주변에 금빛을 표시합니다. 실패 결과는 차분한 전환을 사용합니다.", 9),
]
before = target / "before"
before.mkdir(exist_ok=True)
for name in ("slash", "chain", "projectiles", "installations"):
    previous = repo / f"design/ui-image-skins/combat-feedback/{name}.webp"
    if previous.exists() and not (before / previous.name).exists(): copyfile(previous, before / previous.name)

sections = []
for name, title, description, poster in scenes:
    paths = sorted((source / name).glob("*.png"))
    if not paths: raise RuntimeError(f"Missing native capture: {name}")
    if not selected or name in selected or not (target / f"{name}.webp").exists():
        frames = [Image.open(path).convert("RGBA") for path in paths]
        frames[0].save(target / f"{name}.webp", save_all=True, append_images=frames[1:],
                       duration=[33 if i % 3 != 2 else 34 for i in range(len(frames))],
                       loop=0, lossless=True, method=4)
        copyfile(paths[min(poster,len(paths)-1)], target / f"{name}.png")
        for frame in frames: frame.close()
    baseline = (f'<details><summary>이전 적용과 비교</summary><img loading="lazy" src="before/{name}.webp" width="915" height="412" alt="이전 {title}"></details>'
                if (before / f"{name}.webp").exists() else "")
    sections.append(f'<section id="{name}"><h2>{title}</h2><p>{description}</p>'
                    f'<img loading="lazy" src="{name}.webp?v=1" width="915" height="412" alt="{title} 실제 Godot 애니메이션">'
                    f'<p class="meta"><a href="{name}.webp?v=1" target="_blank">애니메이션 원본</a> · <a href="{name}.png?v=1" target="_blank">정지 캡처</a> · 915×412 / 30fps</p>{baseline}</section>')

report = json.loads((source / "capture.json").read_text(encoding="utf-8"))
copyfile(source / "capture.json", target / "capture.json")
checks = report["checks"]
failures = [check for check in checks if not check["passed"]]
if failures: raise RuntimeError(f"Failed scoped capture checks: {failures}")
provenance = {
    "date":"2026-10-04", "capture":"Godot 4.7.2 / OpenGL Compatibility / native viewport frames",
    "newIllustrations":[], "prompts":[],
    "artwork":"Existing approved character, monster, UI and VFX PNG artwork reused unchanged.",
    "proceduralSources":[], "retouchedFrames":False,
}
for relative in ["godot/shaders/slash_sweep.gdshader", "godot/shaders/chain_link.gdshader", "godot/shaders/effect_pulse.gdshader", "godot/shaders/projectile_trail.gdshader", "godot/shaders/field_flow.gdshader", "godot/shaders/installation_glow.gdshader", "godot/shaders/ui_vfx.gdshader", "godot/data/visuals/effects.json", "godot/data/visuals/ui_effects.json"]:
    provenance["proceduralSources"].append({"path":relative,"sha256":sha256((repo/relative).read_bytes()).hexdigest(),"source":"authored in this repository; no external generated illustration"})
(target / "provenance.json").write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
links = "".join(f'<a href="#{name}">{title.split(" · ")[1]}</a>' for name,title,_,_ in scenes)
header = '''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>서울 히어로 · VFX 실제 적용</title><style>
*{box-sizing:border-box}body{margin:0;background:#edf2f5;color:#193445;font:16px/1.65 system-ui,Malgun Gothic,sans-serif}main{max-width:1011px;margin:auto;padding:30px 48px 60px}h1{font-size:29px;line-height:1.35}h2{font-size:22px;margin:0}a{color:#196b71;text-underline-offset:3px}img{display:block;width:100%;height:auto;background:#dbe5e9}section{margin:38px 0 50px}nav{display:flex;gap:12px 20px;flex-wrap:wrap;padding:16px 0;border-block:1px solid #c6d4db}.meta{font-size:13px;color:#5a7180}.note{padding:14px 18px;background:#f9fbfc;border-left:3px solid #4e9d95}details{margin-top:14px}summary{cursor:pointer;color:#196b71}@media(max-width:700px){main{padding:22px 12px}h1{font-size:24px}}
</style></head><body><main><header><p class="meta">2026.10.04 · 실제 Godot 렌더 · VFX REBORN 01</p><h1>검흔부터 로비까지, 실제 적용한 움직임</h1><p>검기 세 겹, 연속 투사체 궤적, 적 접점을 따라가는 번개, 설치물과 메뉴의 짧은 반응을 게임에 연결했습니다.</p><div class="note">아래는 별도 그림 시안이 아니라 실제 런타임 화면 클래스의 네이티브 캡처입니다. 저장 쓰기와 전투 시뮬레이션을 차단하고 움직이는 검토용 상태의 표시 시간만 진행했습니다. 카메라와 HUD는 고정입니다.</div></header>'''
footer = (f'<footer class="meta">필수 스크립트·셰이더 렌더링과 이번 범위의 표시 확인 {len(checks)}개 통과. '
          '실제 전투 플레이·모바일 실기기·전체 테스트·빌드·성능 검사는 실행하지 않았습니다. '
          '<a href="capture.json">확인 기록</a> · <a href="provenance.json">제작 출처</a></footer></main></body></html>')
(target / "index.html").write_text(header+f'<nav>{links}</nav>'+"".join(sections)+footer,encoding="utf-8")
print(json.dumps({"gallery":str(target/"index.html"),"scenes":len(scenes),"checks":len(checks)},ensure_ascii=False))
