extends Control

# Six approval drafts + component board. No gameplay classes or autoloads.
const Common := preload("res://common.gd")
const Guild := preload("res://guild_draft.gd")
const Lobby := preload("res://lobby_draft.gd")
const Gate := preload("res://gate_drafts.gd")
const HUDShop := preload("res://hud_shop.gd")
const NAMES := ["00-materials","01-guild","02-lobby","03-shop","04-character","05-archive","06-hud"]
var ui
var records: Array = []

func _ready() -> void:
	if "--capture" not in OS.get_cmdline_user_args(): get_tree().quit(); return
	_capture.call_deferred()

func _capture() -> void:
	var path := ProjectSettings.globalize_path("res://")
	ui = Common.new(path)
	DirAccess.make_dir_recursive_absolute(path.path_join("captures"))
	for id in NAMES:
		await _screen(id,path)
	# Additional representative size captures, using the exact same layout.
	for target in [Vector2i(844,390),Vector2i(1830,824)]:
		DisplayServer.window_set_size(target)
		for tick in range(3): await get_tree().process_frame
		for id in ["01-guild","03-shop","04-character","05-archive","06-hud"]:
			await _screen(id,path,"-%dx%d" % [target.x,target.y])
	DisplayServer.window_set_size(Vector2i(915,412))
	for tick in range(3): await get_tree().process_frame
	var errors := 0
	for record in records: errors += record.fitIssues.size()
	var out := FileAccess.open(path.path_join("captures/layout.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify({"previewOnly":true,"approvalPending":true,"productionLoaded":false,"saveAdaptersLoaded":false,"simulation":false,"audioPlayback":false,"records":records,"fitIssues":errors},"\t"))
	print("Operations UI standards drafts: ",NAMES.size(),"; fitIssues=",errors)
	get_tree().quit(0 if errors == 0 else 3)

func _screen(id: String, path: String, suffix: String = "") -> void:
	ui.reset()
	var surface := Control.new(); surface.size = Common.CANVAS
	add_child(surface)
	match id:
		"00-materials": _board(surface)
		"01-guild": Guild.build(ui,surface)
		"02-lobby": Lobby.build(ui,surface)
		"03-shop": HUDShop.build(ui,surface,"shop-items")
		"04-character":
			ui.wash(surface,Color("#EDF2F4")); Gate.build(ui,surface,"character")
		"05-archive":
			ui.wash(surface,Color("#EDF2F4")); Gate.build(ui,surface,"archive")
		"06-hud": HUDShop.build(ui,surface,"hud")
	for frame in range(4): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path.path_join("captures/"+id+suffix+".png"))
	records.append(ui.report(id+suffix))
	surface.free()
	await get_tree().process_frame

func _board(parent: Control) -> void:
	ui.wash(parent,Color("#DCE4E8"))
	ui.header(parent,"도시 작전풍 · UI 소재 규격")
	ui.material(parent,"ops/info",Rect2(20,78,272,214))
	ui.text(parent,"정보판",Rect2(40,90,232,28),"heading",18,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(parent,"길드 · 성장 · 협회 · 설정\n밝은 내용 면과 남색 구조",Rect2(40,126,232,44),"body",14,"ink",HORIZONTAL_ALIGNMENT_LEFT,true)
	ui.material(parent,"ops/row",Rect2(40,186,232,44))
	ui.text(parent,"목록 행 · 동일한 형상",Rect2(54,190,204,36),"control",16,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	ui.material(parent,"ops/popup",Rect2(306,78,272,214))
	ui.text(parent,"팝업",Rect2(326,90,232,28),"heading",18,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(parent,"상세 · 분기 · 생환 · 확인\n제목과 버튼은 고정",Rect2(326,126,232,44),"body",14,"ink",HORIZONTAL_ALIGNMENT_LEFT,true)
	ui.button(parent,"확인",Rect2(326,233,232,44),"ops/primary",16)
	ui.text(parent,"조작과 상태",Rect2(610,80,280,28),"heading",18)
	ui.button(parent,"주 행동",Rect2(604,116,138,44),"ops/primary",16)
	ui.button(parent,"보조 행동",Rect2(756,116,138,44),"ops/secondary",16)
	ui.button(parent,"탭",Rect2(604,172,138,44),"ops/tab",16)
	ui.button(parent,"선택된 탭",Rect2(756,172,138,44),"ops/tab_selected",16)
	ui.button(parent,"비활성",Rect2(604,228,138,44),"ops/disabled",16)
	ui.text(parent,"상태가 바뀌어도\n내용과 모서리는 고정",Rect2(756,227,138,50),"body",14,"muted",HORIZONTAL_ALIGNMENT_LEFT,true)
	ui.text(parent,"전용 소재",Rect2(24,306,158,26),"heading",18)
	ui.text(parent,"책등 → 자료집  /  편의점 → 게이트24  /  유리 카드 → 선택 목록",Rect2(184,306,700,26),"body",14)
	ui.text(parent,"BMJUA 제목",Rect2(24,352,214,35),"brand",24)
	ui.text(parent,"해옹산스 소제목",Rect2(248,352,216,35),"heading",18)
	ui.text(parent,"Paperlogy 본문",Rect2(480,352,218,35),"body",14)
	ui.text(parent,"1,680 / 24",Rect2(716,352,176,35),"number",18)
