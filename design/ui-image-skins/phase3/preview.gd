extends Control
# Separate design project: frozen fixtures only, no runtime, saves, simulation or audio.
const Common := preload("res://common.gd")
const HUD := preload("res://hud.gd")
const Gate := preload("res://gate_drafts.gd")
const Meta := preload("res://meta_drafts.gd")
const SCREENS := ["01-hud","02-materials","03-map","04-depth","05-character","06-weapon","07-blessing","08-formation","09-growth","10-archive","11-settings","12-pause"]
var ui
var output: String

func _ready() -> void:
	var project_dir := ProjectSettings.globalize_path("res://").simplify_path()
	ui = Common.new(project_dir)
	output = project_dir.path_join("captures")
	if not "--capture" in OS.get_cmdline_user_args():
		print("Phase3 preview project. --capture exports separated drafts; --screen=id limits a capture.")
		get_tree().quit(); return
	DirAccess.make_dir_recursive_absolute(output)
	await capture()

func capture() -> void:
	var reports: Array[Dictionary] = []
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screen="): requested = argument.trim_prefix("--screen=")
	var screens := SCREENS.duplicate()
	if "--hud-stress" in OS.get_cmdline_user_args(): screens = ["01-hud","13-hud-low-hp"]
	if not requested.is_empty(): screens = [requested]
	for screen in screens:
		ui.reset()
		var surface := Control.new(); surface.size = Common.CANVAS; add_child(surface)
		var kind := str(screen).get_slice("-",1)
		if kind == "hud" or kind == "pause": HUD.build(ui,surface,screen)
		elif kind == "materials": material_board(surface)
		elif kind in ["map","depth","character","weapon","blessing","formation"]:
			menu_background(surface,kind)
			Gate.build(ui,surface,kind)
		else:
			menu_background(surface,kind)
			Meta.build(ui,surface,str(screen))
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join(str(screen)+".png"))
		reports.append(ui.report(str(screen)))
		surface.queue_free(); await get_tree().process_frame
	var issues := 0
	for report in reports: issues += report.fitIssues.size()
	var file_name := "hud-fit.json" if "--hud-stress" in OS.get_cmdline_user_args() else "font-fit.json" if requested.is_empty() else requested+"-fit.json"
	var file := FileAccess.open(output.path_join(file_name),FileAccess.WRITE)
	file.store_string(JSON.stringify({"size":[915,412],"previewOnly":true,"productionLoaded":false,"saveAdaptersLoaded":false,"simulation":false,"audioPlayback":false,"contentSha256":FileAccess.get_sha256(ui.repo_dir.path_join("godot/data/content.json")),"screens":reports,"issueCount":issues},"\t"))
	print("Phase3 screenshots: ",reports.size(),"; fontFitIssues=",issues,"; ",output)
	get_tree().quit(0 if issues == 0 else 3)

func menu_background(parent: Control, kind: String) -> void:
	var source := "metaGrowthLab" if kind in ["growth","blessing"] else "metaOfflineTerminal" if kind == "settings" else "metaAssociationOffice"
	ui.image(parent,source,Rect2(0,0,915,412),false,true)
	ui.wash(parent,Color(0.94,0.97,0.98,0.91))

func material_board(parent: Control) -> void:
	menu_background(parent,"materials")
	ui.header(parent,"새 PNG 소재","각 화면의 목적에 맞춘 안내판 · 발판 · 진열대 · 청자 · 콘솔")
	var defaults := [
		{"pack":"navigation","title":"구역 안내판","element":"panel","caption":"청회색 지도 테두리"},
		{"pack":"personnel","title":"각성자 발판","element":"plinth","caption":"가벼운 인물 선택 표시"},
		{"pack":"armory","title":"장비 진열대","element":"tray","caption":"홈이 있는 장비 선반"},
		{"pack":"arcane","title":"단군의 축복","element":"plinth","caption":"청자 · 금속 · 금색"},
		{"pack":"codex","title":"수집 자료집","element":"tile","caption":"썸네일 진열 소재"},
		{"pack":"console","title":"설정 콘솔","element":"row","caption":"낮은 채도의 조작 행"},
		{"pack":"command","title":"작전 알림","element":"panel","caption":"별도 일시정지 표면"},
		{"pack":"controls","title":"공용 버튼","element":"primary","caption":"주요 · 보조 · 상태"}
	]
	var entries: Array = ui.materials.get("board",defaults)
	for index in range(mini(entries.size(),8)):
		var entry: Dictionary = entries[index]
		var x := 24+(index%4)*223; var y := 94+floori(index/4.0)*154
		var pack := str(entry.pack)
		if ui.materials.packs[pack].roles.has("title"): ui.material(parent,pack+"/title",Rect2(x,y+27,198,27))
		ui.text(parent,str(entry.get("title",pack)),Rect2(x+8,y,182,24),"heading",17,"ink",HORIZONTAL_ALIGNMENT_CENTER)
		ui.material(parent,pack+"/"+str(entry.get("element","panel")),Rect2(x+5,y+65,188,58))
		ui.text(parent,str(entry.get("caption","")),Rect2(x,y+131,198,25),"body",13,"muted",HORIZONTAL_ALIGNMENT_CENTER)
