"""Prepare independent raster UI drafts; production assets/data are read-only."""
from pathlib import Path
from PIL import Image
import hashlib
import json
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
GENERATED = Path('C:/Users/geniu/.codex/generated_images/01a0f2b0-afe6-7281-8ba3-48d0d8354159')

def sha(file): return hashlib.sha256(file.read_bytes()).hexdigest()
def dump(file, data): file.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def expand_slices(image, target, edge):
    # Raster 9-slice assembly retains generated corners, not code-drawn artwork.
    w,h = image.size; tw,th = target; e = edge
    result = Image.new('RGBA',target)
    xx=[0,e,w-e,w]; yy=[0,e,h-e,h]
    tx=[0,e,tw-e,tw]; ty=[0,e,th-e,th]
    for row in range(3):
        for col in range(3):
            part=image.crop((xx[col],yy[row],xx[col+1],yy[row+1]))
            size=(tx[col+1]-tx[col],ty[row+1]-ty[row])
            result.paste(part.resize(size,Image.Resampling.LANCZOS),(tx[col],ty[row]))
    return result

def extract(source, roi, output, target, edge, native):
    image=Image.open(source).convert('RGBA').crop(roi)
    bbox=image.getchannel('A').point(lambda x:255 if x>=32 else 0).getbbox()
    image=image.crop(bbox)
    image.save(native)
    expand_slices(image,target,edge).save(output)
    return {'file':'assets/'+output.name,'native_file':'assets/'+native.name,'native_size':list(image.size),'master_size':list(target),'rect':[0,0,*target],'slice':[edge]*4,'asset_scale':4,'safe_padding':[20,12,20,12],'source_sheet':source.name,'source_roi':list(roi),'trim_bbox':list(bbox),'preparation':'Raster 9-slice master expansion; generated corners preserved. Native source retained; not new 4K generated detail.'}

def main():
    assets=HERE/'assets'; assets.mkdir(exist_ok=True)
    structure=GENERATED/'exec-fb166f0b-08a7-4d62-aade-82c023c02082.png'
    controls=GENERATED/'exec-21721008-74f2-4320-bae3-7ee452840e2f.png'
    for source,name in [(structure,'structures-generated.png'),(controls,'controls-generated.png')]: shutil.copyfile(source,assets/name)
    roles={}
    definitions=[
        ('header',structure,(0,210,668,475),(3532,208),32),
        ('info',structure,(665,0,1254,704),(1616,1312),40),
        ('popup',structure,(0,651,621,1254),(1920,1312),40),
        ('row',structure,(615,790,1254,1100),(2000,192),32),
        ('primary',controls,(0,0,1448,370),(1488,176),44),
        ('secondary',controls,(0,370,1448,720),(1488,176),44),
        ('tab',controls,(0,720,1448,1086),(1488,176),44),
    ]
    for name,source,roi,size,edge in definitions:
        roles[name]=extract(source,roi,assets/(name+'-4x.png'),size,edge,assets/(name+'-native.png'))
    roles['header']['safe_padding']=[16,8,16,8]
    for name in ['primary','secondary','tab']: roles[name]['safe_padding']=[14,4,14,4]
    roles['tab_selected']={**roles['tab'],'tint':[0.80,1.0,0.91,1]}
    roles['disabled']={**roles['secondary'],'grayscale':True,'tint':[0.80,0.84,0.88,1]}
    roles['icon']={'unframed':True,'hit_size':[44,44],'safe_padding':[0,0,0,0],'asset_scale':1,'description':'Native transparent input; PNG icon content; no surrounding frame.'}
    skin=json.loads((ROOT/'godot/data/visuals/ui_materials.json').read_text(encoding='utf-8'))['image_skin']
    content=json.loads((ROOT/'godot/data/content.json').read_text(encoding='utf-8'))
    packs={}
    for name,entry in skin.items():
        if not isinstance(entry,dict) or 'roles' not in entry: continue
        pack=json.loads(json.dumps(entry)); original_file=pack.get('file','')
        if pack.get('image_id'): original_file=content['images'][pack['image_id']]['url']
        pack['file']=original_file
        for role,definition in pack['roles'].items():
            if definition.get('image_id'): definition['file']=content['images'][definition['image_id']]['url']
            if 'rect' not in definition and 'cell' in definition:
                raw=Image.open(ROOT/'godot'/original_file.removeprefix('res://'))
                cell=definition['cell']; cw=raw.width/pack['columns']; ch=raw.height/pack['rows']
                if isinstance(cell,list): x,y=cell
                else: x,y=cell%pack['columns'],cell//pack['columns']
                definition['rect']=[int(x*cw),int(y*ch),int(cw),int(ch)]
        packs[name]=pack
    packs['ops']={'file':'assets/info-4x.png','asset_scale':4,'roles':roles}
    dump(HERE/'materials.json',{'previewOnly':True,'approvalPending':True,'packs':packs})
    source=ROOT/'design/ui-image-skins/enamel-glass-01/common.gd'
    if not (HERE/'common.gd').exists(): shutil.copyfile(source,HERE/'common.gd')
    source=ROOT/'design/ui-image-skins/guild-offices-01'
    for relative in ['world.gd','sd_visual.gd','shaders/sd_feet.gdshader','assets/visuals/vfx/contact_shadow.png']:
        destination=HERE/relative; destination.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(source/relative,destination)
    dump(HERE/'provenance.json',{'tool':'built-in image_gen','approvalPending':True,'productionConnected':False,'sources':[{'file':'assets/structures-generated.png','size':list(Image.open(structure).size),'sha256':sha(structure)},{'file':'assets/controls-generated.png','size':list(Image.open(controls).size),'sha256':sha(controls)}],'roles':roles,'reference':'design/ui-image-skins/guild-offices-01/runtime/03-management.png','reuse':'Existing approved Seoul scene, SD/monster/item PNGs, card backgrounds, book-spine and store assets read unchanged.'})
    local=ROOT/'.worktrees/operations-standard-01'; local.mkdir(parents=True,exist_ok=True)
    files={}
    for folder in ['godot/scripts','godot/data','godot/shaders','godot/scenes','src/data']:
        for file in (ROOT/folder).rglob('*'):
            if file.is_file(): files[file.relative_to(ROOT).as_posix()]=sha(file)
    if not (local/'runtime-before.json').exists(): dump(local/'runtime-before.json',files)
    print(json.dumps({'roles':list(roles),'sourceSizes':[list(Image.open(structure).size),list(Image.open(controls).size)],'runtimeHashFiles':len(files)},ensure_ascii=False))

if __name__=='__main__': main()
