"""Only uniform scaling, translation and the user-authorized outer alpha mask."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
TARGET = np.array([[256.,208.],[456.,308.],[256.,408.],[56.,308.]])
OUTLINE = np.array([[56.,308.],[56.,158.],[256.,58.],[456.,158.],[456.,308.],[256.,408.]])

def line_fit(x, y):
    good = np.isfinite(y)
    x, y = x[good], y[good]
    for _ in range(4):
        coef = np.polyfit(x, y, 1)
        residual = np.abs(y - np.polyval(coef, x))
        keep = residual < max(2., np.median(residual) * 4)
        x, y = x[keep], y[keep]
    return coef

def intersect(a, b):
    x = (b[1]-a[1])/(a[0]-b[0])
    return np.array([x, np.polyval(a,x)])

def geometry(im, locked=False):
    alpha = np.asarray(im.getchannel('A'))
    h,w = alpha.shape
    solid = alpha >= 128
    # Row/column silhouettes are used only for measurement, never to erase interior pixels.
    lx = np.where(solid.any(1), solid.argmax(1), np.nan)
    rx = np.where(solid.any(1), w-1-solid[:,::-1].argmax(1), np.nan)
    top = np.where(solid.any(0), solid.argmax(0), np.nan)
    bottom = np.where(solid.any(0), h-1-solid[::-1].argmax(0), np.nan)
    if locked:
        validx = np.where(solid.any(0))[0]
        left, right = float(validx.min()), float(validx.max())
    else:
        left = float(np.nanmedian(lx[int(h*.40):int(h*.63)]))
        right = float(np.nanmedian(rx[int(h*.40):int(h*.63)]))
    span = right-left
    xs1=np.arange(int(left+.07*span),int(left+.43*span))
    xs2=np.arange(int(left+.57*span),int(left+.93*span))
    bl=line_fit(xs1,bottom[xs1]); br=line_fit(xs2,bottom[xs2])
    low=intersect(bl,br)
    if locked:
        tl=line_fit(xs1,top[xs1]); tr=line_fit(xs2,top[xs2])
        L=intersect(tl,bl); R=intersect(tr,br); back=intersect(tl,tr)
        floor=np.array([back,R,low,L]); hull=floor.copy()
    else:
        L=np.array([left,np.polyval(bl,left)])
        R=np.array([right,np.polyval(br,right)])
        # Back corner is occluded by furniture in many images: reconstruct the parallelogram.
        back=L+R-low
        floor=np.array([back,R,low,L])
        tl=line_fit(xs1,top[xs1]); tr=line_fit(xs2,top[xs2])
        ridge=intersect(tl,tr)
        hull=np.array([L,[left,np.polyval(tl,left)],ridge,[right,np.polyval(tr,right)],R,low])
    return floor,hull

def clip_halfplane(poly,n,c):
    result=[]
    for a,b in zip(poly,np.roll(poly,-1,axis=0)):
        da=float(a@n-c); db=float(b@n-c)
        if da>=0: result.append(a)
        if (da>=0)!=(db>=0): result.append(a+(b-a)*(da/(da-db)))
    return np.array(result)

def closest(poly,p):
    best=None; distance=float('inf')
    for a,b in zip(poly,np.roll(poly,-1,axis=0)):
        d=b-a; u=np.clip((p-a)@d/max(d@d,1e-12),0,1)
        q=a+u*d; dist=float((q-p)@(q-p))
        if dist<distance: best,distance=q,dist
    return best

def fit(floor,hull,locked):
    centered=floor-floor.mean(0); target=TARGET-TARGET.mean(0)
    ideal=float((centered*target).sum()/(centered*centered).sum())
    container=TARGET if locked else OUTLINE
    normals=[]; bounds=[]; support=[]
    for a,b in zip(container,np.roll(container,-1,axis=0)):
        d=b-a; n=np.array([-d[1],d[0]])/np.linalg.norm(d)
        normals.append(n); bounds.append(float(n@a)-3.)
        support.append(float(np.min(hull@n)))
    normals=np.array(normals); bounds=np.array(bounds); support=np.array(support)
    best=None
    # Minimize floor-corner SSE while protecting the room outline within its 4px allowance.
    low,high=ideal*.75,ideal*1.03
    for refinement in range(2):
        for s in np.linspace(low,high,181):
            t0=TARGET.mean(0)-s*floor.mean(0)
            c=bounds-s*support
            if np.all(normals@t0>=c): t=t0
            else:
                region=np.array([[-4096.,-4096.],[4096.,-4096.],[4096.,4096.],[-4096.,4096.]])
                for n,k in zip(normals,c):
                    region=clip_halfplane(region,n,k)
                    if len(region)<3: break
                if len(region)<3: continue
                t=closest(region,t0)
            loss=float(((s*floor+t-TARGET)**2).sum())
            if best is None or loss<best[0]: best=(loss,float(s),t)
        step=(high-low)/180
        low,high=best[1]-step,best[1]+step
    return best[1],best[2],ideal

def outer_mask():
    yy,xx=np.mgrid[:448,:512]
    p=np.stack([xx,yy],axis=-1).astype(float)
    inside=np.ones((448,512),bool); distance=np.full((448,512),np.inf)
    for a,b in zip(OUTLINE,np.roll(OUTLINE,-1,axis=0)):
        d=b-a; v=p-a
        inside &= d[0]*v[:,:,1]-d[1]*v[:,:,0]>=0
        u=np.clip(np.sum(v*d,axis=-1)/(d@d),0,1)
        dist=np.linalg.norm(v-u[:,:,None]*d,axis=-1)
        distance=np.minimum(distance,dist)
    return inside|(distance<=4.)

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    manifest=json.loads((ROOT/'generation.json').read_text(encoding='utf-8-sig'))
    keep=outer_mask(); results=[]
    sheet=Image.new('RGBA',(7*512,5*448),(11,22,33,255))
    draw=ImageDraw.Draw(sheet)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17)
    for i,entry in enumerate(manifest['entries']):
        name=entry['id']; raw=ROOT/'_raw'/f'{name}.png'
        im=Image.open(raw).convert('RGBA'); floor,hull=geometry(im,name=='locked')
        s,t,ideal=fit(floor,hull,name=='locked')
        # Same scalar on both axes, zero rotation/shear/perspective. Premultiplied alpha avoids fringes.
        out=im.convert('RGBa').transform((512,448),Image.Transform.AFFINE,
            (1/s,0,-t[0]/s,0,1/s,-t[1]/s),resample=Image.Resampling.BICUBIC).convert('RGBA')
        arr=np.array(out); removed=int(np.count_nonzero((arr[:,:,3]>0)&~keep))
        arr[~keep]=0
        out=Image.fromarray(arr); out.save(ROOT/f'{name}.png')
        transformed=s*floor+t
        errors=np.linalg.norm(transformed-TARGET,axis=1)
        a=arr[:,:,3]
        result=dict(file=name+'.png',raw_size=list(im.size),scale=s,translation=t.tolist(),
            unconstrained_floor_scale=ideal,raw_floor_vertices=floor.tolist(),
            corrected_floor_vertices=transformed.tolist(),corner_error_px=errors.tolist(),
            back_corner_method='observed contour' if name=='locked' else 'inferred L+R-bottom (occluded)',
            maximum_error_px=float(errors.max()),masked_nonzero_pixels=removed,
            edge_nonzero=[int(np.count_nonzero(a[0])),int(np.count_nonzero(a[-1])),int(np.count_nonzero(a[:,0])),int(np.count_nonzero(a[:,-1]))],
            label_nonzero=int(np.count_nonzero(a[20:51,186:327])),raw_sha256=sha(raw),sha256=sha(ROOT/f'{name}.png'))
        results.append(result)
        xy=((i%7)*512,(i//7)*448)
        sheet.alpha_composite(out,xy)
        draw.text((xy[0]+256,xy[1]+25),name,font=font,fill=(213,229,236,255),anchor='mm')
        print(name, 'scale',round(s,6),'shift',t.round(2).tolist(),'errors',errors.round(2).tolist(),'masked',removed,flush=True)
    sheet.save(ROOT/'contact_sheet.png')
    (ROOT/'correction.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    lines=['# 방 원화 보정 결과','',
        '- 원본 35장은 `_raw/`에 생성 파일 바이트 그대로 보존했다. 보정본은 현재 폴더의 동일 파일명, 512×448 RGBA PNG다.',
        '- 적용식: `출력 좌표 = 원본 좌표 × 배율 + (dx, dy)`. 원본 픽셀 좌표가 기준이며 배율은 가로·세로 동일하다. 회전·기울임·원근 변형·비균등 확대·축소는 적용하지 않았다.',
        '- 바닥 목표(위/오른쪽/아래/왼쪽): `(256,208) (456,308) (256,408) (56,308)`.',
        '- 알파 128 이상 윤곽의 직선 경계를 적합해 좌우·아래 바닥 꼭짓점을 측정했다. 가구에 가려진 위 꼭짓점은 `왼쪽+오른쪽−아래`로 추정했다(locked는 네 점 모두 관측). 따라서 표는 경계 적합에 따른 기하학적 오차이며, 가려진 위 꼭짓점의 직접 픽셀 검증이 아니다.',
        '- 바닥 네 점의 오차 제곱합을 우선 최소화하되, 방 외곽선이 마스크에 잘리지 않도록 윤곽을 허용 범위 안에 놓았다. 생성 원본의 비율 차이는 동일 비율 변환만으로 완전히 없앨 수 없어 잔여 오차를 기록한다.',
        '- 지정한 방 윤곽 `(56,308) (56,158) (256,58) (456,158) (456,308) (256,408)`에서 유클리드 거리 4px 이내를 보존하고 그 바깥만 투명 처리했다. 내부 색·가구·그림자는 수정하지 않았다.',
        '- `contact_sheet.png`: 보정본 35장, 요청 파일 순서, 7열×5행, 3584×2240. 이름은 모음 시트에만 표시했다.',
        '- `generation.json`: 내장 image_gen 실제 프롬프트 및 입력/출처. `correction.json`: 좌표, 변환, 알파 검사, 원본/보정본 SHA-256 상세.',
        '', '| 파일 | 원본 크기 | dx(px) | dy(px) | 동일 배율 | 위 오차* | 오른쪽 오차 | 아래 오차 | 왼쪽 오차 | 최대 오차 |',
        '|---|---|---:|---:|---:|---:|---:|---:|---:|---:|']
    for r in results:
        e=r['corner_error_px']; dx,dy=r['translation']; w,h=r['raw_size']
        lines.append(f"| {r['file']} | {w}×{h} | {dx:.3f} | {dy:.3f} | {r['scale']:.8f} | {e[0]:.3f} | {e[1]:.3f} | {e[2]:.3f} | {e[3]:.3f} | {max(e):.3f} |")
    lines += ['', '*위 오차는 locked를 제외하고 추정치다. 오차 단위는 최종 512×448 캔버스의 px다.', '',
        f"전체 최대 꼭짓점 오차: {max(r['maximum_error_px'] for r in results):.3f}px.",
        f"네 변 및 상단 라벨 예약 영역의 alpha>0 픽셀: {sum(sum(r['edge_nonzero'])+r['label_nonzero'] for r in results)}개."]
    (ROOT/'보정_결과.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')

if __name__=='__main__': main()
