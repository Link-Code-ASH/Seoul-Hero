extends Node

# 2026-10-10 office restyle check: boots the real main scene and captures the lobby,
# association and archive screens. Requires --ui-preview so nothing is saved.
var _output := "res://exports/office-screens-2026-10-10"
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
		push_error("Office capture requires --ui-preview to block save writes.")
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
	await _frames(6)
	_report_text(_main_scene.view,"lobby")
	await _shot("01-lobby")

	_main_scene.go("association")
	await _frames(3)
	_check("Association opens",_main_scene.screen == "association",_main_scene.screen)
	_check("Association coin label",_main_scene.view.find_child("AssociationCoins",true,false) != null)
	_report_text(_main_scene.view,"association")
	await _shot("02-association")
	var first_upgrade := str(Content.data.upgrades.keys()[0])
	_main_scene._meta_action("associationSelect",first_upgrade)
	_main_scene._refresh()
	await _frames(3)
	_check("Association upgrade selected",_main_scene.view.find_child("AssociationBuy",true,false) != null)
	_report_text(_main_scene.view,"association-upgrade")
	await _shot("03-association-upgrade")

	_main_scene.go("archive")
	await _frames(3)
	_check("Archive opens",_main_scene.screen == "archive",_main_scene.screen)
	var index := 4
	for group in HeroArchive.GROUPS:
		_main_scene._archive_select("group",group)
		await _frames(3)
		var view: Control = _main_scene.view
		_check("Archive %s has collection" % group,view.find_child("ArchiveCollection",true,false) != null)
		_report_text(view,"archive-"+group)
		await _shot("%02d-archive-%s" % [index,group])
		index += 1
	_main_scene._archive_select("group","characters")
	_main_scene._archive_select("page",2)
	await _frames(3)
	_report_text(_main_scene.view,"archive-characters-stats")
	await _shot("%02d-archive-characters-stats" % index)
	index += 1
	_main_scene._archive_select("group","weapons")
	_main_scene._archive_select("page",1)
	await _frames(3)
	_report_text(_main_scene.view,"archive-weapon-growth")
	await _shot("%02d-archive-weapon-growth" % index)
	_main_scene.go("lobby")
	await _frames(3)
	_check("Back to lobby",_main_scene.screen == "lobby")
	_check("No save writes",not Profile.writable)
	print("OFFICE_SCREENS_CAPTURE %s; failed %d" % [_output,_failed])
	get_tree().quit(0 if _failed == 0 else 1)
