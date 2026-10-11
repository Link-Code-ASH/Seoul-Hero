"""Connect user-approved compact raster controls to shared image definitions."""
from pathlib import Path
import copy
import json
import shutil

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
DEST=ROOT/'assets/ui/image-skin/operations-light-controls-02'
BACKUP=ROOT/'.worktrees/compact-controls-runtime-20261005'
BACKUP.mkdir(parents=True,exist_ok=True)
for relative in ['godot/data/content.json','godot/data/visuals/ui_materials.json','src/data/images.ts','scripts/export-godot-content.mjs']:
    path=BACKUP/relative
    if not path.exists():
        path.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(ROOT/relative,path)

DEST.mkdir(parents=True,exist_ok=True)
for path in (HERE/'assets').glob('*.png'): shutil.copy2(path,DEST/path.name)
shutil.copy2(HERE/'prompts.json',DEST/'source-prompts.json')
record=json.loads((HERE/'provenance.json').read_text(encoding='utf-8'))
record.update(approvalPending=False,productionConnected=True,
    approval={'date':'2026-10-05','userMessage':'구현해','preview':'design/ui-image-skins/operations-light-controls-02/index.html'})
record['previewOrigin']=str(HERE.relative_to(ROOT)).replace('\\','/')
record['source']['file']=Path(record['source']['file']).name
for role in record['roles'].values():
    for key in ['file','native_file']:
        if key in role: role[key]=Path(role[key]).name
(DEST/'provenance.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

material_path=ROOT/'godot/data/visuals/ui_materials.json'
catalog=json.loads(material_path.read_text(encoding='utf-8'))
source=json.loads((HERE/'materials.json').read_text(encoding='utf-8'))['packs']['light']
pack=copy.deepcopy(source)
ids={name:'runtimeUiCompact'+name.title() for name in ['back','secondary','tab','primary']}
pack.pop('file',None)
pack['image_id']=ids['secondary']
pack['fixed_state_geometry']=True
pack['preserve_source_color']=True
pack['selected_tint']=[0.82,1.0,0.94,1.0]
for name,role in pack['roles'].items():
    file_name=Path(role.pop('file')).name
    role['image_id']=ids[file_name.split('-')[0]]
    role['native_file']='assets/ui/image-skin/operations-light-controls-02/'+Path(role['native_file']).name
    role['states']={'geometry':'fixed','selected':'tint','disabled':'desaturate'}
    role['text_color_role']='scene' if name in ['back','primary'] else 'ink'
    role['allowed_screens']=['gate','growth','association','settings','archive','guild','offline','supply'] if name=='back' else ['title','shop']
catalog['image_skin']['compact']=pack
catalog['image_skin']['compact_revision']='operations-light-controls-02 approved 2026-10-05'
info_screens=catalog['image_skin']['ops']['roles']['info'].setdefault('allowed_screens',[])
if 'title' not in info_screens: info_screens.append('title')
material_path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

manifest_path=ROOT/'src/data/images.ts'
manifest=manifest_path.read_text(encoding='utf-8')
if 'runtimeUiCompactBack:' not in manifest:
    rows=[]
    for name,id in ids.items():
        role=pack['roles'][name]
        rows.append(f"  {id}: {{ url: file('ui/image-skin/operations-light-controls-02/{name}-4x'), heightRatio: {role['rect'][3]} / {role['rect'][2]} }},")
    manifest=manifest.replace('export const images = {','export const images = {\n'+'\n'.join(rows))
    manifest_path.write_text(manifest,encoding='utf-8')
export_path=ROOT/'scripts/export-godot-content.mjs'
exporter=export_path.read_text(encoding='utf-8')
line="for (const file of ['provenance.json','source-prompts.json']) copyAsset(path.join(root, 'assets/ui/image-skin/operations-light-controls-02', file));"
if line not in exporter:
    anchor="for (const file of ['provenance.json','source-prompts.json']) copyAsset(path.join(root, 'assets/ui/image-skin/operations-standard-01', file));"
    assert anchor in exporter
    export_path.write_text(exporter.replace(anchor,anchor+'\n'+line),encoding='utf-8')
print('Approved four compact PNG controls connected; export content next.')
