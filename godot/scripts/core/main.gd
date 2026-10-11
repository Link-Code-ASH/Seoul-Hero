extends Node

var screen := "lobby"
var view: Control
var canvas := CanvasLayer.new()
var world := HeroWorld.new()
var movement := HeroMovement.new()
var guild_ui := {"panel":"facility","slot":0,"employee":"","expedition":"cityScout","selectedStaff":[]}
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
var ui_fx := HeroUIEffects.new()
var _mounted_ui_key := ""
var _support_action_active := false
var _recovery_clock := 0.0
var _daily_prompted_day := -1
var _association_result_pending := false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	add_child(world); add_child(canvas)
	canvas.add_child(movement)
	canvas.add_child(ui_fx)
	draft.weekly = Profile.meta.weeklyGate.ruleId
	Sound.music("menu"); Sound.prime()
	_lobby_scene = str(Content.data.premiumUI.scenes.pick_random())
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
	canvas.move_child(ui_fx,canvas.get_child_count()-1)
	canvas.move_child(movement,canvas.get_child_count()-1)
	var key := screen + (":%d" % gate_step if screen == "gate" else ":"+run.phase if screen == "combat" and run != null else "")
	ui_fx.bind_view(view,key,key != _mounted_ui_key)
	_mounted_ui_key = key
	movement.reset()

func _refresh() -> void:
	if _redraw_pending: return
	_redraw_pending = true
	_render.call_deferred()

func _render() -> void:
	_redraw_pending = false
	world.visible = screen == "combat" and run != null
	movement.active = screen == "combat" and run != null and run.phase == "waveActive"
	match screen:
		"title": _mount(HeroMetaScreens.title(func(): go("lobby"),_resume_saved,FileAccess.file_exists(Profile.CHECKPOINT_PATH)))
		"lobby":
			_mount(HeroLobbyScreen.build(go,_lobby_scene,FileAccess.file_exists(Profile.CHECKPOINT_PATH)))
			Sound.ambience(str(view.get_meta("lobbyAmbience", "")))
			_offer_daily()
		"gate": _mount(HeroGateScreen.build(draft,gate_step,_gate_change,_gate_navigate,_deploy,gate_ui))
		"growth","association","offline","supply","settings": _mount(HeroMetaScreens.build(screen,growth,go,_meta_action))
		"archive": _mount(HeroArchive.build(archive,func(): go("lobby"),_archive_select))
		"guild":
			var headquarters := HeroGuildOfficeScreen.create(Profile.meta,Profile.guild_action,func(): go("lobby"),func(): go("gate"),_guild_art(),guild_ui)
			headquarters.read_only = not Profile.writable
			_mount(headquarters)
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
				"revivalChoice":
					if Content.enabled("revivalStones"): _mount(HeroCombatUI.revival(run,_revive,_die))
					else: _die.call_deferred()
				"stageClear","gameOver":
					_mount(HeroCombatUI.result(run,func(): go("lobby")))
			Profile.save_run(run)

func go(destination: String) -> void:
	_association_result_pending = false
	if destination == "resume": _resume_saved(); return
	if destination != "lobby": Sound.ambience("")
	if screen == "combat" and destination != "combat": Sound.stop_combat()
	if destination != "combat": Sound.set_paused(false)
	if destination == "lobby" and (screen != "lobby" or _lobby_scene.is_empty()):
		_lobby_scene = str(Content.data.premiumUI.scenes.pick_random())
	if screen == "guild" and destination != "guild": Profile.save()
	if destination != "combat":
		if run != null and run.settled: run = null; simulation = null; world.run = null
		Sound.music("guild" if destination == "guild" else "menu")
	var feature_of := {"guild":"guild","offline":"offlineReward","supply":"supplyBox","growth":"fragments"}
	if feature_of.has(destination) and not Content.enabled(feature_of[destination]): destination = "lobby"
	screen = destination
	if destination == "gate":
		HeroMeta.weekly(Content.data,Profile.meta,Time.get_unix_time_from_system())
		draft.weekly = Profile.meta.weeklyGate.ruleId
		draft.week = int(Profile.meta.weeklyGate.weekKey)
		gate_step = 0
	if destination == "guild":
		HeroGuildClock.advance(Content.data,Profile.meta,Time.get_unix_time_from_system())
		Profile.save()
	if destination == "offline": Profile.save()
	_refresh()

func _guild_art() -> Dictionary:
	var visuals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visuals/guild.json"))
	return {"rooms":Content.texture(visuals.rooms.file),"states":Content.texture(visuals.states.file),"facilityOrder":visuals.rooms.facility_order,"tiers":visuals.rooms.tiers,"structure":Content.texture(visuals.walk.file),"structureRegions":visuals.walk.regions}

func _gate_change(key: String, value) -> void:
	if key == "uiInspect":
		if str(gate_ui.inspected.get(value.kind,"")) != str(value.id): ui_fx.queue_effect("detail",{"anchor":"GateDetailArt"})
		gate_ui.inspected[value.kind] = value.id
		_refresh(); return
	if key in ["character","weapon","blessing"] and draft.get(key) != value:
		ui_fx.queue_effect("select",{"anchor":"GateChoice_"+str(value)})
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
	if Content.enabled("guild"): HeroGuildClock.advance(Content.data,Profile.meta,Time.get_unix_time_from_system())
	draft.blessingLevel = HeroMeta.blessing_level(Content.data,Profile.meta.blessings.get(draft.blessing,{}))
	Profile.save()
	_start_run(HeroRun.new(Content.data,draft,Profile.meta))

func _resume_saved() -> void:
	var saved := Profile.restore_run()
	if saved == null: go("lobby"); return
	_start_run(saved)

func _start_run(state: HeroRun) -> void:
	draft.character = state.setup.character
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
	# Gameplay subscribers retain the original events; semantic audio emits once.
	if _weapon_audio_events.has(id) or id in ["enemyHit","critical","enemyKilled","playerHit","magicStoneCollected","purchase","weaponPurchase"]: return
	if id in ["stageClear", "gameOver"]: Sound.music("")
	Sound.cue(id)

func _run_visual_audio(payload: Dictionary) -> void:
	if payload.get("kind", "") == "cleanup": Sound.stop_combat()

func _run_phase_changed() -> void:
	Sound.set_paused(run.phase == "paused")
	if run.phase in ["stageClear","gameOver"]:
		if not run.settled:
			HeroMeta.settle(Content.data,Profile.meta,run,"clear" if run.phase == "stageClear" else "death")
			Profile.record_analytics(run)
			if Profile.save(): Profile.clear_run()
		Sound.stop_combat(); Sound.music("")
		ui_fx.queue_effect("result" if run.phase == "stageClear" else "calm",{"anchor":"ResultRewardArt","view_key":"combat:"+run.phase})
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
	HeroMeta.settle(Content.data,Profile.meta,run,"abandon")
	Profile.record_analytics(run)
	if Profile.save(): Profile.clear_run()
	go("lobby")

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
	if key == "id" and archive.id != value:
		ui_fx.queue_effect("select",{"anchor":"Archive_"+str(value)})
		ui_fx.queue_effect("detail",{"anchor":"ArchiveDetailArt"})
	archive[key] = value
	if key == "group": archive.id = Content.data[value].keys()[0]; archive.scroll = 0
	if key in ["group","id","map"]: archive.page = 0; archive.growthPage = 0
	if key == "page": archive.growthPage = 0
	_refresh()

# Shows today's gift once per day per session; claiming saves before the rewards appear.
func _offer_daily() -> void:
	if not Profile.writable: return
	var now := Time.get_unix_time_from_system()
	var today := HeroMeta.day_key(Content.data,now)
	if _daily_prompted_day == today or not HeroMeta.daily_available(Content.data,Profile.meta,now): return
	_daily_prompted_day = today
	var offer := HeroMeta.daily_offer(Content.data,Profile.meta,now)
	var daily: Dictionary = Profile.meta.daily
	var streak_day := int(daily.get("streak",0)) + 1 if int(daily.get("claimedDayKey",-1)) == today - 1 else 1
	HeroLobbyScreen.daily_popup(view,offer,streak_day,int(Content.data.daily.streakDays),func():
		var before := Profile.meta.duplicate(true)
		var rewards := HeroMeta.claim_daily(Content.data,Profile.meta,Time.get_unix_time_from_system())
		if rewards.is_empty() or not Profile.save():
			Profile.meta = before
			return
		Sound.cue("purchase")
		# Redraw the lobby wallet first, then open the results on the new view.
		_refresh()
		_show_daily_rewards.call_deferred(rewards)
	)

func _show_draw(kind: String, id: String) -> void:
	if screen == "association" and is_instance_valid(view): HeroAssociationFeedback.draw(view,kind,id)

func _show_association_result(result: Dictionary) -> void:
	_association_result_pending = false
	if screen != "association" or not is_instance_valid(view): return
	if result.action == "associationDraw": _show_draw(str(result.kind),str(result.id))
	else: HeroAssociationFeedback.play(view,result.payload)

# A transaction commits once before any visual feedback. The capture uses a memory-only
# commit callback to exercise the same success/rollback path without touching user files.
func _association_transaction(action: String, value: Variant, commit: Callable) -> Dictionary:
	if not commit.is_valid(): return {}
	var before := Profile.meta.duplicate(true)
	var result: Dictionary = {"action":action}
	if action == "associationDraw":
		var id := HeroMeta.draw(Content.data,Profile.meta,str(value))
		if id.is_empty(): return {}
		result["kind"] = str(value)
		result["id"] = id
	elif action == "associationBuy":
		var id := str(value)
		if not Content.data.upgrades.has(id): return {}
		var upgrade: Dictionary = Content.data.upgrades[id]
		var old_level := int(before.association.upgrades.get(id,0))
		if not HeroMeta.buy_association(Content.data,Profile.meta,id): return {}
		var new_level := int(Profile.meta.association.upgrades.get(id,0))
		var is_stat: bool = str(upgrade.effect.type) == "stat"
		var suffix := ""
		if is_stat:
			if upgrade.effect.operation == "multiply": suffix = "%"
			elif upgrade.effect.stat in HeroArchive.MULTIPLIERS or upgrade.effect.stat in HeroArchive.PROBABILITIES: suffix = "%p"
		result["payload"] = {"id":id,"name":str(upgrade.name),"type":str(upgrade.effect.type),
			"old_level":old_level,"new_level":new_level,"bonus_suffix":suffix,
			"old_bonus":HeroMeta.association_bonus(upgrade,old_level) if is_stat else 0.0,
			"new_bonus":HeroMeta.association_bonus(upgrade,new_level) if is_stat else 0.0}
		if not is_stat and str(upgrade.effect.get("target","")) in ["character","weapon","blessing"]:
			result.payload["reward_kind"] = str(upgrade.effect.target)
			result.payload["content_id"] = str(upgrade.effect.contentId)
	else: return {}
	if not bool(commit.call()):
		Profile.meta = before
		return {}
	return result

func _show_daily_rewards(rewards: Array) -> void:
	if screen == "lobby" and is_instance_valid(view): HeroMetaScreens.rewards_popup(view,rewards,"오늘의 선물")

func _meta_action(action: String, value) -> Variant:
	if not Profile.writable and action in ["grow","associationBuy","associationDraw","claimOffline","supplyOpen","offlineAdvance","devTickets"]: return null
	if action in ["associationBuy","associationDraw"]:
		if screen != "association" or _redraw_pending or _association_result_pending or not is_instance_valid(view) or HeroAssociationFeedback.is_busy(view): return null
		var result := _association_transaction(action,value,Profile.save)
		if result.is_empty(): return null
		_association_result_pending = true
		_refresh()
		_show_association_result.call_deferred(result)
		return null
	if action == "associationSelect" and (_association_result_pending or (is_instance_valid(view) and HeroAssociationFeedback.is_busy(view))): return null
	match action:
		"growthTab":
			growth.kind = value; growth.id = Content.data[{"character":"characters","weapon":"weapons","blessing":"blessings"}[value]].keys()[0]
		"growthSelect":
			if growth.id != value: ui_fx.queue_effect("detail",{"anchor":"GrowthArt"})
			growth.id = value
		"grow":
			var payload := {"anchor":"GrowthArt","content_id":str(value),"kind":str(growth.kind)}
			if HeroMeta.grow(Content.data,Profile.meta,growth.kind,value):
				ui_fx.queue_effect("growth",payload); Sound.cue("purchase")
		"associationSelect": growth["associationId"] = str(value)
		"claimOffline":
			if screen != "offline" or _support_action_active or _support_view_busy(): return {}
			_support_action_active = true
			HeroMeta.accrue_offline(Content.data,Profile.meta,Time.get_unix_time_from_system())
			var before := Profile.meta.duplicate(true)
			var claimed: Dictionary = Profile.meta.offlineReward.pendingRewards.duplicate(true)
			var received := HeroMeta.claim_offline(Content.data,Profile.meta)
			Profile.meta.offlineReward.lastClaimedAt = Time.get_datetime_string_from_system(true)
			if not Profile.save():
				Profile.meta = before
				received = false
			_support_action_active = false
			if received: Sound.cue("purchase")
			return claimed if received else {}
		"offlineAdvance":
			if not Profile.meta.settings.developerMode: return null
			Profile.meta.offlineReward.lastAccruedAt -= float(value)
			HeroMeta.accrue_offline(Content.data,Profile.meta,Time.get_unix_time_from_system())
		"supplyOpen":
			if screen != "supply" or _support_action_active or _support_view_busy(): return []
			_support_action_active = true
			var before := Profile.meta.duplicate(true)
			var results := HeroMeta.open_supply(Content.data,Profile.meta,int(value))
			if not Profile.save():
				Profile.meta = before
				results.clear()
			_support_action_active = false
			return results
		"devTickets": if Profile.meta.settings.developerMode: Profile.meta.wallet.supplyTickets += int(value)
		"volume": Profile.meta.settings[value.key] = value.value; Sound.apply_settings(); Profile.save(); return null
		"developer": Profile.meta.settings.developerMode = value
		"graphics": go("graphics"); return null
		"sd-sample": go("sd-sample"); return null
		"backup":
			var backup := FileAccess.open("user://export-%d.json" % Time.get_unix_time_from_system(),FileAccess.WRITE)
			if backup: backup.store_string(JSON.stringify({"formatVersion":Profile.FORMAT_VERSION,"meta":Profile.meta},"\t"))
			return null
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
			return null
	Profile.save(); _refresh()
	return null

func _support_view_busy() -> bool:
	return is_instance_valid(view) and view.has_method("is_busy") and bool(view.call("is_busy"))

func _back() -> void:
	if screen == "association" and is_instance_valid(view) and HeroAssociationFeedback.close_or_reveal(view): return
	if is_instance_valid(view):
		var modal := view.find_child("EconomyModal",true,false)
		if modal:
			modal.queue_free()
			return
	if screen == "guild" and view is HeroGuildOfficeScreen and view.close_management(): return
	if screen == "combat" and run != null:
		if run.phase == "paused": run.resume()
		elif run.phase in ["waveActive","shop","revivalChoice"]: _pause()
		elif run.settled: go("lobby")
	elif screen == "gate": _gate_navigate(-1)
	elif screen in ["graphics","sd-sample"]: go("settings")
	elif screen != "title": go("lobby")

func _process(_dt: float) -> void:
	if run != null and run.phase == "waveActive": HeroTelemetry.fps(run,Engine.get_frames_per_second())
	_recovery_clock += _dt
	if _recovery_clock >= 30.0:
		_recovery_clock = 0.0
		if Profile.save() and run != null and run.settled: Profile.clear_run()
		if screen == "offline" and not _support_view_busy(): _refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed: Sound.prime()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: _back(); get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if not is_node_ready(): return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		ui_fx.suspend(true)
		if run != null and screen == "combat": _pause(); Profile.save_run(run)
		Profile.save()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		ui_fx.suspend(false)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST: _back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if run != null: _pause(); Profile.save_run(run)
		Profile.save(); Sound.shutdown()
		get_tree().create_timer(0.08).timeout.connect(get_tree().quit)
