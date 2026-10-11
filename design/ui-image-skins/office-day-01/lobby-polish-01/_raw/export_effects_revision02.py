from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,shutil,hashlib
root=Path(__file__).resolve().parents[5]
design=root/'design/ui-image-skins/office-day-01/lobby-polish-01'
runtime=root/'godot/assets/ui/office-day-01/lobby-polish-01'
raw=design/'_raw'
runtime.mkdir(parents=True,exist_ok=True)
specs=json.loads(r'''[{"name":"operator_halo","raw":"C:\\Users\\geniu\\.codex\\generated_images\\01a1295b-f305-7352-aa06-e6cf330f3987\\exec-3cd7f9b1-378f-465c-a742-fc00fa9ff05a.png","size":[256,256],"prompt":"Use case: stylized-concept\nAsset type: one transparent raster light effect for an adult polished mobile game operating-office UI. This is an effect-only overlay around a64pixel operator portrait; final texture256x256.\nPrimary request: a delicate circular optical halo, a thin pale mint and soft white refractive ring with a few softly fading sections, front-facing perfectly circular. About84percent of the square width, centered. Fine satin optical reflection on the upper-left arc, gently luminous lower-right arc, restrained soft bloom immediately around the thin ring. The entire center of the ring is fully transparent and empty so a portrait beneath stays untouched. Broad readable optics with minimal detail; feels like premium glass and a calm modern communicator, not fantasy magic.\nColor palette: pale mint #9FFFE7 and warm white #F7FFF9; no saturated neon. Maximum light sits on only a short arc, other arc sections are quieter. Ring thickness about2percent of diameter with bloom another2percent.\nConstraints: true RGBA transparent background and fully transparent center, no backing disk, no glass panel, no letters or numbers, no logo, no icon, no runes, no concentric HUD target, no ticks, no star shapes, no sparkles, no decorations, no material border line. No neon/cyberpunk. No drop shadow, room, floor or object. The effect is soft refractive light only."},{"name":"operator_glint","raw":"C:\\Users\\geniu\\.codex\\generated_images\\01a1295b-f305-7352-aa06-e6cf330f3987\\exec-aa3f6145-0376-43f2-9baf-10824659cb5e.png","size":[256,64],"prompt":"Use case: stylized-concept\nAsset type: one transparent raster optical-gloss effect-only texture for a mature professional operating-office game UI, final256x64, animated across a360x82 glass communicator.\nPrimary request: one elegant white-to-pale-mint optical gleam ribbon, long horizontal overall silhouette with a gently curved diagonal bright ridge rising from lower left to upper right. Broad silky refractive light tapering softly into fully transparent ends. A restrained irregular pale-white specular reflection is brightest left of center; the surrounding mint sheen is faint and feathered. It is a soft surface reflection passing over a glass UI window, not a material panel, object, laser, magic effect or neon strip.\nComposition: isolated single ribbon occupying about85percent width and45percent height of a4:1 horizontal texture, centered with generous transparent margin all around. Flat frontal 2D compositor-ready raster light effect; gentle diagonal sweep and very slight curvature, no perspective. Both ends fade out into true transparency, no hard clipping.\nColor: white #F7FFF9 and pale mint #BCFFEC suitable for additive blending. No saturated colors, no dark opaque backing.\nConstraints: true RGBA transparent background outside and behind the light, no rectangular panel or material surface, no border, no text, numbers, logos, icon, stars, sparkle shapes, dots, runes, triangles, arrows or ornaments. No shadow, no environment, no floor. Refined premium consumer-device optics with a little organic painted softness; not flat vector, not sci-fi neon."}]''')
manifest={'generator':'built-in image_gen.imagegen','revision':'02 operator light overlays','mode':'transparent RGBA; source alpha preserved; full-canvas resize only','assets':[],'notes':['Effect-only textures; existing base frames and prior textures not modified.','White/pale mint RGB suits runtime additive blending and opacity gating.','Visual inspection found no text, logos, rune/stars or frame backing.']}
for spec in specs:
 source=Path(spec['raw'])
 im=Image.open(source).convert('RGBA')
 origsize=list(im.size)
 source_saved=raw/(spec['name']+'_revision02_source.png')
 shutil.copy2(source,source_saved)
 im=im.resize(tuple(spec['size']),Image.Resampling.LANCZOS)
 dest=design/(spec['name']+'.png')
 im.save(dest)
 shutil.copy2(dest,runtime/dest.name)
 a=im.getchannel('A')
 record={**spec,'source_saved':str(source_saved),'original_size':origsize,'crop':'full generated canvas','final':str(dest),'runtime':str(runtime/dest.name),'mode':im.mode,'alpha_range':list(a.getextrema()),'alpha_zero_pixels':sum(v==0 for v in a.get_flattened_data()),'center_alpha':a.getpixel((im.width//2,im.height//2)),'visible_bbox_alpha32':list(a.point(lambda x:255 if x>32 else 0).getbbox()),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()}
 if spec['name']=='operator_halo':
  center=a.crop((96,96,160,160))
  record['center64x64_alpha_range']=list(center.getextrema())
 manifest['assets'].append(record)
 print(spec['name'],im.size,'alpha',a.getextrema(),'center',record['center_alpha'],'transparent_pixels',record['alpha_zero_pixels'])
(raw/'manifest_effects_revision02.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
preview=Image.new('RGB',(760,400),'#FBF6EC')
draw=ImageDraw.Draw(preview)
draw.rectangle((380,0,760,400),fill='#24395C')
draw.text((20,12),'Operator optical overlays / cream',fill='#24395C',font=font)
draw.text((400,12),'Navy preview',fill='#F7FFF9',font=font)
for x in [40,420]:
 im=Image.open(design/'operator_halo.png').convert('RGBA')
 small=im.resize((64,64),Image.Resampling.LANCZOS)
 preview.paste(small,(x,50),small)
 preview.paste(im,(x+76,43),im)
 gleam=Image.open(design/'operator_glint.png').convert('RGBA')
 preview.paste(gleam,(x,320),gleam)
preview.save(raw/'preview_effects_revision02.png')

