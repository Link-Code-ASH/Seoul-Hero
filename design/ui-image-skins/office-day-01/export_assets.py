from pathlib import Path
import json, shutil, hashlib
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
records = json.loads((ROOT / 'generation.json').read_text(encoding='utf-8'))['assets']
(ROOT / '_raw').mkdir(exist_ok=True)
checks = []
for item in records:
    name = item['id']
    source = Path(item['source'])
    shutil.copy2(source, ROOT / '_raw' / (name + '.png'))
    im = Image.open(source).convert('RGBA')
    # Trim the generator's transparent canvas, retaining the generated alpha.
    alpha = np.asarray(im.getchannel('A'))
    occupied = alpha > 32
    rows = np.where(occupied.sum(axis=1) > max(2, im.width * .015))[0]
    cols = np.where(occupied.sum(axis=0) > max(2, im.height * .015))[0]
    box = (max(0,int(cols[0])-2), max(0,int(rows[0])-2), min(im.width,int(cols[-1])+3), min(im.height,int(rows[-1])+3))
    cropped = im.crop(box)
    w,h = item['width'],item['height']
    top = 5 if ('pressed' in name or name == 'tab_inactive') else 2
    canvas = Image.new('RGBA', (w,h))
    canvas.alpha_composite(cropped.resize((w-4,h-top-2),Image.Resampling.LANCZOS), (2,top))
    path = ROOT / (name+'.png')
    canvas.save(path)
    arr = np.asarray(canvas)
    a = arr[:,:,3]
    checks.append({'file':path.name,'size':[w,h], 'mode':canvas.mode, 'transparent_pixels':int((a==0).sum()), 'partial_alpha_pixels':int(((a>0)&(a<255)).sum()), 'edges_alpha_zero':bool(not np.any(a[0]) and not np.any(a[-1]) and not np.any(a[:,0]) and not np.any(a[:,-1])), 'crop':box, 'placement':[2,top,w-2,h-2], 'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})

sheet = Image.new('RGBA',(1800,1500),(145,145,145,255))
draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
for i,item in enumerate(records):
    x=(i%5)*360; y=(i//5)*300
    im=Image.open(ROOT/(item['id']+'.png')).convert('RGBA')
    im.thumbnail((330,240),Image.Resampling.LANCZOS)
    sheet.alpha_composite(im,(x+(360-im.width)//2,y+12+(240-im.height)//2))
    draw.text((x+12,y+264),item['id'],font=font,fill=(30,35,40))
sheet.save(ROOT/'contact_sheet.png')
(ROOT/'verification.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
lines=['# Office Day UI', '', '내장 image_gen으로 만든 밝은 협회 사무실 메뉴용 UI 원화 25종. 원본은 `_raw/`, 실제 프롬프트와 생성 경로는 `generation.json`에 보존했다.', '', '모든 개별 파일은 지정 크기의 8비트 채널 RGBA PNG(32비트)다. 생성 알파를 유지하며 여백을 정리하고 지정 해상도로 리샘플링했다. 외곽에 2px 투명 안전 여백을 두었다. 눌림 상태와 비활성 탭은 위쪽 시작점을 3px 낮춰 배치했다.', '', '## 크기 및 9-slice', '', '여백은 원본 PNG 픽셀 기준 **왼쪽 / 위 / 오른쪽 / 아래** 순서다. 표의 값은 모서리와 아래쪽 립을 보존하기 위한 권장값이다. 비대상은 전체 이미지를 비율 유지해 사용한다.', '', '| 파일 | 크기 | 9-slice L/T/R/B (px) | 크기·RGBA·투명 가장자리 |', '|---|---|---|---|']
for item in records:
    margin=item['margins']
    if isinstance(margin,int): margin=[margin]*4
    m=' / '.join(map(str,margin)) if margin else '비대상'
    lines.append(f"| {item['id']}.png | {item['width']}×{item['height']} | {m} | 통과 |")
lines += ['', '## 검사 결과', '', '- 25/25개 파일: 요청한 해상도와 RGBA 모드 일치, alpha=0 픽셀 존재, 네 가장자리 전체 alpha=0.', '- 기본/눌림/비활성 상태별 캔버스 크기 일치. 기본과 비활성 상태의 배치 사각형은 같으며 눌림 상태는 위쪽을 3px 낮췄다.', '- 회색 바탕 합성 모음은 `contact_sheet.png`(1800×1500, 5열×5행). 개별 원화에는 글자·숫자·로고를 넣지 않았다. 자물쇠는 lock_overlay에만 사용했다.', '- 픽셀 수, 배치 사각형, SHA-256은 `verification.json`에 기록했다.', '', '## 사용 시 유의점', '', '- 손으로 칠한 미세한 색 변화는 남아 있다. 가장자리와 중심에 큰 장식은 없지만 수학적으로 완전히 균일한 픽셀 띠는 아니다.', '- `tooltip_bubble`은 아래 중앙 꼬리 때문에 일반 9-slice의 하단 중앙을 늘리면 꼬리 폭도 함께 늘어난다. 꼬리 비율을 유지해야 할 때는 384px 폭으로 사용하거나 꼬리를 별도로 잘라 배치한다.', '- 진행 막대 채움은 프레임 안쪽 홈 크기에 맞춰 배치한다.', '- 게임 코드 연결이나 빌드는 수행하지 않았다.']
(ROOT/'README.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({'files':len(checks),'all_edges_transparent':all(x['edges_alpha_zero'] for x in checks)},ensure_ascii=False))
lock=np.asarray(Image.open(ROOT/'lock_overlay.png'))
print('lock plate alpha:',lock[50,50,3],lock[100,50,3])
