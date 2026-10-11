extends Node

# Capture the approved production screen classes without main, simulation,
# rewards/RNG, or writes. Profile changes below are in-memory UI fixtures only.
var _output := "res://exports/seoul-support-01"
var _density := 1
var _only := ""
var _view: Control
var _fx: HeroUIEffects
var _canvas := CanvasLayer.new()
var _original_meta: Dictionary
var _records: Array = []
var _checks: Array = []
var _lifecycle: Array = []
var _calls: Array = []
var _routes: Array = []
var _kind := ""

func _ready() -> void:
	_capture.call_deferred()

func _capture() -> void:
	await get_tree().process_frame
	if Profile.writable:
		push_error("Support runtime capture requires --ui-preview; save writes must be blocked.")
		get_tree().quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
		if arg.begins_with("--density="): _density = maxi(1,int(arg.trim_prefix("--density=")))
		if arg.begins_with("--scene="): _only = arg.trim_prefix("--scene=")
	DisplayServer.window_set_size(Vector2i(915,412)*_density)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),true)
	for frame in range(3): await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	_original_meta = Profile.meta
	Profile.meta = Content.data.defaultMeta.duplicate(true)
	HeroMeta.initialize(Content.data,Profile.meta)
	Profile.meta.settings.developerMode = false
	add_child(_canvas)
	_fx = HeroUIEffects.new(); _canvas.add_child(_fx); _fx.set_process(false)
	await _still("recovery","ready")
	await _still("supply","ready")
	await _still("recovery","empty")
	await _still("recovery","claimed")
	await _still("supply","insufficient")
	await _still("supply","result1")
	await _still("supply","result10")
	if _density == 1:
		for scene in ["recovery-idle","recovery-claim","supply-idle","supply-open","supply-ten"]:
			if not _only.is_empty() and _only != scene: continue
			await _animation(scene)
		await _probe("recovery")
		await _probe("supply")
	await _clear_view()
	Profile.meta = _original_meta
	_fx.queue_free(); _fx = null
	for frame in range(3): await get_tree().process_frame
	var passed := true
	for check: Dictionary in _checks:
		if not check.get("fitIssues",[]).is_empty() or not check.get("missingArt",[]).is_empty(): passed = false
	for check: Dictionary in _lifecycle:
		if not bool(check.passed): passed = false
	var report := {"size":[915*_density,412*_density],"logicalSize":[915,412],"rasterDensity":_density,"fps":30,"stage":"approved-runtime","runtimeConnected":true,"productionRenderer":true,"actualSceneRouter":"HeroMetaScreens.build","fixtureCallbacks":true,"saveWrites":false,"rewardAssignment":false,"simulation":false,"silent":true,"scenes":_records,"checks":_checks,"lifecycle":_lifecycle,"passed":passed}
	var file := FileAccess.open(_output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("SEOUL_SUPPORT_RUNTIME ",JSON.stringify({"checks":_checks.size(),"lifecycle":_lifecycle,"passed":passed,"output":ProjectSettings.globalize_path(_output)}))
	get_tree().quit(0 if passed else 1)

func _clear_view() -> void:
	if is_instance_valid(_view):
		_canvas.remove_child(_view); _view.queue_free()
	_view = null
	if is_instance_valid(_fx): _fx.bind_view(null,"support-capture-unmounted",false)
	await get_tree().process_frame

func _mount(kind: String, fixture: String = "ready") -> void:
	await _clear_view()
	_kind = kind; _calls.clear(); _routes.clear()
	Profile.meta.offlineReward.pendingRewards = {"associationCoins":1420,"revivalStones":{"low":2,"mid":1,"high":0},"supplyTickets":2}
	if fixture in ["empty","claimed"]:
		Profile.meta.offlineReward.pendingRewards = {"associationCoins":0,"revivalStones":{"low":0,"mid":0,"high":0},"supplyTickets":0}
	Profile.meta.wallet.supplyTickets = 0 if fixture == "insufficient" else 12
	_view = HeroMetaScreens.build("offline" if kind == "recovery" else "supply",{},_go,_fixture_action)
	_view.set("capture_clock",true)
	_canvas.add_child(_view)
	_canvas.move_child(_fx,_canvas.get_child_count()-1)
	_fx.bind_view(_view,"support-runtime-"+kind,false)
	for frame in range(3): await get_tree().process_frame
	if fixture == "claimed":
		# Obtain the completed visual via its real callback instead of changing a
		# renderer-only state. The ready fixture is consumed once in memory.
		Profile.meta.offlineReward.pendingRewards = {"associationCoins":1420,"revivalStones":{"low":2,"mid":1,"high":0},"supplyTickets":2}
		await _clear_view()
		_view = HeroMetaScreens.build("offline",{},_go,_fixture_action)
		_view.set("capture_clock",true); _canvas.add_child(_view)
		_canvas.move_child(_fx,_canvas.get_child_count()-1)
		_fx.bind_view(_view,"support-runtime-recovery",false)
		for frame in range(3): await get_tree().process_frame
		_press("RecoveryClaim"); _advance(0.6)
	if fixture in ["result1","result10"]:
		_press("SupplyOpen1" if fixture == "result1" else "SupplyOpen10")
		_advance(1.1)
	for frame in range(2): await get_tree().process_frame

func _fixture_action(action: String, value) -> Variant:
	_calls.append({"action":action,"value":value})
	match action:
		"claimOffline":
			var receipt: Dictionary = Profile.meta.offlineReward.pendingRewards.duplicate(true)
			Profile.meta.offlineReward.pendingRewards = {"associationCoins":0,"revivalStones":{"low":0,"mid":0,"high":0},"supplyTickets":0}
			return receipt
		"supplyOpen":
			var count := int(value)
			if int(Profile.meta.wallet.supplyTickets) < count: return []
			Profile.meta.wallet.supplyTickets -= count
			if count == 1:
				return [{"type":"associationCoin","contentId":"","amount":12},{"type":"revivalStone","contentId":"low","amount":1}]
			return [{"type":"associationCoin","contentId":"","amount":240},{"type":"revivalStone","contentId":"low","amount":3},{"type":"revivalStone","contentId":"mid","amount":1},{"type":"characterFragment","contentId":"awakener","amount":2},{"type":"weaponFragment","contentId":"manaSword","amount":3}]
	return null

func _go(destination: String) -> void:
	_routes.append(destination)

func _press(name: String) -> void:
	var button := _view.find_child(name,true,false) as Button
	if button == null: push_error("Runtime capture could not find "+name); return
	button.pressed.emit()

func _advance(dt: float) -> void:
	if is_instance_valid(_view): _view.call("advance_for_capture",dt)
	if is_instance_valid(_fx): _fx.advance_for_capture(dt)

func _diagnostics(fixture: String) -> Dictionary:
	var report: Dictionary = _view.call("diagnostics")
	report["fixture"] = fixture
	report["runtimeConnected"] = true
	report["saveWrites"] = false; report["rewardAssignment"] = false
	report["simulation"] = false; report["uiEffects"] = _fx.snapshot()
	return report

func _still(kind: String, fixture: String) -> void:
	await _mount(kind,fixture)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output.path_join(kind+"-"+fixture+".png"))
	_checks.append(_diagnostics(fixture))

func _animation(scene: String) -> void:
	await _mount("recovery" if scene.begins_with("recovery") else "supply")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output.path_join(scene)))
	var record := {"id":scene,"frames":66,"maximumParticles":0,"maximumEffects":0}
	for frame in range(66):
		if frame == 12:
			if scene == "recovery-claim": _press("RecoveryClaim")
			if scene == "supply-open": _press("SupplyOpen1")
			if scene == "supply-ten": _press("SupplyOpen10")
		_advance(1.0/30.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_output.path_join(scene).path_join("%03d.png" % frame))
		var stats := _fx.snapshot()
		record.maximumParticles = maxi(int(record.maximumParticles),int(stats.get("particles",0)))
		record.maximumEffects = maxi(int(record.maximumEffects),int(stats.get("effects",0)))
	_records.append(record)
	_checks.append(_diagnostics(scene))

func _snapshot() -> Dictionary:
	var presentation = _view.get("presentation")
	return presentation.snapshot()

func _probe(kind: String) -> void:
	await _mount(kind)
	var control := "RecoveryClaim" if kind == "recovery" else "SupplyOpen1"
	_press(control); _press(control)
	if kind == "supply": _press("SupplyOpen10")
	_lifecycle.append({"id":kind+":duplicateRequest","passed":_calls.size()==1,"acceptedCallbacks":_calls.size(),"scope":"production screen guard; fixed in-memory callback"})
	_advance(0.1)
	var before := _snapshot()
	_view.hide(); _advance(0.3)
	await get_tree().process_frame
	var after := _snapshot()
	_lifecycle.append({"id":kind+":hiddenStopsClock","passed":is_equal_approx(float(before.age),float(after.age)) and is_equal_approx(float(before.action_age),float(after.action_age))})
	_view.show()
	var presentation = _view.get("presentation")
	presentation.suspend(true)
	before = _snapshot(); _advance(0.2); after = _snapshot()
	_lifecycle.append({"id":kind+":suspendStopsClock","passed":is_equal_approx(float(before.age),float(after.age)) and is_equal_approx(float(before.action_age),float(after.action_age)) and bool(after.suspended),"scope":"component suspend hook, not an OS event"})
	presentation.suspend(false); _advance(0.1); after = _snapshot()
	_lifecycle.append({"id":kind+":resumeAdvancesClock","passed":float(after.age)>float(before.age) and float(after.action_age)>float(before.action_age)})
	_advance(1.0)
	var callback_count := _calls.size()
	if kind == "supply": _press("SupplyResultsConfirm")
	_press("SupportBack")
	_lifecycle.append({"id":kind+":confirmationDoesNotGrantAgain","passed":_calls.size()==callback_count and _routes.size()==1,"callbacks":_calls.size(),"routes":_routes.duplicate()})
	await _mount(kind)
	_press(control); _advance(0.1)
	var reference: WeakRef = weakref(_view)
	callback_count = _calls.size()
	await _clear_view()
	_fx.advance_for_capture(1.2)
	for frame in range(2): await get_tree().process_frame
	_lifecycle.append({"id":kind+":screenExitCancels","passed":reference.get_ref()==null and _calls.size()==callback_count and int(_fx.snapshot().get("pending",0))==0,"callbacks":_calls.size()})
