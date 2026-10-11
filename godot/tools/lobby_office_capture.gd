extends Node

# 2026-10-10 bright office lobby check: boots the real main scene, captures the lobby
# states and presses the lobby controls. Requires --ui-preview so nothing is saved.
var _output := "res://exports/lobby-office-2026-10-10"
var _failed := 0
var _main_scene: Node

func _ready() -> void:
	_run.call_deferred()

func _check(title: String, passed: bool, detail = "") -> void:
	if not passed: _failed += 1
	print("[%s] %s %s" % ["ok" if passed else "FAIL",title,str(detail)])

func _frames(count: int) -> void:
	for frame in range(count): await get_tree().process_frame

func _shot(id: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(_output.path_join(id+".png"))

func _lobby() -> Control:
	return _main_scene.view

func _report_text(view: Control) -> void:
	for label in view.find_children("*","Label",true,false):
		var frame: Rect2 = label.get_meta("text_frame",Rect2())
		var lines: int = label.get_line_count()
		var needed: float = label.get_minimum_size().y if label.autowrap_mode != TextServer.AUTOWRAP_OFF else label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
		var room: float = frame.size.y if label.autowrap_mode != TextServer.AUTOWRAP_OFF else frame.size.x
		_check("Text fits: "+label.text.left(18),needed <= room+0.5 and (label.max_lines_visible < 0 or lines <= label.max_lines_visible),"needs %.0f of %.0f, %d lines" % [needed,room,lines])

func _run() -> void:
	await get_tree().process_frame
	if Profile.writable:
		push_error("Lobby capture requires --ui-preview to block save writes.")
		get_tree().quit(1); return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): _output = argument.trim_prefix("--output=")
	_output = ProjectSettings.globalize_path(_output)
	DirAccess.make_dir_recursive_absolute(_output)
	DisplayServer.window_set_size(Vector2i(915,412))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),true)
	seed(20261010)
	_main_scene = load("res://scenes/main.tscn").instantiate()
	add_child(_main_scene)
	await _frames(4)
	_check("Boots straight to the lobby",_main_scene.screen == "lobby" and _lobby().find_child("LobbyDeploy",true,false) != null,_main_scene.screen)
	# The local profile may hold a checkpoint; 01-03 show the plain deploy state.
	_main_scene._mount(HeroLobbyScreen.build(_main_scene.go,"",false))
	await _frames(2)
	var crew := _lobby().find_child("OfficeCoworkers",true,false)
	print("Coworkers: %s; line: %s" % [str(crew.walkers.map(func(w): return w.id)),HeroLobbyScreen._launch_line])
	_check("Every owned awakener is on the floor",crew.walkers.size() >= 1,crew.walkers.size())
	_report_text(_lobby())
	await _shot("01-lobby")

	crew.set_process(false)
	var starts: Array = crew.walkers.map(func(w): return Vector2(w.pos))
	for index in range(360): crew.step(1.0/60.0)
	var moved := 0.0
	for i in range(starts.size()): moved = maxf(moved,Vector2(crew.walkers[i].pos).distance_to(starts[i]))
	_check("Coworkers walked after 6 seconds",moved > 20.0,"%.0f px" % moved)
	crew.next_bubble = 0.0; crew.bubble_owner = -1
	for index in range(30): crew.step(1.0/60.0)
	_check("A coworker speaks",crew.bubble.visible,crew.bubble_label.text)
	await _shot("02-lobby-later")
	for line: String in crew.LINES:
		crew.bubble_label.text = line
		_check("Bubble line fits: "+line,crew.bubble_label.get_line_count() <= 2 and crew.bubble_label.get_minimum_size().y <= crew.bubble_label.size.y+0.5,"%d lines" % crew.bubble_label.get_line_count())

	var deploy: Button = _lobby().find_child("LobbyDeploy",true,false)
	var face: Control = deploy.get_node("DeployFace")
	deploy.button_down.emit()
	_check("Deploy glass sinks when pressed",face.position.y > 0.0,face.position.y)
	await _shot("03-lobby-pressed")
	deploy.button_up.emit()
	_check("Deploy glass returns",face.position.y == 0.0)

	# Every authored line must fit; the resume shot shows the longest one.
	var shown := HeroLobbyScreen._launch_line
	var longest := ""
	var most_lines := 0
	for line: String in HeroLobbyScreen.OPERATOR_LINES:
		HeroLobbyScreen._launch_line = line
		var probe := HeroLobbyScreen.build(_main_scene.go,"",true)
		add_child(probe)
		var label: Label = probe.find_child("OperatorLine",true,false)
		var count := label.get_line_count()
		if count > 3 or label.get_minimum_size().y > label.size.y+0.5: _check("Operator line fits: "+line,false,"%d lines" % count)
		if count > most_lines or (count == most_lines and line.length() > longest.length()): most_lines = count; longest = line
		remove_child(probe); probe.free()
	print("Operator lines use at most %d lines" % most_lines)
	HeroLobbyScreen._launch_line = longest
	_main_scene._mount(HeroLobbyScreen.build(_main_scene.go,"",true))
	await _frames(2)
	_report_text(_lobby())
	_lobby().find_child("OfficeCoworkers",true,false).set_process(false)
	await _shot("04-lobby-resume")
	# Long walk with chatter for a lived-in shot.
	_main_scene._mount(HeroLobbyScreen.build(_main_scene.go,"",false))
	await _frames(2)
	var later := _lobby().find_child("OfficeCoworkers",true,false)
	later.set_process(false)
	for index in range(900): later.step(1.0/60.0)
	later.next_bubble = 0.0; later.bubble_owner = -1
	for index in range(30): later.step(1.0/60.0)
	await _shot("05-lobby-chatter")
	HeroLobbyScreen._launch_line = shown

	for entry in [["LobbyAssociation","association"],["LobbyArchive","archive"],["LobbySettings","settings"]]:
		_main_scene.go("lobby")
		await _frames(3)
		var button: Button = _lobby().find_child(str(entry[0]),true,false)
		button.pressed.emit()
		await _frames(3)
		_check("%s opens %s" % entry,_main_scene.screen == entry[1],_main_scene.screen)
	_main_scene.go("lobby")
	await _frames(3)
	var muted: bool = Profile.meta.settings.muted
	var music: Button = _lobby().find_child("LobbyMusic",true,false)
	var bus := AudioServer.get_bus_index("BGM")
	music.pressed.emit()
	await _frames(2)
	_check("Sound button toggles mute",Profile.meta.settings.muted != muted,"%s -> %s" % [str(muted),str(Profile.meta.settings.muted)])
	_check("BGM bus follows the setting",AudioServer.is_bus_mute(bus) == Profile.meta.settings.muted)
	music.pressed.emit()
	await _frames(2)
	_check("Sound button toggles back",Profile.meta.settings.muted == muted)
	_check("No save writes",not Profile.writable)
	print("LOBBY_OFFICE_CAPTURE %s; failed %d" % [_output,_failed])
	get_tree().quit(0 if _failed == 0 else 1)
