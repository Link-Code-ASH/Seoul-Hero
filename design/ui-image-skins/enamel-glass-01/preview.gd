extends Control
const Common := preload("res://common.gd")
const HUDShop := preload("res://hud_shop.gd")
const Gate := preload("res://gate_drafts.gd")
const Lobby := preload("res://lobby_draft.gd")
const SCREENS := ["01-hud","02-character","03-weapon","04-blessing","05-archive","06-lobby","07-shop-weapons","08-shop-items"]
var ui
func _ready() -> void:
	if not "--capture" in OS.get_cmdline_user_args(): get_tree().quit(); return
	var dir := ProjectSettings.globalize_path("res://").simplify_path()
	ui = Common.new(dir)
	var output := dir.path_join("captures")
	DirAccess.make_dir_recursive_absolute(output)
	var reports: Array = []
	for screen in SCREENS:
		ui.reset()
		var surface := Control.new(); surface.size = Common.CANVAS; add_child(surface)
		var kind := str(screen).substr(3)
		if kind == "hud" or kind.begins_with("shop-"): HUDShop.build(ui,surface,kind)
		elif kind == "lobby": Lobby.build(ui,surface)
		else:
			ui.wash(surface,Color(0.93,0.96,0.96,1.0))
			Gate.build(ui,surface,kind)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join(str(screen)+".png"))
		reports.append(ui.report(str(screen)))
		surface.free()
		await get_tree().process_frame
	# The gallery animates only this authored PNG; no CSS-generated light or frame.
	ui.reset()
	var lobby_base := Control.new(); lobby_base.size = Common.CANVAS; add_child(lobby_base)
	Lobby.build(ui,lobby_base)
	lobby_base.get_node("OperationScan").hide()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("06-lobby-base.png"))
	var pulse_bounds: Array = ui.materials.packs.spy.roles.pulse.rect
	var pulse_source: Image = ui.texture("assets/spy-02.png",false).get_image()
	pulse_source.get_region(Rect2i(int(pulse_bounds[0]),int(pulse_bounds[1]),int(pulse_bounds[2]),int(pulse_bounds[3]))).save_png(dir.path_join("assets/lobby-scan-overlay.png"))
	lobby_base.free()
	await get_tree().process_frame
	ui.reset()
	var audit := Control.new(); audit.visible = false; add_child(audit)
	var audited_products := 0
	for group in ["items","weapons"]:
		for id in ui.content[group]:
			var product: Dictionary = ui.content[group][id]
			var short: Dictionary = product.get("shopCardText",{})
			ui.text(audit,str(product.name),Rect2(20,87,122,42),"heading",15,"ink",HORIZONTAL_ALIGNMENT_CENTER,true)
			ui.text(audit,str(short.get("summary","")),Rect2(20,132,122,36),"body",13,"ink",HORIZONTAL_ALIGNMENT_LEFT,true)
			ui.text(audit,str(short.get("penalty","")),Rect2(20,173,122,36),"body",13,"danger",HORIZONTAL_ALIGNMENT_LEFT,true)
			audited_products += 1
	await get_tree().process_frame
	await get_tree().process_frame
	var copy_report: Dictionary = ui.report("shop-copy-audit")
	audit.free()
	var issue_count: int = copy_report.fitIssues.size()
	for report in reports: issue_count += report.fitIssues.size()
	var f := FileAccess.open(output.path_join("font-fit.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"size":[915,412],"previewOnly":true,"approvalPending":true,"productionLoaded":false,"saveAdaptersLoaded":false,"simulation":false,"audioPlayback":false,"screens":reports,"shopCopyAudit":{"products":audited_products,"labels":copy_report.labels.size(),"fitIssues":copy_report.fitIssues},"issueCount":issue_count},"\t"))
	print("Enamel/glass drafts: ",reports.size(),"; fitIssues=",issue_count)
	get_tree().quit(0 if issue_count == 0 else 3)
