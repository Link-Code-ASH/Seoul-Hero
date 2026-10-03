extends Node

var screen := "title"
var view: Control
var canvas := CanvasLayer.new()
var world := HeroWorld.new()
var movement := HeroMovement.new()
var guild: HeroGuild
var run: HeroRun
var simulation: HeroSimulation
var draft := {"map":"seoul","depth":1,"character":"awakener","weapon":"manaBolt","blessing":"","weekly":""}
var gate_ui := {"inspected":{},"scroll":{}}
var gate_step := 0
var shop_weapon := true
var growth := {"kind":"character","id":"awakener"}
var archive := {"group":"characters","id":"awakener","page":0,"growthPage":0,"map":"seoul","scroll":0}
var checkpoint_clock := 0.0
var _redraw_pending := false
var _lobby_scene := ""
var _weapon_audio_events: Dictionary = {}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	add_child(world); add_child(canvas)
	canvas.add_child(movement)
	draft.weekly = Profile.meta.weeklyGate.ruleId
	Sound.music("menu"); Sound.prime()
	_render()
	# Optional local developer shortcut, without modifying the saved profile.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--open="):
			var target := argument.trim_prefix("--open=")
			if target in ["lobby","gate","growth","association","offline","supply","settings","archive","guild","graphics","sd-sample"]: go(target)
			elif target in ["weapons","character","depth"]:
				go("gate"); gate_step = {"weapons":3,"character":2,"depth":1}[target]
			elif target == "combat": _deploy()

func _mount(control: Control) -> void:
	if is_instance_valid(view): canvas.remove_child(view); view.queue_free()
	view = control; canvas.add_child(view)
	canvas.move_child(movement,canvas.get_child_count()-1)
	movement.reset()

func _refresh() -> void:
	if _redraw_pending: return
	_redraw_pending = true
	_render.call_deferred()

func _render() -> void:
	_redraw_pending = false
	world.visible = screen == "combat" and run != null
	movement.active = (screen == "combat" and run != null and run.phase == "waveActive") or screen == "guild"
	if is_instance_valid(guild): guild.visible = screen == "guild"
	match screen:
		"title": _mount(HeroMetaScreens.title(func(): go("lobby"),_resume_saved,FileAccess.file_exists(Profile.CHECKPOINT_PATH)))
		"lobby":
			_mount(HeroLobbyScreen.build(go,_lobby_scene))
			Sound.ambience(str(view.get_meta("lobbyAmbience", "")))
		"gate": _mount(HeroGateScreen.build(draft,gate_step,_gate_change,_gate_navigate,_deploy,gate_ui))
		"growth","association","offline","supply","settings": _mount(HeroMetaScreens.build(screen,growth,go,_meta_action))
		"archive": _mount(HeroArchive.build(archive,func(): go("lobby"),_archive_select))
		"guild": _mount(guild.controls(func(): go("lobby")))
		"graphics":
			var preview := HeroGraphicsPreview.new()
			preview.back = func(): go("settings")
			_mount(preview)
		"sd-sample":
			var preview := HeroSDPreview.new()
			preview.back = func(): go("settings")
			_mount(preview)
		"combat":
			match run.phase:
				"waveActive","postWave": _mount(HeroCombatUI.hud(run,_pause))
				"shop": _mount(HeroCombatUI.shop(run,shop_weapon,_shop_tab,_shop_refresh,func(): simulation.next_wave(),_pause))
				"paused": _mount(HeroCombatUI.pause_menu(run,func(): run.resume(),_abandon))
				"revivalChoice": _mount(HeroCombatUI.revival(run,_revive,_die))
				"stageClear","gameOver":
					_mount(HeroCombatUI.result(run,func(): go("lobby")))
			Profile.save_run(run)

func go(destination: String) -> void:
	if destination != "lobby": Sound.ambience("")
	if screen == "combat" and destination != "combat": Sound.stop_combat()
	if destination != "combat": Sound.set_paused(false)
	if destination == "lobby" and (screen != "lobby" or _lobby_scene.is_empty()):
		_lobby_scene = str(Content.data.premiumUI.scenes.pick_random())
	if screen == "guild" and is_instance_valid(guild): remove_child(guild); guild.queue_free(); guild = null
	if destination != "combat":
		if run != null and run.settled: run = null; simulation = null; world.run = null
		Sound.music("guild" if destination == "guild" else "menu")
	screen = destination
	if destination == "gate":
		HeroMeta.weekly(Content.data,Profile.meta,Time.get_unix_time_from_system())
		draft.weekly = Profile.meta.weeklyGate.ruleId
		gate_step = 0
	if destination == "guild":
		guild = HeroGuild.new(); guild.movement = movement; add_child(guild)
		guild.enter_gate.connect(func(): go("gate"))
		guild.open_roster.connect(func(): archive.group = "characters"; archive.id = "awakener"; archive.page = 0; go("archive"))
		guild.facility_changed.connect(_refresh)
	_refresh()

func _gate_change(key: String, value) -> void:
	if key == "uiInspect":
		gate_ui.inspected[value.kind] = value.id
		_refresh(); return
	draft[key] = value
	if key in ["character","weapon","blessing"]: gate_ui.inspected[key] = value
	if key == "character":
		var weapon: Dictionary = Content.data.weapons[draft.weapon]
		if weapon.get("signatureOwnerId",value) != value: draft.weapon = "manaBolt"
		gate_ui.inspected["weapon"] = draft.weapon
	_refresh()

func _gate_navigate(step: int) -> void:
	var next := gate_step - 1 if step == -1 else step
	if next < 0: go("lobby"); return
	gate_step = clampi(next,0,5)
	_refresh()

func _valid_entry() -> bool:
	var data: Dictionary = Content.data
	if not data.maps.has(draft.map) or draft.map not in Profile.meta.account.unlockedMapIds: return false
	if draft.depth < 1 or draft.depth > Profile.meta.gateProgression.highestUnlockedDepth: return false
	if not data.characters.has(draft.character) or not Profile.meta.characters[draft.character].unlocked: return false
	if not data.weapons.has(draft.weapon) or not Profile.meta.sharedWeapons[draft.weapon].unlocked: return false
	var weapon: Dictionary = data.weapons[draft.weapon]
	if weapon.has("structure") or weapon.get("signatureOwnerId",draft.character) != draft.character: return false
	if not draft.blessing.is_empty() and (not data.blessings.has(draft.blessing) or not Profile.meta.blessings[draft.blessing].unlocked): return false
	return data.weeklyRules.has(draft.weekly)

func _deploy() -> void:
	if not _valid_entry(): return
	draft.blessingLevel = int(Profile.meta.blessings.get(draft.blessing,{}).get("level",0))
	_start_run(HeroRun.new(Content.data,draft,Profile.meta))

func _resume_saved() -> void:
	var saved := Profile.restore_run()
	if saved == null: go("lobby"); return
	_start_run(saved)

func _start_run(state: HeroRun) -> void:
	run = state; simulation = HeroSimulation.new(run); world.run = run
	_weapon_audio_events.clear()
	var weapon_stages: Dictionary = Content.data.get("audioConnections", {}).get("weaponStages", {})
	for stages: Dictionary in weapon_stages.values():
		for cue_id in stages.values():
			if cue_id is String and not cue_id.is_empty(): _weapon_audio_events[cue_id] = true
	run.event.connect(_legacy_run_sound)
	run.audio_event.connect(Sound.cue)
	run.visual_event.connect(_run_visual_audio)
	run.phase_changed.connect(_run_phase_changed)
	screen = "combat"; checkpoint_clock = 0
	Sound.ambience(""); Sound.stop_combat()
	Sound.set_paused(run.phase == "paused")
	Sound.music("combat"); Profile.save_run(run); _refresh()

func _legacy_run_sound(id: String) -> void:
	# Keep gameplay event subscribers intact while weapon audio uses stage payloads.
	if _weapon_audio_events.has(id): return
	if id in ["stageClear", "gameOver"]: Sound.music("")
	Sound.cue(id)

func _run_visual_audio(payload: Dictionary) -> void:
	if payload.get("kind", "") == "cleanup": Sound.stop_combat()

func _run_phase_changed() -> void:
	Sound.set_paused(run.phase == "paused")
	if run.phase in ["stageClear","gameOver"]:
		if not run.settled:
			HeroMeta.settle(Content.data,Profile.meta,run,run.phase == "stageClear")
			Profile.record_analytics(run)
			Profile.clear_run(); Profile.save()
		Sound.stop_combat(); Sound.music("")
	else: Profile.save_run(run)
	_refresh()

func _physics_process(dt: float) -> void:
	if screen != "combat" or run == null: return
	if run.phase == "waveActive": Sound.advance_combat(dt)
	simulation.tick(dt,movement.vector(),world.player_limits())
	if is_instance_valid(view) and run.phase in ["waveActive","postWave"]:
		HeroCombatUI.update_hud(view,run)
		var icon := view.find_child("WalletIcon",true,false) as Control
		if icon: world.wallet_target = icon.get_global_rect().get_center()
	checkpoint_clock += dt
	if checkpoint_clock >= 5.0:
		checkpoint_clock = 0; Profile.save_run(run)

func _pause() -> void:
	if run: movement.reset(); run.pause(); Profile.save_run(run)

func _abandon() -> void:
	if run == null: return
	run.phase = "gameOver"
	HeroMeta.settle(Content.data,Profile.meta,run,false)
	Profile.record_analytics(run)
	Profile.clear_run(); Profile.save(); go("lobby")

func _die() -> void:
	run.phase = "gameOver"; run.phase_changed.emit(); Sound.cue("gameOver")

func _revive(grade: String) -> void:
	if run.phase != "revivalChoice" or Profile.meta.wallet.revivalStones.get(grade,0) <= 0: return
	Profile.meta.wallet.revivalStones[grade] -= 1; Profile.save()
	run.player.hp = run.stats.maxHp * Content.data.revivalStones[grade].healthFraction
	run.player.invulnerability = 2.5; run.phase = "waveActive"; run.phase_changed.emit()
	Profile.save_run(run)
	Sound.cue("branchChoice")

func _shop_tab(weapon: bool) -> void: shop_weapon = weapon; _refresh()
func _shop_refresh() -> void: Profile.save_run(run); _refresh()

func _archive_select(key: String, value) -> void:
	archive[key] = value
	if key == "group": archive.id = Content.data[value].keys()[0]; archive.scroll = 0
	if key in ["group","id","map"]: archive.page = 0; archive.growthPage = 0
	if key == "page": archive.growthPage = 0
	_refresh()

func _meta_action(action: String, value) -> void:
	match action:
		"growthTab":
			growth.kind = value; growth.id = Content.data[{"character":"characters","weapon":"weapons","blessing":"blessings"}[value]].keys()[0]
		"growthSelect": growth.id = value
		"grow": HeroMeta.grow(Content.data,Profile.meta,growth.kind,value); Sound.cue("purchase")
		"associationBuy": HeroMeta.buy_association(Content.data,Profile.meta,value); Sound.cue("purchase")
		"claimOffline":
			HeroMeta.claim_offline(Profile.meta); Profile.meta.offlineReward.lastClaimedAt = Time.get_datetime_string_from_system(true)
			Profile.save(); Sound.cue("purchase"); return
		"offlineAdvance":
			Profile.meta.offlineReward.lastExitAt = Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) - int(value))
			HeroMeta.accrue_offline(Content.data,Profile.meta,Time.get_unix_time_from_system())
		"supplyOpen":
			var results := HeroMeta.open_supply(Content.data,Profile.meta,int(value))
			Profile.save()
			if not results.is_empty(): _opening(results)
			return
		"devTickets": if Profile.meta.settings.developerMode: Profile.meta.wallet.supplyTickets += int(value)
		"volume": Profile.meta.settings[value.key] = value.value; Sound.apply_settings(); Profile.save(); return
		"developer": Profile.meta.settings.developerMode = value
		"graphics": go("graphics"); return
		"sd-sample": go("sd-sample"); return
		"backup":
			var backup := FileAccess.open("user://export-%d.json" % Time.get_unix_time_from_system(),FileAccess.WRITE)
			if backup: backup.store_string(JSON.stringify({"formatVersion":1,"meta":Profile.meta},"\t"))
			return
		"import":
			var dialog := FileDialog.new()
			dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			dialog.access = FileDialog.ACCESS_FILESYSTEM
			dialog.filters = PackedStringArray(["*.json ; Seoul Hero Godot"])
			add_child(dialog)
			dialog.file_selected.connect(func(path):
				if Profile.import_backup(path): Sound.apply_settings(); _refresh()
				dialog.queue_free()
			)
			dialog.canceled.connect(dialog.queue_free)
			dialog.popup_centered_ratio(0.8)
			return
	Profile.save(); _refresh()

func _opening(results: Array) -> void:
	var box := HeroCombatUI.popup(view,"봉인 해제",650,300)
	var chest := HeroUI.image(box,Content.trimmed_texture("lobbySupplyVault"),300,124)
	chest.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var halo := HeroUI.image(box,Content.trimmed_texture("supplyOpeningBurst"),200,52)
	halo.modulate.a = 0
	Sound.cue("supplyLatch")
	var tween := chest.create_tween()
	tween.tween_property(chest,"modulate",Color(1.25,1.25,1.3),0.25)
	tween.tween_property(halo,"modulate:a",0.85,0.2)
	tween.tween_interval(0.4)
	tween.tween_callback(func():
		Sound.cue("supplyFanfare")
		if is_instance_valid(box): box.get_meta("overlay").queue_free()
		HeroMetaScreens.rewards_popup(view,results)
	)

func _back() -> void:
	if screen == "combat" and run != null:
		if run.phase == "paused": run.resume()
		elif run.phase in ["waveActive","shop","revivalChoice"]: _pause()
		elif run.settled: go("lobby")
	elif screen == "gate": _gate_navigate(-1)
	elif screen in ["graphics","sd-sample"]: go("settings")
	elif screen != "title": go("lobby")

func _process(_dt: float) -> void:
	if run != null and run.phase == "waveActive": HeroTelemetry.fps(run,Engine.get_frames_per_second())

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed: Sound.prime()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: _back(); get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E and screen == "guild" and is_instance_valid(guild): guild.interact()

func _notification(what: int) -> void:
	if not is_node_ready(): return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if run != null and screen == "combat": _pause(); Profile.save_run(run)
		Profile.save()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST: _back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if run != null: _pause(); Profile.save_run(run)
		Profile.save(); Sound.shutdown()
		get_tree().create_timer(0.08).timeout.connect(get_tree().quit)
