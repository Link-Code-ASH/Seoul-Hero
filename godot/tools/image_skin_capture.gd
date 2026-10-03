extends Node

# Production UI capture only. The profile write guard is mandatory; no gameplay
# simulation, growth operations or checkpoint writes are executed.
# Shop/slider probes use isolated in-memory runs and the native UI callbacks.
var _output := "res://exports/ui-feedback-runtime"
var _records: Array = []
var _checks: Array = []
var _world: HeroWorld
var _canvas := CanvasLayer.new()
var _original_profile: Dictionary

func _ready() -> void:
	_capture_all.call_deferred()

func _capture_all() -> void:
	await get_tree().process_frame
	if Profile.writable:
		push_error("Runtime UI capture requires --ui-preview to block save writes.")
		get_tree().quit(1); return
	DisplayServer.window_set_size(Vector2i(915,412))
	for frame in range(3): await get_tree().process_frame
	var hud_only := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): _output = argument.trim_prefix("--output=")
		if argument == "--hud-only": hud_only = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	_original_profile = Profile.meta
	Profile.meta = Content.data.defaultMeta.duplicate(true)
	HeroMeta.initialize(Content.data,Profile.meta)
	HeroMeta.weekly(Content.data,Profile.meta,Time.get_unix_time_from_system())
	Profile.meta.wallet.associationCoins = 12480; Profile.meta.wallet.supplyTickets = 12
	Profile.meta.settings = Content.data.defaultMeta.settings.duplicate(true)
	for group in ["characters","sharedWeapons","blessings"]:
		for id in Profile.meta[group]:
			Profile.meta[group][id].unlocked = true
			Profile.meta[group][id].fragments = 120
	Profile.meta.gateProgression.highestUnlockedDepth = 12
	Profile.meta.gateProgression.characters.awakener = {"highestClearedDepth":5,"bestWaveByDepth":{"6":13}}
	_world = HeroWorld.new(); add_child(_world); _world.visible = false
	add_child(_canvas)
	var noop := func(_value = null,_other = null): pass
	var setup := {"map":"seoul","depth":6,"character":"awakener","weapon":"manaBolt","blessing":"","weekly":Profile.meta.weeklyGate.ruleId}
	var run := HeroRun.new(Content.data.duplicate(true),setup,Profile.meta)
	_frozen_combat(run)
	if hud_only:
		await _capture(HeroCombatUI.hud(run,noop),"01-hud",run)
		run.phase = "waveActive"; run.wave = 7; run.elapsed = run.wave_data().duration-4
		run.player.hp = run.stats.maxHp*0.17; run.currency = 987654; run.wallet = 12480
		await _capture(HeroCombatUI.hud(run,noop),"qa-hud-low-large",run)
		run.phase = "postWave"; run.post_elapsed = 0.40; run.wallet_flights = run.pickups.duplicate(true)
		await _capture(HeroCombatUI.hud(run,noop),"qa-hud-post-wave-wallet",run)
		for factor in [1,2]:
			DisplayServer.window_set_size(Vector2i(915,412)*factor)
			for frame in range(3): await get_tree().process_frame
			for percent in [0,50,100]:
				run.phase = "waveActive"; run.player.hp = run.stats.maxHp*percent/100.0
				await _capture(HeroCombatUI.hud(run,noop),"qa-hp-%d-%dx" % [percent,factor],run)
		DisplayServer.window_set_size(Vector2i(915,412))
		for frame in range(3): await get_tree().process_frame
		await _hud_live_check(run,noop)
		var hud_file := FileAccess.open(_output.path_join("hud-layout.json"),FileAccess.WRITE)
		hud_file.store_string(JSON.stringify({"size":[915,412],"saveWrites":false,"simulation":false,"productionClasses":true,"screenRecords":_records,"checks":_checks},"\t"))
		Profile.meta = _original_profile
		print("Production HUD captures: ",ProjectSettings.globalize_path(_output),"; Profile.writable=",Profile.writable)
		get_tree().quit()
		return
	await _capture(HeroCombatUI.hud(run,noop),"01-hud",run)
	await _capture(HeroGateScreen.build(setup,0,noop,noop,noop,{}),"02-map")
	await _capture(HeroGateScreen.build(setup,1,noop,noop,noop,{}),"03-depth")
	await _capture(HeroGateScreen.build(setup,2,noop,noop,noop,{}),"04-character")
	await _capture(HeroGateScreen.build(setup,3,noop,noop,noop,{}),"05-weapon")
	var blessing_id: String = Content.data.blessings.keys()[0]
	setup.blessing = blessing_id
	Profile.meta.blessings[blessing_id].level = 2
	await _capture(HeroGateScreen.build(setup,4,noop,noop,noop,{}),"06-blessing")
	await _capture(HeroGateScreen.build(setup,5,noop,noop,noop,{}),"07-formation")
	await _selection_visual_checks(setup,noop)
	await _capture(HeroMetaScreens.build("growth",{"kind":"character","id":"awakener"},noop,noop),"08-growth")
	await _capture(HeroArchive.build(_archive_view("items","vaultLedger"),noop,noop),"09-archive")
	await _capture(HeroMetaScreens.build("settings",{},noop,noop),"10-settings")
	run.phase = "paused"
	await _capture(HeroCombatUI.pause_menu(run,noop,noop),"11-pause",run)
	# Approved screens are captured separately to show unchanged production art.
	var continuing_title := HeroMetaScreens.title(noop,noop,true)
	_title_actions_check(continuing_title,true)
	await _capture(continuing_title,"approved-title")
	var starting_title := HeroMetaScreens.title(noop,noop,false)
	_title_actions_check(starting_title,false)
	await _capture(starting_title,"qa-title-no-run")
	await _capture(HeroLobbyScreen.build(noop,"premiumLobbyRain"),"approved-lobby")
	run.phase = "shop"; run.wave = 12; run.currency = 60; run.wallet = 240
	run.items.phoenixMatch = 1; run.item_stock = []
	for id in ["phoenixMatch","vaultLedger","revengeFuse","ankleGuard"]:
		run.item_stock.append({"id":id,"locked":id == "vaultLedger"})
	await _capture(HeroShopScreen.build(run,false,noop,noop,noop,noop),"approved-shop")
	run.weapon_stock.clear()
	for slot in run.owned.slice(0,4):
		run.weapon_stock.append({"id":slot.id,"level":int(slot.level)+1,"locked":slot.id == "guardianDaggers"})
	await _capture(HeroShopScreen.build(run,true,noop,noop,noop,noop),"qa-shop-weapons")
	run.currency = 0
	await _capture(HeroShopScreen.build(run,false,noop,noop,noop,noop),"qa-shop-disabled")
	run.currency = 987654321
	var previous_price: int = int(run.data.items.phoenixMatch.basePrice)
	run.data.items.phoenixMatch.basePrice = 98765432
	await _capture(HeroShopScreen.build(run,false,noop,noop,noop,noop),"qa-shop-eight-digit-price")
	run.data.items.phoenixMatch.basePrice = previous_price
	# Stress states use only temporary in-memory presentation fixtures.
	run.phase = "waveActive"; run.wave = 7; run.elapsed = run.wave_data().duration-4
	run.player.hp = run.stats.maxHp*0.17; run.currency = 987654; run.wallet = 12480
	await _capture(HeroCombatUI.hud(run,noop),"qa-hud-low-large",run)
	run.phase = "postWave"; run.post_elapsed = 0.40; run.wallet_flights = run.pickups.duplicate(true)
	await _capture(HeroCombatUI.hud(run,noop),"qa-hud-post-wave-wallet",run)
	run.phase = "waveActive"
	var locked_character: String = Content.data.characters.keys().back()
	Profile.meta.characters[locked_character].unlocked = false
	await _capture(HeroGateScreen.build(setup,2,noop,noop,noop,{"inspected":{"character":locked_character}}),"qa-character-locked")
	Profile.meta.characters[locked_character].unlocked = true
	Profile.meta.sharedWeapons.manaShotgun.unlocked = false
	await _capture(HeroGateScreen.build(setup,3,noop,noop,noop,{"inspected":{"weapon":"manaShotgun"}}),"qa-weapon-locked")
	Profile.meta.sharedWeapons.manaShotgun.unlocked = true
	Profile.meta.blessings[blessing_id].unlocked = false
	setup.blessing = ""
	await _capture(HeroGateScreen.build(setup,4,noop,noop,noop,{"inspected":{"blessing":blessing_id}}),"qa-blessing-locked")
	await _capture(HeroGateScreen.build(setup,4,noop,noop,noop,{}),"qa-blessing-none")
	for id in Profile.meta.blessings: Profile.meta.blessings[id].unlocked = false
	await _capture(HeroGateScreen.build(setup,4,noop,noop,noop,{}),"qa-blessing-unowned")
	for id in Profile.meta.blessings: Profile.meta.blessings[id].unlocked = true
	for pair in [["weapon","manaBolt"],["blessing",blessing_id]]:
		await _capture(HeroMetaScreens.build("growth",{"kind":pair[0],"id":pair[1]},noop,noop),"qa-growth-"+str(pair[0]))
	Profile.meta.characters.awakener.fragments = 0
	await _capture(HeroMetaScreens.build("growth",{"kind":"character","id":"awakener"},noop,noop),"qa-growth-insufficient")
	Profile.meta.characters.awakener.fragments = 120
	for group in HeroArchive.GROUPS:
		var id: String = Content.data[group].keys()[0]
		if group == "items": id = "phoenixMatch"
		if group == "enemies":
			for candidate in Content.data.enemies:
				if not Content.data.enemies[candidate].get("bossPatterns",[]).is_empty(): id = candidate; break
		var definition: Dictionary = Content.data[group][id]
		var tabs := HeroArchive.detail_tabs(group,definition)
		for page in range(tabs.size()):
			var view := _archive_view(group,id); view.page = page
			await _capture(HeroArchive.build(view,noop,noop),"qa-archive-%s-%d" % [group,page])
	await _hud_live_check(run,noop)
	await _gate_interaction_check(setup,noop)
	await _shop_interaction_checks(setup,noop)
	await _all_shop_copy_checks()
	await _bar_states(run,noop)
	var file := FileAccess.open(_output.path_join("layout.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"size":[915,412],"saveWrites":false,"simulation":false,"productionClasses":true,"screenRecords":_records,"checks":_checks},"\t"))
	Profile.meta = _original_profile
	print("Production feedback UI captures: ",ProjectSettings.globalize_path(_output),"; Profile.writable=",Profile.writable)
	get_tree().quit()

func _archive_view(group: String, id: String) -> Dictionary:
	return {"group":group,"id":id,"page":0,"growthPage":0,"map":"seoul","scroll":0}

func _frozen_combat(run: HeroRun) -> void:
	run.wave = 7; run.combat_time = 124; run.elapsed = run.wave_data().duration-28
	run.currency = 240; run.wallet = 36; run.player.hp = run.stats.maxHp*0.84
	run.player.pos = Vector2.ZERO
	run.owned.clear()
	var ids := ["manaSword","guardianDaggers","manaBolt","piercingShot","chainLightning","manaBombard"]
	for i in range(ids.size()):
		run.owned.append({"id":ids[i],"level":1+i%5,"cooldown":0.0,"branch":"A" if i%5 >= 2 else ""})
	var fixtures := [["crawler",Vector2(-.65,-.18)],["swarm",Vector2(-.40,-.28)],["runner",Vector2(.37,-.16)],
		["crawler",Vector2(.64,.06)],["swarm",Vector2(-.27,.32)],["crawler",Vector2(.21,.33)],
		["bulwark",Vector2(.53,.33)],["spitter",Vector2(.34,.21)],["crawler",Vector2(-.60,.21)],
		["swarm",Vector2(.78,-.24)],["runner",Vector2(-.35,.03)],["crawler",Vector2(.06,-.22)]]
	var half_arena := Vector2(float(run.map.arenaHeight)*915.0/412.0*.5,float(run.map.arenaHeight))
	for i in range(fixtures.size()):
		var definition: Dictionary = run.data.enemies[fixtures[i][0]]
		run.enemies.append({"id":i+1,"definition":definition.id,"pos":fixtures[i][1]*half_arena,
			"hp":definition.maxHp,"maxHp":definition.maxHp,"radius":definition.radius,"facing":-1.0 if i%2 else 1.0,"action":"move"})
	for point in [Vector2(-.31,.21),Vector2(.24,.13),Vector2(.60,.21),Vector2(-.14,.34),Vector2(-.72,.10)]:
		run.pickups.append({"pos":point*half_arena,"value":1.0})

func _capture(screen: Control, id: String, run: HeroRun = null) -> void:
	_world.visible = run != null
	if run != null: _world.run = run
	if screen.get_parent() == null: _canvas.add_child(screen)
	for frame in range(3): await get_tree().process_frame
	if run != null:
		var wallet_icon := screen.find_child("WalletIcon",true,false) as Control
		if wallet_icon: _world.wallet_target = wallet_icon.get_global_rect().get_center()
		if run.phase == "waveActive" and not run.enemies.is_empty():
			# Freeze real presentation effects at a readable instant; never tick gameplay.
			run.effect("slash",run.player.pos,75,-0.25,1.55)
			run.effect("impact",run.enemies[7].pos,22,0,1.0,Vector2.ZERO,{"targetActor":str(run.enemies[7].id)})
			for effect in _world._combat._playing: effect.tick(0.10)
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var capture_image := get_tree().root.get_texture().get_image()
	capture_image.save_png(_output.path_join(id+".png"))
	var texts: Array = []; var issues: Array = []
	_scan(screen,texts,issues)
	var tooltips: Array = []
	_collect_tooltips(screen,tooltips)
	_records.append({"screen":id,"pixelSize":[capture_image.get_width(),capture_image.get_height()],"labels":texts,"fitIssues":issues,"tooltips":tooltips})
	_checks.append({"check":id+" has no hover tooltips","passed":tooltips.is_empty()})
	if id.begins_with("qa-shop-") or id == "approved-shop": _shop_layout_check(screen,id)
	if id == "07-formation": _formation_layout_check(screen)
	_canvas.remove_child(screen); screen.free()

func _title_actions_check(screen: Control, has_run: bool) -> void:
	var primary := screen.find_child("TitleResume" if has_run else "TitleStart",true,false) as Button
	var secondary := screen.find_child("TitleNewRun",true,false) as Button
	var caption := "이어하기" if has_run else "시작하기"
	_checks.append({"check":"Title action uses "+caption,"passed":primary != null and primary.text == caption and primary.get_theme_font_size("font_size") == 19 and primary.size.y == 52})
	if has_run:
		_checks.append({"check":"Resume and new-run actions share type size and height","passed":primary != null and secondary != null and secondary.text == "새로하기" and secondary.get_theme_font_size("font_size") == primary.get_theme_font_size("font_size") and secondary.size.y == primary.size.y})
	else:
		_checks.append({"check":"No-run title shows only the start action","passed":primary != null and secondary == null and screen.find_child("TitleResume",true,false) == null})

func _hud_live_check(run: HeroRun, noop: Callable) -> void:
	var screen := HeroCombatUI.hud(run,noop)
	_canvas.add_child(screen)
	await get_tree().process_frame
	run.owned[0].level = 5
	HeroCombatUI.update_hud(screen,run)
	var level := screen.find_child("WeaponLevel0",true,false) as Label
	var wallet_icon := screen.find_child("WalletIcon",true,false) as Control
	var pause_button := screen.find_child("PauseButton",true,false) as Control
	_checks.append({"check":"HUD live level update","passed":level != null and level.text == "5"})
	_checks.append({"check":"Weapon level white 14px lower-right","passed":level != null and level.get_theme_font_size("font_size") == 14 and level.get_theme_color("font_color") == Color.WHITE and level.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT})
	var weapons := screen.find_child("HudWeapons",true,false) as Control
	_checks.append({"check":"Six owned weapon icons without empty plates","passed":weapons != null and weapons.get_child_count() == 12})
	_checks.append({"check":"Wallet flight target remains a visible HUD icon","passed":wallet_icon != null and wallet_icon.get_global_rect().has_area()})
	_checks.append({"check":"Pause touch target minimum 44","passed":pause_button != null and pause_button.size.x >= 44 and pause_button.size.y >= 44})
	var currency := screen.find_child("Currency",true,false) as Label
	var wallet := screen.find_child("Wallet",true,false) as Label
	var stone_icon := screen.find_child("StoneIcon",true,false) as Control
	var bar := screen.find_child("HealthBar",true,false) as ProgressBar
	var hp := screen.find_child("Health",true,false) as Label
	_checks.append({"check":"Currency and wallet share one compact 13px row above HP","passed":currency != null and wallet != null and bar != null and currency.position.x < wallet.position.x and is_equal_approx(currency.get_rect().get_center().y,wallet.get_rect().get_center().y) and currency.get_theme_font_size("font_size") == 13 and wallet.get_theme_font_size("font_size") == 13 and currency.get_rect().end.y < bar.position.y and wallet.get_rect().end.y < bar.position.y})
	_checks.append({"check":"Wallet icon is 12px and centered on the resource row","passed":wallet_icon != null and wallet != null and wallet_icon.size == Vector2(12,12) and is_equal_approx(wallet_icon.get_rect().get_center().y,wallet.get_rect().get_center().y)})
	var bar_display_size := bar.size*bar.scale if bar != null else Vector2.ZERO
	var resources_inside_hp_span := bar != null
	for resource in [stone_icon,currency,wallet_icon,wallet]:
		if resource == null or bar == null:
			resources_inside_hp_span = false
			continue
		var resource_rect: Rect2 = resource.get_global_rect()
		var bar_rect: Rect2 = bar.get_global_rect()
		resources_inside_hp_span = resources_inside_hp_span and resource_rect.position.x >= bar_rect.position.x and resource_rect.end.x <= bar_rect.end.x and resource_rect.end.y < bar_rect.position.y
	_checks.append({"check":"Both resource icons and full number rectangles sit above HP within its visual horizontal span","passed":resources_inside_hp_span})
	_checks.append({"check":"Stone icon is 12px and centered on the resource row","passed":stone_icon != null and currency != null and stone_icon.size == Vector2(12,12) and is_equal_approx(stone_icon.get_rect().get_center().y,currency.get_rect().get_center().y)})
	_checks.append({"check":"Compact resource groups retain 4px icon gaps and 5px between groups","passed":stone_icon != null and currency != null and wallet_icon != null and wallet != null and is_equal_approx(currency.position.x-stone_icon.get_rect().end.x,4.0) and is_equal_approx(wallet_icon.position.x-currency.get_rect().end.x,5.0) and is_equal_approx(wallet.position.x-wallet_icon.get_rect().end.x,4.0)})
	_checks.append({"check":"Prominent HP number remains separate from the resource row","passed":hp != null and stone_icon != null and bar != null and hp.get_theme_font_size("font_size") == 24 and hp.get_rect().end.x+2 <= stone_icon.position.x and hp.get_rect().end.y < bar.position.y})
	_checks.append({"check":"Six weapons stay below HP within its horizontal span","passed":weapons != null and bar != null and weapons.position.x == bar.position.x and weapons.position.x+weapons.size.x <= bar.position.x+bar_display_size.x and weapons.position.y >= bar.position.y+bar_display_size.y+8})
	_checks.append({"check":"HP native bar displays 180x10 with 4x raster and linear filter","passed":bar != null and bar.scale == Vector2(0.25,0.25) and bar_display_size == Vector2(180,10) and bar.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR})
	_canvas.remove_child(screen); screen.queue_free()

func _gate_interaction_check(source: Dictionary, noop: Callable) -> void:
	var draft := source.duplicate(true)
	var ui_state := {"inspected":{},"scroll":{"character":56}}
	var changes: Array = []
	var change := func(key: String, value):
		changes.append({"key":key,"value":value})
		if key == "uiInspect": ui_state.inspected[value.kind] = value.id
		elif not key.begins_with("ui"): draft[key] = value
	var screen := HeroGateScreen.build(draft,2,change,noop,noop,ui_state)
	var list := screen.find_child("GateSelectionScroll",true,false) as HeroImageSkin.DragScroll
	# Extra height exercises future roster scrolling with current real cards.
	# It is not rendered as a delivered screen and changes no content definitions.
	if list == null:
		_checks.append({"check":"Gate selection drag helper exists","passed":false})
		screen.free(); return
	(list.get_child(0) as Control).custom_minimum_size.y = 580
	_canvas.add_child(screen)
	for frame in range(3): await get_tree().process_frame
	var card := screen.find_child("GateChoice_awakener",true,false) as Button
	var point := list.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new(); touch.index = 7; touch.position = point; touch.pressed = true
	list._input(touch)
	var drag := InputEventScreenDrag.new(); drag.index = 7; drag.position = point-Vector2(0,60); drag.relative = Vector2(0,-60)
	list._input(drag)
	card.pressed.emit()
	touch.pressed = false; touch.position = drag.position; list._input(touch)
	card.pressed.emit()
	_checks.append({"check":"Touch drag and release suppress card selection","passed":changes.is_empty() and list.suppress_click})
	_checks.append({"check":"Touch drag advances vertical roster","passed":list.scroll_vertical > 56})
	var position_after_drag := list.scroll_vertical
	await get_tree().process_frame
	card.pressed.emit()
	_checks.append({"check":"Stationary click selects and updates inspected detail","passed":changes.size() == 2 and draft.character == "awakener" and ui_state.inspected.character == "awakener"})
	_canvas.remove_child(screen); screen.queue_free()
	screen = HeroGateScreen.build(draft,2,change,noop,noop,ui_state)
	list = screen.find_child("GateSelectionScroll",true,false) as HeroImageSkin.DragScroll
	(list.get_child(0) as Control).custom_minimum_size.y = 580
	_canvas.add_child(screen)
	for frame in range(3): await get_tree().process_frame
	_checks.append({"check":"Roster scroll position survives rebuild","passed":list.scroll_vertical == position_after_drag})
	changes.clear(); point = list.get_global_rect().get_center()
	var mouse := InputEventMouseButton.new(); mouse.button_index = MOUSE_BUTTON_LEFT; mouse.position = point; mouse.pressed = true
	list._input(mouse)
	var motion := InputEventMouseMotion.new(); motion.position = point-Vector2(0,48); motion.relative = Vector2(0,-48); motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	list._input(motion)
	card = screen.find_child("GateChoice_awakener",true,false) as Button
	card.pressed.emit(); mouse.pressed = false; mouse.position = motion.position; list._input(mouse)
	_checks.append({"check":"Mouse drag suppresses selection and scrolls","passed":changes.is_empty() and list.scroll_vertical > position_after_drag})
	await get_tree().process_frame
	var roster_wheel_moved: bool = await _native_wheel(list)
	_checks.append({"check":"Native mouse wheel scrolls roster","passed":roster_wheel_moved})
	var detail_column := screen.find_child("GateSelectionDetail",true,false) as VBoxContainer
	var detail_scroll := screen.find_child("GateDetailScroll",true,false) as ScrollContainer
	detail_scroll.scroll_vertical = 0
	await get_tree().process_frame
	var detail_has_overflow: bool = detail_column.get_combined_minimum_size().y > detail_scroll.size.y+1
	var detail_wheel_moved: bool = await _native_wheel(detail_scroll)
	_checks.append({"check":"Native mouse wheel scrolls right detail content from its top","passed":detail_has_overflow and detail_wheel_moved,"contentHeight":detail_column.get_combined_minimum_size().y,"viewportHeight":detail_scroll.size.y})
	changes.clear()
	card = screen.find_child("GateChoice_kangTaehoon",true,false) as Button
	card.pressed.emit()
	_checks.append({"check":"Selection click changes inspected and deployed character","passed":changes.size() == 2 and draft.character == "kangTaehoon" and ui_state.inspected.character == "kangTaehoon"})
	var selected_character: String = str(draft.character)
	_canvas.remove_child(screen); screen.queue_free()
	var locked_id: String = Content.data.characters.keys().back()
	Profile.meta.characters[locked_id].unlocked = false
	screen = HeroGateScreen.build(draft,2,change,noop,noop,ui_state)
	_canvas.add_child(screen); await get_tree().process_frame
	var refreshed_title := screen.find_child("GateDetailTitle",true,false) as Label
	_checks.append({"check":"Right detail updates after selected character click","passed":refreshed_title != null and refreshed_title.text == str(Content.data.characters[selected_character].name)})
	changes.clear()
	card = screen.find_child("GateChoice_"+locked_id,true,false) as Button
	card.pressed.emit()
	_checks.append({"check":"Locked card inspects without replacing deployed character","passed":changes.size() == 1 and changes[0].key == "uiInspect" and draft.character == selected_character and ui_state.inspected.character == locked_id})
	_canvas.remove_child(screen); screen.queue_free()
	screen = HeroGateScreen.build(draft,2,change,noop,noop,ui_state)
	_canvas.add_child(screen); await get_tree().process_frame
	var title := screen.find_child("GateDetailTitle",true,false) as Label
	_checks.append({"check":"Inspected locked character appears in right detail panel","passed":title != null and title.text == str(Content.data.characters[locked_id].name)})
	_canvas.remove_child(screen); screen.queue_free()
	Profile.meta.characters[locked_id].unlocked = true

func _native_wheel(scroll: ScrollContainer) -> bool:
	var previous := scroll.scroll_vertical
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed = true; wheel.factor = 1.0
	wheel.position = scroll.get_global_rect().get_center(); wheel.global_position = wheel.position
	# Route through native viewport GUI handling rather than assigning a scroll value.
	get_viewport().push_input(wheel)
	await get_tree().process_frame
	return scroll.scroll_vertical > previous

func _scan(node: Node, texts: Array, issues: Array, inside_scroll: bool = false) -> void:
	if (node is Label or node is Button) and node.is_visible_in_tree():
		var control := node as Control
		if not node.text.is_empty():
			var available := control.size
			if node is Button: available -= control.get_theme_stylebox("normal").get_minimum_size()
			var shaped := TextParagraph.new()
			shaped.break_flags = TextServer.BREAK_MANDATORY
			if node.autowrap_mode != TextServer.AUTOWRAP_OFF: shaped.break_flags |= TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
			var font_size := control.get_theme_font_size("font_size")
			shaped.add_string(node.text,control.get_theme_font("font"),font_size)
			shaped.width = available.x if node.autowrap_mode != TextServer.AUTOWRAP_OFF else -1
			var needed := shaped.get_size()
			needed.y += maxi(0,shaped.get_line_count()-1)*control.get_theme_constant("line_spacing")
			var entry := {"text":node.text,"size":font_size,"rect":[control.global_position.x,control.global_position.y,control.size.x,control.size.y],"needed":[needed.x,needed.y],"insideScroll":inside_scroll}
			texts.append(entry)
			if needed.x > available.x+1 or needed.y > available.y+1: issues.append(entry)
	for child in node.get_children(): _scan(child,texts,issues,inside_scroll or node is ScrollContainer)

func _collect_tooltips(node: Node, found: Array) -> void:
	if node is Control and not node.tooltip_text.is_empty(): found.append(node.tooltip_text)
	for child in node.get_children(true): _collect_tooltips(child,found)

func _contains_scroll(node: Node) -> bool:
	if node is ScrollContainer: return true
	for child in node.get_children():
		if _contains_scroll(child): return true
	return false

func _shop_layout_check(screen: Control, id: String) -> void:
	var products_without_scroll := true
	var touch_targets := true
	var top_corner_locks := true
	for index in range(4):
		var product := screen.find_child("ShopProduct_%d" % index,true,false) as Control
		var purchase := screen.find_child("ShopPurchase_%d" % index,true,false) as Button
		var lock := screen.find_child("ShopLock_%d" % index,true,false) as Button
		products_without_scroll = products_without_scroll and product != null and not _contains_scroll(product)
		touch_targets = touch_targets and purchase != null and lock != null and purchase.size.y >= 44 and lock.size.x >= 44 and lock.size.y >= 44
		top_corner_locks = top_corner_locks and lock != null and lock.position.y < 32
	_checks.append({"check":id+" has four products with no internal scroll","passed":products_without_scroll})
	_checks.append({"check":id+" purchase and lock targets remain 44px","passed":touch_targets})
	_checks.append({"check":id+" locks sit at product upper right","passed":top_corner_locks})

func _formation_layout_check(node: Node) -> void:
	if node is Label and node.has_meta("formation_content"):
		var allowed: Rect2 = node.get_meta("formation_content")
		var box := Rect2(node.position,node.size)
		var needed := _text_needed(node)
		_checks.append({"check":"Formation safe content: "+node.text,"passed":allowed.encloses(box) and needed.x <= box.size.x+1 and needed.y <= box.size.y+1})
	for child in node.get_children(): _formation_layout_check(child)

func _text_needed(label: Label) -> Vector2:
	var shaped := TextParagraph.new()
	shaped.break_flags = TextServer.BREAK_MANDATORY
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF: shaped.break_flags |= TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	shaped.add_string(label.text,label.get_theme_font("font"),label.get_theme_font_size("font_size"))
	shaped.width = label.size.x if label.autowrap_mode != TextServer.AUTOWRAP_OFF else -1
	var needed := shaped.get_size()
	needed.y += maxi(0,shaped.get_line_count()-1)*label.get_theme_constant("line_spacing")
	return needed

func _base_surface(node: Node) -> HeroImageSkin.ImageSurface:
	for child in node.get_children(true):
		if child is HeroImageSkin.ImageSurface: return child
	return null

func _selection_visual_checks(source: Dictionary, noop: Callable) -> void:
	for pair in [["character",2,"awakener","kangTaehoon"],["weapon",3,"manaBolt","manaSword"],["blessing",4,Content.data.blessings.keys()[0],""]]:
		var setup := source.duplicate(true)
		setup[pair[0]] = pair[3]
		var normal := HeroGateScreen.build(setup,int(pair[1]),noop,noop,noop,{})
		_canvas.add_child(normal)
		for frame in range(3): await get_tree().process_frame
		var card := normal.find_child("GateChoice_"+str(pair[2]),true,false) as Button
		var surface: HeroImageSkin.ImageSurface = _base_surface(card) if card != null else null
		var texture: Texture2D = surface.texture if surface != null else null
		var region: Rect2 = surface.region_rect if surface != null else Rect2()
		var bounds: Rect2 = surface.get_global_rect() if surface != null else Rect2()
		await _capture(normal,"qa-selection-"+str(pair[0])+"-before")
		setup[pair[0]] = pair[2]
		var selected := HeroGateScreen.build(setup,int(pair[1]),noop,noop,noop,{})
		_canvas.add_child(selected)
		for frame in range(3): await get_tree().process_frame
		card = selected.find_child("GateChoice_"+str(pair[2]),true,false) as Button
		surface = _base_surface(card) if card != null else null
		_checks.append({"check":str(pair[0])+" selection keeps the same Seoul background crop and geometry","passed":surface != null and surface.texture == texture and surface.region_rect == region and surface.get_global_rect() == bounds})
		await _capture(selected,"qa-selection-"+str(pair[0])+"-after")

func _shop_interaction_checks(setup: Dictionary, noop: Callable) -> void:
	var run := HeroRun.new(Content.data.duplicate(true),setup,Profile.meta)
	run.phase = "shop"; run.wave = 12; run.currency = 10000
	HeroShop.refresh(run,false)
	var refreshes: Array = []
	var refresh := func(): refreshes.append(true)
	var screen := HeroShopScreen.build(run,false,noop,refresh,noop,noop)
	_canvas.add_child(screen)
	await get_tree().process_frame
	var lock := screen.find_child("ShopLock_0",true,false) as Button
	var purchase := screen.find_child("ShopPurchase_0",true,false) as Button
	var id: String = str(run.item_stock[0].id)
	var before_money := run.currency
	if lock != null: lock.pressed.emit()
	_checks.append({"check":"Shop lock native callback toggles stock without charging","passed":lock != null and run.item_stock[0].locked and run.currency == before_money and refreshes.size() == 1})
	if purchase != null: purchase.pressed.emit()
	_checks.append({"check":"Locked item remains purchasable and purchase clears offer","passed":purchase != null and int(run.items.get(id,0)) == 1 and str(run.item_stock[0].id).is_empty() and not run.item_stock[0].locked and run.currency == before_money-float(run.data.items[id].basePrice) and refreshes.size() == 2})
	_canvas.remove_child(screen); screen.queue_free()
	HeroShop.refresh(run,false)
	run.item_stock[1].locked = true
	var retained_id: String = str(run.item_stock[1].id)
	var cost := HeroShop.reroll_cost(run,false)
	before_money = run.currency
	screen = HeroShopScreen.build(run,false,noop,refresh,noop,noop)
	_canvas.add_child(screen); await get_tree().process_frame
	var reroll := screen.find_child("ShopReroll",true,false) as Button
	if reroll != null: reroll.pressed.emit()
	_checks.append({"check":"Shop reroll native callback charges exact cost and preserves locked item","passed":reroll != null and run.item_rerolls == 1 and run.currency == before_money-cost and run.item_stock[1].id == retained_id and run.item_stock[1].locked})
	_canvas.remove_child(screen); screen.queue_free()
	run.currency = 0
	screen = HeroShopScreen.build(run,false,noop,refresh,noop,noop)
	_canvas.add_child(screen); await get_tree().process_frame
	var all_disabled := true
	for index in range(4):
		purchase = screen.find_child("ShopPurchase_%d" % index,true,false) as Button
		all_disabled = all_disabled and purchase != null and purchase.disabled
	_checks.append({"check":"Unaffordable offers disable native purchase controls","passed":all_disabled})
	_canvas.remove_child(screen); screen.queue_free()

func _bar_states(run: HeroRun, noop: Callable) -> void:
	# Remove queued interaction fixtures before emitting the viewport resize signal.
	await get_tree().process_frame
	var original_settings: Dictionary = Profile.meta.settings.duplicate(true)
	var volume_events: Array = []
	var volume := func(action: String, payload):
		if action != "volume": return
		Profile.meta.settings[payload.key] = payload.value
		Sound.apply_settings()
		volume_events.append(payload)
	for factor in [1,2]:
		DisplayServer.window_set_size(Vector2i(915,412)*factor)
		for frame in range(3): await get_tree().process_frame
		for percent in [0,50,100]:
			run.phase = "waveActive"; run.player.hp = run.stats.maxHp*percent/100.0
			await _capture(HeroCombatUI.hud(run,noop),"qa-hp-%d-%dx" % [percent,factor],run)
			var screen := HeroMetaScreens.build("settings",{},noop,volume)
			_canvas.add_child(screen)
			for frame in range(3): await get_tree().process_frame
			var events_before := volume_events.size()
			var sliders_match := true
			for key in ["masterVolume","musicVolume","combatVolume","uiVolume"]:
				var slider := screen.find_child("Volume_"+key,true,false) as HSlider
				if slider == null:
					sliders_match = false; continue
				slider.value = float(percent)
				sliders_match = sliders_match and is_equal_approx(slider.value,float(percent)) and is_equal_approx(float(Profile.meta.settings[key]),percent/100.0)
				var logical_size := slider.size*slider.scale
				sliders_match = sliders_match and logical_size.y >= 44
			var master_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
			var expected_db := linear_to_db(maxf(0.0001,percent/100.0))
			_checks.append({"check":"Native sliders %d%% at %dx update settings and audio buses immediately" % [percent,factor],"passed":sliders_match and volume_events.size() >= events_before+4 and is_equal_approx(master_db,expected_db)})
			await _capture(screen,"qa-volume-%d-%dx" % [percent,factor])
	DisplayServer.window_set_size(Vector2i(915,412))
	Profile.meta.settings = original_settings
	Sound.apply_settings()

func _all_shop_copy_checks() -> void:
	# Measure the full text, ignoring max_lines_visible, so a hidden third line
	# cannot pass a two-line card check. This uses the actual product labels.
	var noop := func(): pass
	for group in ["items","weapons"]:
		for id in Content.data[group]:
			var definition: Dictionary = Content.data[group][id]
			var copy: Dictionary = definition.get("shopCardText",{})
			var screen := HeroImageSkin.root()
			var model := {"empty":false,"name":str(definition.name),"summary":str(copy.get("summary","")),"note":str(copy.get("penalty","")),"warning":not str(copy.get("penalty","")).is_empty(),"icon":Content.weapon_icon(id) if group == "weapons" else Content.item_icon(id),"price":int(definition.get("basePrice",36)),"can_buy":true,"can_lock":true,"locked":false}
			HeroShopScreen.product(screen,Rect2(205,84,162,266),model,noop,noop,noop)
			_canvas.add_child(screen)
			await get_tree().process_frame
			var fit := copy.has("summary") and copy.has("penalty")
			var issues: Array = []
			for name in ["CardName","CardSummary","CardNote"]:
				var label := screen.find_child(name,true,false) as Label
				if label == null:
					fit = false; issues.append({"label":name,"missing":true}); continue
				var needed := _text_needed(label)
				var fits: bool = needed.x <= label.size.x+1 and needed.y <= label.size.y+1
				if name != "CardName": fits = fits and label.get_theme_font_size("font_size") == 13
				fit = fit and fits
				if not fits: issues.append({"label":name,"text":label.text,"needed":[needed.x,needed.y],"available":[label.size.x,label.size.y]})
			_checks.append({"check":"Shop full-copy fit "+group+"/"+str(id),"passed":fit,"issues":issues})
			_canvas.remove_child(screen); screen.free()
