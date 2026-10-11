"""Connect the approved raster masters; never touch gameplay values or saves."""
from pathlib import Path
import copy, hashlib, json, shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DEST = ROOT / 'assets/ui/image-skin/operations-standard-01'
BACKUP = ROOT / '.worktrees/operations-runtime-20261005'
BACKUP.mkdir(parents=True, exist_ok=True)
for rel in ['godot/scripts/ui/image_skin.gd', 'godot/scripts/ui/factory.gd',
            'godot/data/visuals/ui_materials.json', 'godot/data/content.json',
            'src/data/images.ts', 'scripts/export-godot-content.mjs']:
    target = BACKUP / rel
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)
DEST.mkdir(parents=True, exist_ok=True)
for source in (HERE / 'assets').glob('*.png'):
    shutil.copy2(source, DEST / source.name)
shutil.copy2(HERE / 'prompts.json', DEST / 'source-prompts.json')
record = json.loads((HERE / 'provenance.json').read_text(encoding='utf-8'))
record.update(approvalPending=False, productionConnected=True,
              approval={'date': '2026-10-05', 'userMessage': '좋아 좋아 적용해',
                        'preview': 'design/ui-image-skins/operations-standard-01/index.html'})
record['previewOrigin'] = str(HERE.relative_to(ROOT)).replace('\\', '/')
for source in record['sources']: source['file'] = Path(source['file']).name
for role in record['roles'].values():
    for key in ['file', 'native_file']:
        if key in role: role[key] = Path(role[key]).name
(DEST / 'provenance.json').write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
catalog_path = ROOT / 'godot/data/visuals/ui_materials.json'
catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
ops = copy.deepcopy(json.loads((HERE / 'materials.json').read_text(encoding='utf-8'))['packs']['ops'])
names = ['header', 'info', 'popup', 'row', 'primary', 'secondary', 'tab']
ids = {name: 'runtimeUiOps'+name.title() for name in names}
ops['image_id'] = ids['info']
for name, role in ops['roles'].items():
    if role.get('unframed'): continue
    file_name = Path(role.pop('file')).name
    role['image_id'] = ids[file_name.split('-')[0]]
    if 'native_file' in role:
        role['native_file'] = 'assets/ui/image-skin/operations-standard-01/'+Path(role['native_file']).name
    if role.pop('grayscale', False): role['saturation'] = 0
    role['states'] = {'geometry': 'fixed', 'selected': 'tint', 'disabled': 'desaturate'}
ops['roles']['row']['allowed_screens'] = ['growth', 'guild', 'settings', 'gate']
ops['roles']['info']['allowed_screens'] = ['guild', 'growth', 'association', 'settings', 'gate', 'result', 'popup']
catalog['image_skin']['ops'] = ops
catalog['image_skin']['colors'].update(ink='#243448', muted='#657787', accent='#267F75', scene='#F5F8FA')
catalog['image_skin']['specialized_usage'] = {'cstore':['shop'], 'codex/panel':['archive'],
    'support/panel':['offline','supply'], 'spy/deploy':['lobby'], 'cards/normal':['gate','archive']}
catalog['image_skin']['operations_revision'] = 'operations-standard-01 approved 2026-10-05'
catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
manifest_path = ROOT / 'src/data/images.ts'
manifest = manifest_path.read_text(encoding='utf-8')
if 'runtimeUiOpsHeader:' not in manifest:
    rows = []
    for name in names:
        role = ops['roles'][name]
        rows.append(f"  {ids[name]}: {{ url: file('ui/image-skin/operations-standard-01/{name}-4x'), heightRatio: {role['rect'][3]} / {role['rect'][2]} }},")
    manifest = manifest.replace('export const images = {', 'export const images = {\n'+'\n'.join(rows))
    manifest_path.write_text(manifest, encoding='utf-8')
export_path = ROOT / 'scripts/export-godot-content.mjs'
exporter = export_path.read_text(encoding='utf-8')
line = "for (const file of ['provenance.json','source-prompts.json']) copyAsset(path.join(root, 'assets/ui/image-skin/operations-standard-01', file));"
if line not in exporter:
    exporter = exporter.replace("copyAsset(path.join(root, 'assets/ui/image-skin/provenance.json'));", "copyAsset(path.join(root, 'assets/ui/image-skin/provenance.json'));\n"+line)
    export_path.write_text(exporter, encoding='utf-8')
print('Approved operations raster assets and semantic roles connected.')
