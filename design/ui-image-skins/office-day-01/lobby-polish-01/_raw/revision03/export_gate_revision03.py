from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib,shutil
root=Path(__file__).resolve().parents[6]
design=root/'design/ui-image-skins/office-day-01/lobby-polish-01'
runtime=root/'godot/assets/ui/office-day-01/lobby-polish-01'
raw=design/'_raw/revision03'
raw.mkdir(parents=True,exist_ok=True)
source=Path(r'C:\Users\geniu\.codex\generated_images\01a1295b-f305-7352-aa06-e6cf330f3987\exec-9ad9a13f-bfb9-41bb-881c-5d3efca9a663.png')
prompt=json.loads(r'''"Use case: stylized-concept\nAsset type: one serious sophisticated transparent raster deployment-gate icon for an adult hunter mobile game operating UI, final512x512, displayed72px on a dark navy deployment plate.\nPrimary request: a single manufactured dimensional portal standing upright, a sleek angular navy and gunmetal frame forming a tall beveled rectangular opening with clipped upper corners. Shallow three-quarter view slightly from above, mostly frontal, only a narrow top and side visible. Broad clean cream/silver metal faces catch calm studio highlights and give a strong readable silhouette on dark navy. The portal is poised and solemn, precise modern equipment belonging in a professional hunter association, not a cute fantasy gateway. Two restrained coral-red readiness insets at the lower frame corners, no symbols.\nInside: a subtle cool-violet and soft-white luminous VERTICAL dimensional breach, an elongated narrow luminous rift with a little translucent depth and quiet pale lavender mist confined inside the frame. No bubbly spiral or concentric swirls. The inner opening is dark muted navy around the breach so the vertical white core reads clearly.\nStyle: refined adult game object render, softly painted tactile metal with smooth restrained dimensional shading, minimal mechanical detail, no outline stroke, no flat SVG or cartoon appearance. Bright enough to read without saturated neon; broad planes and one simple vertical light shape, very limited detail.\nComposition: one centered object filling roughly80percent of square canvas, generous real transparent margins, clear bold silhouette at72px, no environment, no ground plane, no base pedestal, no external light trails, only extremely faint compact transparent grounding shadow.\nColor palette: deep navy #24395C and gunmetal, cream/silver #ECEDE6 edge faces, subtle cool violet #B9B1E8 and soft-white #F7F6F1 core, small coral #FF3D57 accent. No warm gold.\nConstraints: genuine transparent RGBA background, no fake checkerboard, no letters, numbers, logos, no orange cartoon arrow or sign, no arrows at all, no medieval pillars or gold architectural columns, no sci-fi glyphs, no decorative stars, no rounded toy proportions, no heavy neon bloom, no outer outline, no additional object. Completely new icon, no existing game icon geometry to preserve."''')
im=Image.open(source).convert('RGBA')
original_size=list(im.size)
crop=(-60,-60,im.width+60,im.height+60)
im=im.crop(crop).resize((512,512),Image.Resampling.LANCZOS)
dest=design/'icon_deploy_gate.png'
im.save(dest)
runtime.mkdir(parents=True,exist_ok=True)
shutil.copy2(dest,runtime/dest.name)
source_saved=raw/'icon_deploy_gate_source.png'
shutil.copy2(source,source_saved)
a=im.getchannel('A')
file_hash=hashlib.sha256(dest.read_bytes()).hexdigest()
runtime_hash=hashlib.sha256((runtime/dest.name).read_bytes()).hexdigest()
manifest={'revision':'03 serious deployment gate','generator':'built-in image_gen.imagegen','file':dest.name,'prompt':prompt,'generated_source':str(source),'source_saved':str(source_saved),'original_size':original_size,'crop':list(crop),'final_size':list(im.size),'postprocess':'Source RGBA preserved; padded crop extends60px beyond original canvas then512x512 Lanczos resize only. No repainting or alpha normalization.','mode':im.mode,'alpha_extrema':list(a.getextrema()),'has_alpha_zero':a.getextrema()[0]==0,'alpha_zero_pixels':sum(v==0 for v in a.get_flattened_data()),'visible_bbox_alpha32':list(a.point(lambda x:255 if x>32 else 0).getbbox()),'text_logo_visual_check':'none','arrow_sign_medieval_column_visual_check':'none','fake_checkerboard_visual_check':'none','readability72px_visual_check':'angular metallic frame and narrow vertical rift read clearly on dark navy; restrained coral readiness accents visible','sha256':file_hash,'runtime_sha256':runtime_hash,'runtime_copy_matches':file_hash==runtime_hash,'old_asset_preserved':'godot/assets/ui/office-day-01/icons/icon_deploy_gate.png not modified'}
(raw/'manifest_deploy_gate.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
preview=Image.new('RGB',(820,430),'#101A2C')
draw=ImageDraw.Draw(preview)
draw.text((20,15),'REVISION03 / serious deployment gate /72px actual at left',fill='#F7F6F1',font=font)
small=im.resize((72,72),Image.Resampling.LANCZOS)
preview.paste(small,(40,90),small)
draw.text((22,176),'actual72px',fill='#DDE7EF',font=font)
big=im.resize((300,300),Image.Resampling.LANCZOS)
preview.paste(big,(165,80),big)
draw.text((182,390),'new metallic gate',fill='#DDE7EF',font=font)
draw.rectangle((514,72,805,386),fill='#FBF6EC')
preview.paste(big,(510,75),big)
draw.text((546,390),'cream preview',fill='#DDE7EF',font=font)
preview.save(raw/'preview_deploy_gate_72px.png')
print(json.dumps(manifest,ensure_ascii=False))

