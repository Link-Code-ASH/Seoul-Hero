extends Control

# Standalone raster approval drafts. Production scripts/autoloads never load.
const Common := preload("res://common.gd")
const Title := preload("res://title_draft.gd")
const Gate := preload("res://gate_drafts.gd")
const HUDShop := preload("res://hud_shop.gd")
const NAMES := ["00-materials","01-title-resume","02-character","03-shop-weapons","04-shop-items","05-title-start"]
var ui
var records: Array = []

func _ready() -> void:
	if "--capture" not in OS.get_cmdline_user_args(): get_tree().quit(); return
	_capture.call_deferred()

func _capture() -> void:
	var path := ProjectSettings.globalize_path("res://")
	ui = Common.new(path)
	DirAccess.make_dir_recursive_absolute(path.path_join("captures"))
	for id in NAMES: await _screen(id,path)
	var errors := 0
	for record in records: errors += record.fitIssues.size()
	var out := FileAccess.open(path.path_join("captures/layout.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify({"previewOnly":true,"approvalPending":true,"productionLoaded":false,"saveAdaptersLoaded":false,"simulation":false,"audioPlayback":false,"records":records,"fitIssues":errors},"\t"))
	print("Light operations control drafts: ",NAMES.size(),"; fitIssues=",errors)
	get_tree().quit(0 if errors == 0 else 3)

func _screen(id: String, path: String, suffix: String = "") -> void:
	ui.reset()
	var surface := Control.new(); surface.size = Common.CANVAS
	add_child(surface)
	match id:
		"00-materials": _board(surface)
		"01-title-resume": Title.build(ui,surface,true)
		"05-title-start": Title.build(ui,surface,false)
		"02-character":
			ui.wash(surface,Color("#EDF2F4")); Gate.build(ui,surface,"character")
		"03-shop-weapons": HUDShop.build(ui,surface,"shop-weapons")
		"04-shop-items": HUDShop.build(ui,surface,"shop-items")
	for frame in range(4): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path.path_join("captures/"+id+suffix+".png"))
	records.append(ui.report(id+suffix))
	surface.free()
	await get_tree().process_frame

func _board(parent: Control) -> void:
	ui.wash(parent,Color("#EDF2F4"))
	ui.header(parent,"가벼운 작전 조작 프레임", "", "", {"back":false})
	ui.material(parent,"ops/info",Rect2(20,78,294,318))
	ui.text(parent,"복귀 조작",Rect2(40,90,254,28),"heading",18,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(parent,"현재 프레임",Rect2(40,126,112,24),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(parent,"가벼운 프레임",Rect2(180,126,114,24),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	ui.button(parent,"‹",Rect2(74,166,44,44),"ops/secondary",24)
	ui.button(parent,"‹",Rect2(215,166,44,44),"light/back",24)
	ui.text(parent,"동일한 44px 터치 영역\n얇은 테두리와 밝은 표면",Rect2(40,236,254,50),"body",14,"muted",HORIZONTAL_ALIGNMENT_LEFT,true)
	ui.material(parent,"ops/row",Rect2(40,314,254,48))
	ui.text(parent,"구조 프레임은 유지",Rect2(54,318,226,40),"control",16,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	ui.material(parent,"ops/info",Rect2(330,78,564,318))
	ui.text(parent,"조작과 상태",Rect2(350,90,524,28),"heading",18,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	ui.button(parent,"보조 행동",Rect2(350,130,248,44),"light/secondary",16)
	ui.button(parent,"주 행동",Rect2(626,130,248,44),"light/primary",16)
	ui.button(parent,"무기",Rect2(350,190,116,44),"light/tab",16)
	ui.button(parent,"아이템",Rect2(482,190,116,44),"light/tab_selected",16)
	ui.button(parent,"비활성",Rect2(626,190,248,44),"light/secondary",16,{"disabled":true})
	ui.text(parent,"선택·비활성 상태에서도\n같은 PNG와 내용 위치 유지",Rect2(350,250,524,48),"body",14,"muted",HORIZONTAL_ALIGNMENT_LEFT,true)
	ui.button(parent,"아이템 1",Rect2(350,326,74,44),"light/secondary",16,{"padding":[6,4,6,4]})
	ui.button(parent,"조합",Rect2(432,326,81,44),"light/secondary",16)
	ui.text(parent,"상점 하단 실제 폭 · 74 / 81px",Rect2(534,326,340,44),"body",13,"muted")
