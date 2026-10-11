extends Node

# Real production lobby, synthetic memory profile, deterministic 915x412 viewport.
# Run with --ui-preview --guild-office-preview to avoid user profile reads and writes.
var output := "res://../design/ui-image-skins/office-day-01/lobby-polish-01/runtime"
var stage := "before"
var view: Control
var shader_materials: Array[ShaderMaterial] = []
var animation_nodes: Array[Node] = []
var capture_clock := 0.0

func _ready() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count): await get_tree().process_frame

func _shot(file: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	if image.get_size() != Vector2i(915,412):
		push_error("Unexpected capture dimensions: %s" % image.get_size())
		get_tree().quit(1); return
	image.save_png(output.path_join(file+".png"))

func _freeze(node: Node) -> void:
	node.set_process(false)
	if "clock" in node:
		node.set("clock",0.0)
		if node.has_method("advance_for_capture"): node.advance_for_capture(0.0)
		animation_nodes.append(node)
		if node is CanvasItem: node.queue_redraw()
	if node is CanvasItem and node.material is ShaderMaterial:
		var material: ShaderMaterial = node.material
		if "lobby_plate" in material.shader.resource_path:
			var shader := Shader.new()
			shader.code = material.shader.code.replace("TIME","capture_clock_value").replace("void fragment()", "uniform float capture_clock_value = 0.0;\nvoid fragment()")
			material.shader = shader
			material.set_shader_parameter("capture_clock_value",0.0)
			shader_materials.append(material)
	for child in node.get_children(): _freeze(child)

func _speaker(enabled: bool) -> void:
	var icon := view.find_child("MusicStateIcon",true,false)
	if icon.has_method("set_visual_for_capture"):
		icon.set_visual_for_capture(enabled)
	else:
		icon.set("_enabled",enabled)
		icon.set("_level",1.0 if enabled else 0.0)
		icon.queue_redraw()

func _advance(delta: float) -> void:
	capture_clock += delta
	for tween: Tween in get_tree().get_processed_tweens(): tween.custom_step(delta)
	for node in animation_nodes:
		if node.has_method("advance_for_capture"):
			node.advance_for_capture(delta)
		elif node.name == "MusicStateIcon":
			node.set("clock",capture_clock)
			node.queue_redraw()
		else:
			node.set("clock",capture_clock)
			if node is CanvasItem: node.queue_redraw()
	for material in shader_materials:
		material.set_shader_parameter("capture_clock_value",capture_clock)
		material.set_shader_parameter("phase_override",1.0)
		material.set_shader_parameter("capture_time",capture_clock)

func _settle(seconds: float) -> void:
	var count := ceili(seconds*60.0)
	for i in range(count): _advance(1.0/60.0)
	await _frames(2)

func _run() -> void:
	await get_tree().process_frame
	if Profile.writable or "--guild-office-preview" not in OS.get_cmdline_user_args():
		push_error("Requires --ui-preview --guild-office-preview: isolated profile capture only.")
		get_tree().quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--stage="): stage = arg.trim_prefix("--stage=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	if stage == "before" and FileAccess.file_exists(output.path_join("before_lobby.png")):
		push_error("Baseline already exists; preserving the original pre-edit capture.")
		get_tree().quit(1); return
	DisplayServer.window_set_size(Vector2i(915,412))
	get_tree().root.size = Vector2i(915,412)
	AudioServer.set_bus_mute(0,true)
	Profile.meta = Content.data.defaultMeta.duplicate(true)
	HeroMeta.initialize(Content.data,Profile.meta)
	HeroMeta.apply_starter(Content.data,Profile.meta)
	for id in Content.data.characters:
		Profile.meta.characters[id].unlocked = true
	Profile.meta.settings.muted = false
	Profile.meta.settings.developerMode = false
	seed(20261011)
	HeroLobbyScreen._launch_line = "오늘 목표는 칼퇴예요. 게이트가 협조만 해 준다면요..."
	view = HeroLobbyScreen.build(func(_target): pass,"premiumLobbyWind",false)
	add_child(view)
	await _frames(3)
	get_tree().paused = true
	_freeze(view)
	for tween: Tween in get_tree().get_processed_tweens(): tween.kill()
	var crew := view.find_child("OfficeCoworkers",true,false)
	crew._clock = 0.0; crew.next_bubble = 1000.0; crew.bubble_owner = -1
	for i in range(crew.walkers.size()):
		var walker: Dictionary = crew.walkers[i]
		walker.pos = Vector2(100.0+i*126.0,366.0+(i%2)*10.0)
		walker.goal = walker.pos; walker.rest = 1000.0; walker.phase = 0.0
		walker.facing = 1.0 if i%2 == 0 else -1.0
		# Neutralize the few rendered startup frames, keeping before/after SD poses exact.
		walker.node._shown_facing = walker.facing; walker.node._facing = walker.facing
		walker.node._turn_age = 0.0; walker.node._walk = 0.0; walker.node._phase = 0.0; walker.node._lean = 0.0
	crew.step(0.0)
	var halo := view.find_child("GateHalo",true,false)
	if halo: halo.modulate.a = 0.5
	_speaker(true)
	if "--diagnose-clip" in OS.get_cmdline_user_args():
		await _capture_clip_diagnostics()
		print("LOBBY_POLISH_DIAGNOSTICS: ",output,"; Profile.writable=",Profile.writable)
		get_tree().quit(); return
	await _shot(stage+"_lobby")
	if stage == "before":
		_speaker(false); await _shot("before_speaker_off")
		var baseline_report := FileAccess.open(output.path_join("baseline_capture.json"),FileAccess.WRITE)
		baseline_report.store_string(JSON.stringify({"viewport":[915,412],"saveWrites":Profile.writable,"userProfileRead":false,"productionLobby":true,"fixedSeed":20261011,"crewFrozen":true,"operatorLine":HeroLobbyScreen._launch_line,"characters":crew_ids(),"speakerButtonRect":speaker_rect()},"  "))
		print("LOBBY_POLISH_BASELINE: ",output,"; Profile.writable=",Profile.writable)
		get_tree().quit(); return
	await _capture_after()
	print("LOBBY_POLISH_AFTER: ",output,"; Profile.writable=",Profile.writable)
	get_tree().quit()

func _capture_after() -> void:
	var menu: Button = view.find_child("LobbyArchive",true,false)
	var deploy: Button = view.find_child("LobbyDeploy",true,false)
	var menu_input_rect := Rect2(menu.position,menu.size)
	var deploy_input_rect := Rect2(deploy.position,deploy.size)
	var fixed_transforms := artwork_transforms()
	_speaker(false); await _settle(0.2); await _shot("after_speaker_off")
	_speaker(true); await _settle(0.2); await _shot("after_speaker_on")
	menu.mouse_entered.emit(); await _settle(0.25); await _shot("after_menu_hover")
	var menu_hover_x: float = menu.get_node("Face").position.x
	menu.button_down.emit(); await _shot("after_menu_pressed")
	var menu_pressed_y: float = menu.get_node("Face").position.y
	menu.button_up.emit(); menu.mouse_exited.emit(); await _settle(0.25)
	await _shot("after_menu_focus_reference")
	var real_focus_mode := menu.focus_mode
	menu.focus_mode = Control.FOCUS_ALL
	menu.grab_focus(); await _shot("after_menu_focused"); menu.release_focus()
	menu.focus_mode = real_focus_mode
	var focus_style_empty := menu.get_theme_stylebox("focus") is StyleBoxEmpty
	deploy.mouse_entered.emit(); await _settle(0.25); await _shot("after_deploy_hover")
	var deploy_hover_x: float = deploy.get_node("DeployFace").position.x
	deploy.button_down.emit(); await _shot("after_deploy_pressed")
	var deploy_pressed_y: float = deploy.get_node("DeployFace").position.y
	deploy.button_up.emit(); deploy.mouse_exited.emit(); await _settle(0.25)
	await _shot("after_restored")
	for i in range(5):
		menu.mouse_entered.emit(); await _settle(0.02)
		menu.mouse_exited.emit(); await _settle(0.02)
	await _settle(0.25)
	var report := {
		"viewport":[915,412],"saveWrites":Profile.writable,"userProfileRead":false,
		"productionLobby":true,"fixedSeed":20261011,"crewFrozen":true,
		"operatorLine":HeroLobbyScreen._launch_line,"profileCharacters":crew_ids(),
		"menuRestored":menu.get_node("Face").position.is_equal_approx(Vector2.ZERO),
		"deployRestored":deploy.get_node("DeployFace").position.is_equal_approx(Vector2.ZERO),
		"menuHoverX":menu_hover_x,"menuPressedY":menu_pressed_y,
		"deployHoverX":deploy_hover_x,"deployPressedY":deploy_pressed_y,
		"menuInputRectUnchanged":Rect2(menu.position,menu.size).is_equal_approx(menu_input_rect),
		"deployInputRectUnchanged":Rect2(deploy.position,deploy.size).is_equal_approx(deploy_input_rect),
		"rapidHoverRestored":menu.get_node("Face").position.is_equal_approx(Vector2.ZERO),
		"nativeFocusStyleEmpty":focus_style_empty,
		"speakerButtonRect":speaker_rect(),
		"artworkLocalTransformsUnchanged":fixed_transforms == artwork_transforms(),
		"artworkLocalTransforms":artwork_transforms(),
		"plateSlopes":plate_slopes(),
		"menuDeploySlopesEqual":is_equal_approx(float(plate_slopes()[0]),float(plate_slopes()[1])),
		"gifSeconds":6.0,"gifFPS":15,"frames":90,
	}
	var file := FileAccess.open(output.path_join("capture_report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	# Restart idle motion phases and create an exact 6-second interaction sequence.
	capture_clock = 0.0
	for node in animation_nodes: node.set("clock",0.0)
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	for frame in range(90):
		match frame:
			30: _speaker(false)
			23: menu.mouse_entered.emit()
			35: menu.button_down.emit()
			39: menu.button_up.emit(); menu.mouse_exited.emit()
			45: _speaker(true); deploy.mouse_entered.emit()
			63: deploy.button_down.emit()
			68: deploy.button_up.emit(); deploy.mouse_exited.emit()
		_advance(1.0/15.0)
		await _shot("frames/frame_%03d" % frame)

func crew_ids() -> Array:
	var crew := view.find_child("OfficeCoworkers",true,false)
	return crew.walkers.map(func(w): return w.id)

func speaker_rect() -> Array:
	var speaker: Button = view.find_child("LobbyMusic",true,false)
	return [speaker.position.x,speaker.position.y,speaker.size.x,speaker.size.y]

func artwork_transforms() -> Dictionary:
	var result := {}
	for button_name in ["LobbySettings","LobbyArchive","LobbyAssociation"]:
		var button := view.find_child(button_name,true,false)
		var icon := button.get_node_or_null("Face/MenuIcon")
		if icon: result[button_name] = [icon.position.x,icon.position.y,icon.scale.x,icon.scale.y]
	var gate := view.find_child("GateIcon",true,false)
	if gate: result["GateIcon"] = [gate.position.x,gate.position.y,gate.scale.x,gate.scale.y]
	var portrait := view.find_child("OperatorFace",true,false)
	if portrait: result["OperatorFace"] = [portrait.position.x,portrait.position.y,portrait.scale.x,portrait.scale.y]
	return result

func plate_slopes() -> Array:
	var result := []
	for button_name in ["LobbyArchive","LobbyDeploy"]:
		var button := view.find_child(button_name,true,false)
		var material: ShaderMaterial = button.get_node("Body/Plate").material
		var extent: Vector2 = material.get_shader_parameter("rect_size")
		var padding: float = material.get_shader_parameter("pad")
		result.append(float(material.get_shader_parameter("slant"))/(extent.y-padding*2.0))
	return result

func _capture_clip_diagnostics() -> void:
	await _shot("diagnostic_original_clipped")
	var originals: Array[Shader] = []
	for material in shader_materials:
		originals.append(material.shader)
		var probe := Shader.new()
		probe.code = material.shader.code.replace("COLOR = vec4(col, mask);","COLOR = vec4(1.0, 0.0, 1.0, mask);")
		material.shader = probe
	await _shot("diagnostic_magenta_clipped")
	for i in range(shader_materials.size()): shader_materials[i].shader = originals[i]
	for plate in view.find_children("Plate","ColorRect",true,false):
		plate.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
		var watermark := plate.get_node_or_null("Watermark")
		if watermark: watermark.visible = false
	await _shot("diagnostic_original_unclipped")
