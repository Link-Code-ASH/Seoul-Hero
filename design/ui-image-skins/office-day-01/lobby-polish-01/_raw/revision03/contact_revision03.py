from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import hashlib
root=Path(__file__).resolve().parents[6]
design=root/'design/ui-image-skins/office-day-01/lobby-polish-01'
preserved={name:hashlib.sha256((design/name).read_bytes()).hexdigest() for name in ['contact_sheet.png','contact_sheet_revision02.png']}
names=['speaker_on.png','speaker_off.png','menu_settings.png','menu_archive.png','menu_association.png','deploy_surface.png','operator_surface.png','deploy_corner.png','deploy_warning_tile.png','deploy_streak.png','operator_halo.png','operator_glint.png']
sheet=Image.new('RGB',(1352,1390),'#FBF6EC')
draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
titlefont=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',26)
draw.text((22,16),'LOBBY POLISH01 / REVISION03 /13 RASTER ASSETS',fill='#24395C',font=titlefont)
draw.text((22,54),'Source textures shown; menu pigment is re-projected and its white rim replaced by inner glass at runtime.',fill='#43526B',font=font)
for idx,name in enumerate(names):
 col,row=idx%3,idx//3
 x=20+col*444
 y=90+row*252
 effect=name in ['operator_halo.png','operator_glint.png']
 bg='#24395C' if effect else '#F3EDDF'
 fg='#F7FFF9' if effect else '#24395C'
 draw.rounded_rectangle((x,y,x+424,y+234),radius=12,fill=bg)
 im=Image.open(design/name).convert('RGBA')
 ow,oh=im.size
 scale=min(380/ow,172/oh)
 img=im.resize((round(ow*scale),round(oh*scale)),Image.Resampling.LANCZOS)
 sheet.paste(img,(x+(424-img.width)//2,y+14+(172-img.height)//2),img)
 draw.text((x+14,y+201),name+' / '+str(ow)+'x'+str(oh),fill=fg,font=font)
y=1112
draw.rounded_rectangle((20,y,1332,y+236),radius=12,fill='#101A2C')
gate=Image.open(design/'icon_deploy_gate.png').convert('RGBA')
small=gate.resize((72,72),Image.Resampling.LANCZOS)
sheet.paste(small,(50,y+70),small)
big=gate.resize((210,210),Image.Resampling.LANCZOS)
sheet.paste(big,(170,y+14),big)
draw.text((410,y+28),'NEW / icon_deploy_gate.png /512x512',fill='#F7F6F1',font=titlefont)
draw.text((410,y+80),'Manufactured navy metal / silver faces / vertical violet rift',fill='#DDE7EF',font=font)
draw.text((410,y+115),'Actual72px preview at left / true RGBA / source alpha preserved',fill='#DDE7EF',font=font)
draw.text((410,y+150),'Old office-day-01/icons/icon_deploy_gate.png is retained.',fill='#DDE7EF',font=font)
draw.text((22,1364),'Generated with built-in imagegen / prior contact sheets and runtime captures retained',fill='#43526B',font=font)
sheet.save(design/'contact_sheet_revision03.png')
assert all(hashlib.sha256((design/name).read_bytes()).hexdigest()==digest for name,digest in preserved.items())
print('contact_sheet_revision03.png',sheet.size,'13 assets; v1/v2 sheets unchanged')

