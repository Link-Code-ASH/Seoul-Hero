"""Package unchanged native Godot frames as lossless animated WebP previews."""
from pathlib import Path
from shutil import copyfile
import json
from PIL import Image

repo = Path(__file__).resolve().parents[3]
source = repo / "godot/exports/combat-feedback"
target = Path(__file__).resolve().parent
scenes = [
    ("slash", "마력검", "앞끝을 따라 곡선 리본이 생성되고, 지나간 꼬리는 가늘어지며 사라집니다. PNG 덩어리를 회전시키는 방식은 제거했습니다.", 17, 5),
    ("chain", "연쇄번개", "첫 적에서 다음 적으로 순서대로 전달되며, 각 연결은 실제 적의 중심에서 끝납니다. 연결 길이는 그대로 두고 폭을 약 22% 넓혔습니다.", 17, 7),
    ("installations", "마력장·지뢰", "접지 그림자와 두꺼운 설치물 본체, 3.4초 확산과 더 선명한 색입니다. 바닥빛은 캐릭터와 몬스터 뒤에 있습니다.", 100, 20),
    ("projectiles", "수호 표창·투사체", "수호 표창을 실제 표창 원화로 교체했습니다. 표창 궤도는 캐릭터 몸 중심에 맞춰 올리고, 위쪽 통과 지점이 머리보다 높도록 보정했습니다. 기존 1.5배 표시 크기는 유지합니다.", 50, 4),
]
sections = []
for scene, title, text, interval, poster in scenes:
    frames = [Image.open(path).convert("RGBA") for path in sorted((source / scene).glob("*.png"))]
    durations = [interval] * len(frames)
    if scene in ("slash", "chain"):
        durations[-1] = 750
    frames[0].save(target / f"{scene}.webp", save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, lossless=True, method=6)
    copyfile(source / scene / f"{poster:03d}.png", target / f"{scene}.png")
    sections.append(f'<section id="{scene}"><h2>{title}</h2><p>{text}</p>'
                    f'<a href="{scene}.webp?revision=07" target="_blank"><img src="{scene}.webp?revision=07" width="915" height="412" alt="{title} 실제 Godot 렌더 애니메이션"></a>'
                    f'<p class="meta"><a href="{scene}.png?revision=07" target="_blank">정지 캡처 원본</a> · 915×412</p></section>')

copyfile(source / "capture.json", target / "capture.json")
html = '''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>서울 히어로 · 전투 표현 실제 적용</title><style>
*{box-sizing:border-box}body{margin:0;background:#eaf0f3;color:#22374b;font:16px/1.65 system-ui,Malgun Gothic,sans-serif}main{max-width:1011px;margin:auto;padding:32px 48px 64px}h1{font-size:30px;line-height:1.3}h2{font-size:23px;margin:0}a{color:#26776e;text-underline-offset:3px}img{display:block;width:100%;height:auto}section{margin:38px 0 54px}nav{display:flex;gap:24px;flex-wrap:wrap;padding:18px 0;border-block:1px solid #bfced7}.meta{font-size:14px;color:#5a7182}.note{padding:14px 18px;background:#f7fafb;border-left:3px solid #338780}.eyebrow{font-size:13px;font-weight:700;letter-spacing:.06em;color:#426b77}@media(max-width:700px){main{padding:24px 14px}h1{font-size:25px}}
</style></head><body><main><header><p class="eyebrow">서울 히어로 · 실제 Godot 렌더 · 전투 표현 07차</p><h1>검기·연쇄번개·설치물·표창 적용 결과</h1><p>게임에서 사용하는 렌더러와 새 원화를 연결한 결과입니다. 아래 애니메이션은 실제 915×412 캡처 프레임을 순서대로 묶었습니다.</p><div class="note">저장 쓰기와 전투 시뮬레이션을 차단한 고정 장면입니다. 표시 시간만 진행합니다. 일반 투사체 샘플은 크기를 확인할 수 있도록 정지해 있으며 표창은 실제 궤도·회전을 사용합니다.</div><p class="meta">쿨타임의 음수 누적을 수정했습니다. 리롤은 무기 6→8→10, 아이템 5→6→7로 각자 증가합니다. 피해·충돌·사거리·연쇄 횟수는 유지합니다.</p></header><nav><a href="#slash">마력검</a><a href="#chain">연쇄번개</a><a href="#installations">설치물</a><a href="#projectiles">표창·투사체</a><a href="../enamel-glass-01/index.html?runtime=05">기존 UI 결과</a></nav>'''
(target / "index.html").write_text(html + "".join(sections) + '<footer class="meta">가져오기·스크립트·셰이더 실행과 표시를 확인했습니다. 실기기·실제 전투 플레이·전체 테스트·빌드·성능 검사는 실행하지 않았습니다. <a href="capture.json">캡처 기록</a></footer></main></body></html>', encoding="utf-8")
print(json.dumps({"gallery": str(target / "index.html"), "scenes": len(scenes)}, ensure_ascii=False))
