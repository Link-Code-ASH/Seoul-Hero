from pathlib import Path
import json, hashlib
from PIL import Image
root = Path(__file__).resolve().parents[4]
design = root / "design/ui-image-skins/office-day-01/gate24-bright-01"
art = "res://assets/ui/office-day-01/gate24-bright-01/"
pack = {"image_id":art+"panel_frame.png", "asset_scale":4, "preserve_source_color":True, "state_images":True, "roles":{}}
roles=pack["roles"]
def role(name, file, rect, slices, safe, **kw):
    roles[name]={"image_id":art+file,"rect":rect,"slice":slices,"safe_padding":safe,"source":"design/ui-image-skins/office-day-01/gate24-bright-01","text_color_role":"#24395c","disabled_text_color_role":"#708090",**kw}
panel=[56,199,1425,611]
for name in ("header","info","popup","cabinet"):
    role(name,"panel_frame.png",panel,[44,34,44,30],[16,12,16,12],**({"opacity":0.28} if name=="cabinet" else {}))
for tier in ("common","uncommon","rare","epic","legendary"):
    role("card_"+tier,"product_bay.png",[55,67,886,1409],[0,0,0,0],[20,18,20,16],logical_size=[162,266])
# Narrow native PNG rail has its own textured white bevel, tinted only by rarity.
role("tier_rail","controls_atlas.png",[120,104,1010,12],[12,0,12,0],[0,0,0,0],asset_scale=4)
rows={"secondary":[78,86,1096,192],"tab":[78,86,1096,192],"tab_selected":[78,320,1096,192],"primary":[78,548,1096,192],"purchase":[78,786,1096,192],"lock":[78,1011,1096,192],"lock_on":[78,320,1096,192]}
for name, rect in rows.items():
    safe=[8,4,8,4] if name not in ("lock","lock_on","purchase") else [0,0,0,0]
    role(name,"controls_atlas.png",rect,[48,24,48,24],safe)
    if name in ("primary","tab_selected"): roles[name]["text_color_role"]="#fffcf5"
    if name.endswith("_selected"): continue
    roles[name+"_pressed"]={**roles[name],"tint":[0.94,0.94,0.94,1.0]}
    roles[name+"_disabled"]={**roles[name],"rect":rows["secondary"],"tint":[0.84,0.85,0.86,1.0]}
path=root/"godot/data/visuals/ui_materials.json"
text=path.read_text(encoding="utf-8")
data=json.loads(text)
if "cstore_bright" in data["image_skin"]:
    raise SystemExit("cstore_bright already registered; inspect before replacing")
entry=json.dumps({"cstore_bright":pack},ensure_ascii=False,indent=2)[2:-2]
entry="\n".join("  "+line for line in entry.splitlines())
marker='\n  "image_skin": {'
text=text.replace(marker,marker+"\n"+entry+",",1)
assert json.loads(text)["image_skin"]["cstore_bright"]==pack
path.write_text(text,encoding="utf-8",newline="\n")
src={
"shop_background.png":"exec-995fb191-753a-4fcd-b749-01bb8b8ba8b1.png",
"panel_frame.png":"exec-f6c0d1ca-22f6-4afa-a87d-3c29455feffd.png",
"product_bay.png":"exec-854699fc-5430-4f93-ba45-423ff6284be2.png",
"controls_atlas.png":"exec-9879a0c9-ef4c-4067-8e21-f83caf69758b.png"}
files=[]
for name, generated in src.items():
    f=design/"materials"/name
    im=Image.open(f)
    a=im.getchannel("A") if im.mode=="RGBA" else None
    files.append({"file":"materials/"+name,"size":list(im.size),"mode":im.mode,"alpha_range":list(a.getextrema()) if a else None,"sha256":hashlib.sha256(f.read_bytes()).hexdigest(),"generated_source":"C:/Users/geniu/.codex/generated_images/01a124d2-3d06-7a31-b813-60c304738541/"+generated,"runtime_copy":art+name})
manifest={"status":"approved by user; runtime connected","tool":"built-in image_gen.imagegen","date":"2026-10-11","reference":"concepts/shop-items-bright.png","baseline":[915,412],"source_pixels_preserved":True,"preparation":"Lossless file copies; NinePatchRect regions and slices consume PNG atlas directly. No raster redrawing.","prompts":["PROMPTS_RUNTIME.md","PROMPTS_RUNTIME_EDITS.md"],"assets":files,"pack":pack}
(design/"materials/manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"registered_roles":len(roles),"assets":files},ensure_ascii=False,indent=2))

