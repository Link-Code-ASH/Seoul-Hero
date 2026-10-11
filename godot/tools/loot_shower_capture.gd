extends Node

# Frame captures of the menu-side loot rain. In-memory fixtures only; no saves.
var _output := "res://exports/loot-shower"
var _view: Control
var _canvas := CanvasLayer.new()
var _original_meta: Dictionary

func _ready() -> void:
	_capture.call_deferred()

func _capture() -> void:
	await get_tree().process_frame
	if Profile.writable:
		push_error("Loot shower capture requires --ui-preview; save writes must be blocked.")
		get_tree().quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
	DisplayServer.window_set_size(Vector2i(915,412))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	_original_meta = Profile.meta
	Profile.meta = Content.data.defaultMeta.duplicate(true)
	HeroMeta.initialize(Content.data,Profile.meta)
	Profile.meta.settings.developerMode = false
	Profile.meta.wallet.supplyTickets = 12
	add_child(_canvas)
	# 1. Guild claim popup (same popup as daily gift and expedition returns).
	var root := HeroImageSkin.root()
	HeroMetaScreens._image_backdrop(root,"metaAssociationOffice")
	HeroImageSkin.header(root,"길드 본부",Callable())
	_canvas.add_child(root); _view = root
	await get_tree().process_frame
	var keys: Array = HeroGuildState.RESOURCES.slice(0,4)
	var rewards: Array = []
	for index in keys.size(): rewards.append({"type":"guildResource","contentId":keys[index],"amount":[120,36,8,3][index]})
	rewards.append({"type":"characterFragment","contentId":Content.data.characters.keys()[0],"amount":5})
	rewards.append({"type":"weaponFragment","contentId":Content.data.weapons.keys()[0],"amount":2})
	rewards.append({"type":"revivalStone","contentId":"low","amount":1})
	HeroMetaScreens.rewards_popup(root,rewards,"길드 보상 수령")
	var shower := _find_shower(root)
	if shower == null: push_error("Loot shower missing from rewards popup")
	else: shower.capture_clock = true
	await _frames(shower,"popup",[0.12,0.3,0.55,0.8,1.05,1.6])
	_view.queue_free()
	# 2. Supply box, 10 openings.
	_view = HeroMetaScreens.build("supply",{},func(_d): pass,_fixture_action)
	_view.set("capture_clock",true)
	_canvas.add_child(_view)
	for frame in range(3): await get_tree().process_frame
	(_view.find_child("SupplyOpen10",true,false) as Button).pressed.emit()
	var elapsed := 0.0
	var marks := [0.9,1.2,1.45,1.7,2.0,2.6]
	var mark := 0
	while mark < marks.size():
		_view.call("advance_for_capture",1.0/60.0)
		elapsed += 1.0/60.0
		await get_tree().process_frame
		if elapsed >= marks[mark]:
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_output.path_join("supply-%d.png" % mark))
			mark += 1
	_view.queue_free()
	Profile.meta = _original_meta
	print("LOOT_SHOWER_CAPTURE ",ProjectSettings.globalize_path(_output))
	get_tree().quit()

func _frames(shower: HeroLootShower, prefix: String, marks: Array) -> void:
	var elapsed := 0.0
	var mark := 0
	while mark < marks.size():
		if is_instance_valid(shower): shower.advance(1.0/60.0)
		elapsed += 1.0/60.0
		await get_tree().process_frame
		if elapsed >= marks[mark]:
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_output.path_join("%s-%d.png" % [prefix,mark]))
			mark += 1

func _find_shower(node: Node) -> HeroLootShower:
	if node is HeroLootShower: return node
	for child in node.get_children():
		var found := _find_shower(child)
		if found != null: return found
	return null

func _fixture_action(action: String, value) -> Variant:
	if action != "supplyOpen": return null
	Profile.meta.wallet.supplyTickets -= int(value)
	return [{"type":"associationCoin","contentId":"","amount":240},{"type":"revivalStone","contentId":"low","amount":3},{"type":"revivalStone","contentId":"mid","amount":1},{"type":"characterFragment","contentId":Content.data.characters.keys()[0],"amount":2},{"type":"weaponFragment","contentId":Content.data.weapons.keys()[0],"amount":3}]
