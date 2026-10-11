"""Extract imagegen artwork and assemble raster nine-slice preview masters."""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCE = Path('C:/Users/geniu/.codex/generated_images/01a0f2b0-afe6-7281-8ba3-48d0d8354159/exec-2f3afdb7-cf0c-4e78-97f3-fc14eb562331.png')

def dump(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def slices(image, width, edge=24):
    w, h = image.size
    result = Image.new('RGBA', (width, h))
    xs = [0, edge, w-edge, w]
    targets = [0, edge, width-edge, width]
    for n in range(3):
        tile = image.crop((xs[n], 0, xs[n+1], h))
        result.paste(tile.resize((targets[n+1]-targets[n], h), Image.Resampling.LANCZOS), (targets[n], 0))
    return result

def main():
    assets = HERE/'assets'
    assets.mkdir(exist_ok=True)
    shutil.copyfile(SOURCE, assets/'controls-generated.png')
    original = Image.open(SOURCE).convert('RGBA')
    print('Generated size:', original.size)
    # Coordinates recorded on the original alpha atlas. Quiet gutters are excluded.
    specs = [
        ('back', (208,173,496,453), 176, [8,6,8,6]),
        ('secondary', (703,190,1675,434), 1488, [6,4,6,4]),
        ('tab', (38,554,859,757), 1488, [8,4,8,4]),
        ('primary', (909,554,1730,757), 1488, [10,4,10,4]),
    ]
    roles = {}
    for name, roi, width, padding in specs:
        native = original.crop(roi)
        native.save(assets/(name+'-native.png'))
        normalized = native.resize((round(native.width*176/native.height), 176), Image.Resampling.LANCZOS)
        if name == 'back':
            master = normalized.resize((176,176),Image.Resampling.LANCZOS)
        else:
            master = slices(normalized, width)
        master.save(assets/(name+'-4x.png'))
        roles[name] = {'file':'assets/'+name+'-4x.png','native_file':'assets/'+name+'-native.png',
            'rect':[0,0,*master.size],'slice':[24]*4,'asset_scale':4,
            'safe_padding':padding,'source_roi':list(roi),'native_size':list(native.size),
            'master_size':list(master.size),'preparation':'Crop + height normalization + raster nine-slice horizontal assembly. Generated rims preserved; not new generated 4K detail.'}
    roles['tab_selected'] = {**roles['tab'], 'tint':[0.82,1.0,0.94,1.0]}
    materials = json.loads((HERE/'materials.json').read_text(encoding='utf-8'))
    # Keep the approved pack tied to its own source files; new names may match.
    old_pack = materials['packs']['ops']
    if old_pack.get('file','').startswith('assets/'):
        old_pack['file'] = '../operations-standard-01/'+old_pack['file']
    for definition in old_pack['roles'].values():
        if definition.get('file','').startswith('assets/'):
            definition['file'] = '../operations-standard-01/'+definition['file']
    materials['packs']['light'] = {'file':'assets/secondary-4x.png','asset_scale':4,'roles':roles}
    dump(HERE/'materials.json',materials)
    dump(HERE/'provenance.json',{'tool':'built-in image_gen','approvalPending':True,'productionConnected':False,
        'source':{'file':'assets/controls-generated.png','size':list(original.size),'sha256':digest(SOURCE)},
        'references':['operations-standard-01/runtime/screens/approved-title.png','operations-standard-01/runtime/screens/qa-shop-weapons.png'],
        'roles':roles,'preserved':'Large operations information frames, store-specific art, content, callbacks, saves, balance, and fonts.'})
    before = {}
    for folder in ['godot/scripts','godot/data','godot/scenes','godot/shaders','src/data']:
        for path in (ROOT/folder).rglob('*'):
            if path.is_file(): before[path.relative_to(ROOT).as_posix()] = digest(path)
    dump(HERE/'runtime-before.json',before)
    print('Prepared four lightweight roles; runtime hashes:',len(before))

if __name__ == '__main__': main()
