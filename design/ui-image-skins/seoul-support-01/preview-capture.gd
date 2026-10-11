extends SceneTree

# Run with the production Godot project and -- --ui-preview. This external
# preview script deliberately leaves game scene routing and content untouched.
var _output := ""
var _only := ""
var _density := 1
var _preview
var _records: Array = []
var _checks: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for frame in range(5): await process_frame
	var profile := root.get_node_or_null("Profile")
	if profile == null or profile.writable:
		push_error("Support drafts require --ui-preview and the main Godot project.")
		quit(1); return
	var folder: String = get_script().resource_path.get_base_dir()
	_output = folder.path_join("captures")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
		if arg.begins_with("--scene="): _only = arg.trim_prefix("--scene=")
		if arg.begins_with("--density="): _density = maxi(1,int(arg.trim_prefix("--density=")))
	DisplayServer.window_set_size(Vector2i(915,412)*_density)
	DirAccess.make_dir_recursive_absolute(_output)
	var script := load(folder.path_join("preview.gd"))
	if script == null: quit(1); return
	_preview = script.new(); _preview.capture_clock = true
	script = null
	_preview.source_dir = folder.path_join("source")
	root.add_child(_preview)
	for frame in range(3): await process_frame
	await _still("recovery","ready")
	await _still("supply","ready")
	await _still("recovery","empty")
	await _still("recovery","claimed")
	await _still("supply","insufficient")
	for scene in ([] if _density > 1 else ["recovery-idle","recovery-claim","supply-idle","supply-open","supply-ten"]):
		if not _only.is_empty() and _only != scene: continue
		await _animation(scene)
	var report := {"size":[915*_density,412*_density],"logicalSize":[915,412],"rasterDensity":_density,"fps":30,"stage":"approval-preview","productionSkinReused":true,"runtimeConnected":false,"saveWrites":false,"rewardAssignment":false,"simulation":false,"scenes":_records,"checks":_checks}
	var file := FileAccess.open(_output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("SEOUL_SUPPORT_PREVIEW ",JSON.stringify(report))
	_preview.queue_free(); _preview = null
	for frame in range(3): await process_frame
	quit()

func _still(screen: String, fixture: String) -> void:
	_preview.configure(screen,fixture)
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_output.path_join(screen+"-"+fixture+".png"))
	_checks.append(_preview.diagnostics())

func _animation(scene: String) -> void:
	var screen := "recovery" if scene.begins_with("recovery") else "supply"
	_preview.configure(screen,"ready")
	for frame in range(3): await process_frame
	DirAccess.make_dir_recursive_absolute(_output.path_join(scene))
	var record := {"id":scene,"frames":66,"maximumParticles":0,"maximumEffects":0}
	for frame in range(66):
		if frame == 12:
			if scene == "recovery-claim": _preview.start_claim()
			if scene == "supply-open": _preview.start_open(1)
			if scene == "supply-ten": _preview.start_open(10)
		_preview.advance(1.0/30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_output.path_join(scene).path_join("%03d.png" % frame))
		var fx: Dictionary = _preview.diagnostics().uiEffects
		record.maximumParticles = maxi(int(record.maximumParticles),int(fx.get("particles",0)))
		record.maximumEffects = maxi(int(record.maximumEffects),int(fx.get("effects",0)))
	_records.append(record)
	_checks.append(_preview.diagnostics())
