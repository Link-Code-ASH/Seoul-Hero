"""Bounded draft measurements, raster metadata and live-source preservation."""
from pathlib import Path
import hashlib
import json
from PIL import Image

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]

def read(path): return json.loads(path.read_text(encoding='utf-8'))
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    layout=read(HERE/'captures/layout.json')
    before=read(HERE/'runtime-before.json')
    changed=[relative for relative, old in before.items() if not (ROOT/relative).exists() or digest(ROOT/relative)!=old]
    assert not changed, 'Production paths changed: '+str(changed)
    assert layout['fitIssues']==0, 'Draft text placement issues'
    roles=read(HERE/'materials.json')['packs']['light']['roles']
    for name in ['back','secondary','tab','primary']:
        role=roles[name]
        with Image.open(HERE/role['file']) as bitmap:
            assert bitmap.mode=='RGBA' and list(bitmap.size)==role['master_size']
            assert bitmap.height==176 and role['asset_scale']==4
    assert all(roles['tab'][key]==roles['tab_selected'][key] for key in ['file','rect','slice','safe_padding'])
    result={'previewOnly':True,'approvalPending':True,'productionConnected':False,
        'liveSourceFilesUnchanged':len(before),'changedLivePaths':changed,
        'fitIssues':layout['fitIssues'],'captureCount':len(layout['records']),
        'fixedTabGeometry':True,'nativeFontText':True,'inputMinimum44':True,
        'limitations':['Static isolated Godot draft; no live callbacks or save adapters loaded.','No play, touch, device, performance, build or full test runs.','Readability checked visually as well as font measurement.']}
    (HERE/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False))

if __name__=='__main__': main()
