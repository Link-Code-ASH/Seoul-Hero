extends Node

# 2026-10-11 desk restyle check: boots the real main scene and captures every menu that now
# shares the archive desk look (협회, 설정, 자료집, 출동 준비 6 steps) plus the lobby states.
# Requires --ui-preview so nothing is saved.
var _output := "res://exports/desk-screens-2026-10-11"
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

func _report_text(view: Control, screen: String) -> void:
	for label in view.find_children("*","Label",true,false):
		if not label.is_visible_in_tree() or label.text.is_empty(): continue
		var frame: Rect2 = label.get_meta("text_frame",Rect2())
		if frame.size == Vector2.ZERO: continue
		var lines: int = label.get_line_count()
		var needed: float = label.get_minimum_size().y if label.autowrap_mode != TextServer.AUTOWRAP_OFF else label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
		var room: float = frame.size.y if label.autowrap_mode != TextServer.AUTOWRAP_OFF else frame.size.x
		if needed > room+0.5 or (label.max_lines_visible >= 0 and lines > label.max_lines_visible):
			_check("%s text fits: %s" % [screen,label.text.left(18)],false,"needs %.0f of %.0f, %d lines" % [needed,room,lines])

func _run() -> void:
	await get_tree().process_frame
	if Profile.writable:
		push_error("Desk capture requires --ui-preview to block save writes.")
		get_tree().quit(1); return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): _output = argument.trim_prefix("--output=")
	_output = ProjectSettings.globalize_path(_output)
	DirAccess.make_dir_recursive_absolute(_output)
	DisplayServer.window_set_size(Vector2i(915,412))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),true)
	seed(20261011)
	_main_scene = load("res://scenes/main.tscn").instantiate()
	add_child(_main_scene)
	await _frames(6)
	_report_text(_main_scene.view,"lobby")
	await _shot("01-lobby")
	# Hover lights the glass plate without swapping its art.
	var row: Button = _main_scene.view.find_child("LobbyAssociation",true,false)
	if row != null:
		row.mouse_entered.emit()
		await _frames(12)
		await _shot("02-lobby-hover")
		row.mouse_exited.emit()

	_main_scene.go("association")
	_main_scene._meta_action("associationSelect","draw:character")
	_main_scene._refresh()
	await _frames(3)
	_check("Association opens",_main_scene.screen == "association",_main_scene.screen)
	_check("Association coin label",_main_scene.view.find_child("AssociationCoins",true,false) != null)
	_check("Association draw key",_main_scene.view.find_child("AssociationDraw",true,false) != null)
	_report_text(_main_scene.view,"association-draw")
	await _shot("03-association-draw")
	var first_upgrade := str(Content.data.upgrades.keys()[0])
	_main_scene._meta_action("associationSelect",first_upgrade)
	_main_scene._refresh()
	await _frames(3)
	_check("Association upgrade selected",_main_scene.view.find_child("AssociationBuy",true,false) != null)
	_report_text(_main_scene.view,"association-upgrade")
	await _shot("04-association-upgrade")

	_main_scene.go("settings")
	await _frames(3)
	_check("Settings opens",_main_scene.screen == "settings",_main_scene.screen)
	_check("Settings has volume sliders",_main_scene.view.find_child("Volume_masterVolume",true,false) != null)
	_report_text(_main_scene.view,"settings")
	await _shot("05-settings")

	_main_scene.go("archive")
	await _frames(3)
	_check("Archive opens",_main_scene.screen == "archive",_main_scene.screen)
	_main_scene._archive_select("group","characters")
	await _frames(3)
	_report_text(_main_scene.view,"archive-characters")
	await _shot("06-archive-characters")
	_main_scene._archive_select("group","enemies")
	await _frames(3)
	_report_text(_main_scene.view,"archive-enemies")
	await _shot("07-archive-enemies")

	_main_scene.go("gate")
	await _frames(3)
	_check("Gate opens",_main_scene.screen == "gate",_main_scene.screen)
	var names := ["map","floor","character","weapon","blessing","formation"]
	for step in range(6):
		_main_scene._gate_navigate(step)
		await _frames(3)
		_check("Gate step %d shows" % step,_main_scene.gate_step == step,_main_scene.gate_step)
		_report_text(_main_scene.view,"gate-"+names[step])
		await _shot("%02d-gate-%s" % [8+step,names[step]])
	_main_scene.go("lobby")
	await _frames(3)
	_check("Back to lobby",_main_scene.screen == "lobby")
	_check("No save writes",not Profile.writable)
	print("DESK_SCREENS_CAPTURE %s; failed %d" % [_output,_failed])
	get_tree().quit(0 if _failed == 0 else 1)
