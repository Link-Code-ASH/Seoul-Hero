from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib
root=Path(__file__).resolve().parents[5]
design=root/'design/ui-image-skins/office-day-01/lobby-polish-01'
runtime=root/'godot/assets/ui/office-day-01/lobby-polish-01'
raw=design/'_raw'
checks=[]
for name,expected in [('operator_halo.png',(256,256)),('operator_glint.png',(256,64))]:
 path=design/name
 im=Image.open(path)
 a=im.getchannel('A')
 file_hash=hashlib.sha256(path.read_bytes()).hexdigest()
 runtime_hash=hashlib.sha256((runtime/name).read_bytes()).hexdigest()
 item={'file':name,'size':list(im.size),'expected_size':list(expected),'dimensions_match':im.size==expected,'mode':im.mode,'alpha_extrema':list(a.getextrema()),'has_alpha_zero':a.getextrema()[0]==0,'alpha_zero_pixels':sum(v==0 for v in a.get_flattened_data()),'center_alpha':a.getpixel((im.width//2,im.height//2)),'sha256':file_hash,'runtime_sha256':runtime_hash,'runtime_copy_matches':file_hash==runtime_hash,'text_logo_visual_check':'none','fake_checkerboard_visual_check':'none','role':'effect overlay; no opaque panel backing'}
 if name=='operator_halo.png':
  item['center64x64_alpha_extrema']=list(a.crop((96,96,160,160)).getextrema())
  item['center_visual_check']='empty center; central pixel alpha0; negligible original generated edge noise<=1/255 inside64x64 is preserved'
 checks.append(item)
validation={'revision':'02','assets':checks,'scope':'Exact image dimensions/mode/alpha/hash are computed; text/logo/checkerboard checks are manual visual inspection of generated sources and resampled previews. No alpha normalization or repainting.','all_computed_checks_pass':all(x['dimensions_match'] and x['mode']=='RGBA' and x['has_alpha_zero'] and x['runtime_copy_matches'] for x in checks)}
(raw/'validation_effects_revision02.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2),encoding='utf-8')
original_hash=hashlib.sha256((design/'contact_sheet.png').read_bytes()).hexdigest()
names=['speaker_on.png','speaker_off.png','menu_settings.png','menu_archive.png','menu_association.png','deploy_surface.png','operator_surface.png','deploy_corner.png','deploy_warning_tile.png','deploy_streak.png','operator_halo.png','operator_glint.png']
sheet=Image.new('RGB',(1352,1140),'#FBF6EC')
draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
titlefont=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',26)
draw.text((22,16),'LOBBY POLISH 01 / REVISION 02 / 12 RASTER ASSETS',fill='#24395C',font=titlefont)
draw.text((22,54),'Source textures shown here. Neutral white menu rims are suppressed by the runtime shader.',fill='#43526B',font=font)
for idx,name in enumerate(names):
 col,row=idx%3,idx//3
 x=20+col*444
 y=90+row*252
 is_effect=name in ['operator_halo.png','operator_glint.png']
 bg='#24395C' if is_effect else '#F3EDDF'
 fg='#F7FFF9' if is_effect else '#24395C'
 draw.rounded_rectangle((x,y,x+424,y+234),radius=12,fill=bg)
 im=Image.open(design/name).convert('RGBA')
 ow,oh=im.size
 maxw,maxh=(380,172)
 factor=min(maxw/ow,maxh/oh)
 resized=im.resize((round(ow*factor),round(oh*factor)),Image.Resampling.LANCZOS)
 px=x+(424-resized.width)//2
 py=y+14+(172-resized.height)//2
 sheet.paste(resized,(px,py),resized)
 draw.text((x+14,y+201),name+' / '+str(ow)+'x'+str(oh),fill=fg,font=font)
draw.text((22,1112),'RGBA / source alpha preserved / generated with imagegen / original contact_sheet.png and runtime/ retained',fill='#43526B',font=font)
sheet.save(design/'contact_sheet_revision02.png')
assert original_hash==hashlib.sha256((design/'contact_sheet.png').read_bytes()).hexdigest()
print(json.dumps(validation,ensure_ascii=False))
print('contact_sheet_revision02.png',sheet.size,'original contact_sheet unchanged')

