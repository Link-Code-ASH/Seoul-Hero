extends SceneTree

# Audio-only Dummy diagnostic. Both flags select a synthetic Profile before any
# player file is read; no main scene, saved state, music, or combat tick is run.
var sound: Variant
var profile: Variant
var content: Variant
var checks: Array = []
var errors: Array = []
var wavs: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _record(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name":name,"passed":passed,"detail":detail})
	if not passed: errors.append(name)

func _clear_voices() -> void:
	for voice in sound._voices: sound._stop_voice(voice)
	sound._voices.clear(); sound._last.clear()
	sound.stop_combat()

func _normal_count() -> int:
	var count := 0
	for voice in sound._voices:
		if not bool(voice.protected): count += 1
	return count

func _new_run() -> HeroRun:
	var meta: Dictionary = content.data.defaultMeta.duplicate(true)
	meta.guild = HeroGuildState.create(content.data,1000.0)
	HeroMeta.apply_starter(content.data,meta)
	HeroMeta.initialize(content.data,meta)
	return HeroRun.new(content.data,{"map":"seoul","depth":1,"character":"awakener","weapon":"manaBolt","blessing":"","weekly":meta.weeklyGate.ruleId},meta)

func _run() -> void:
	await process_frame
	sound = root.get_node("Sound"); profile = root.get_node("Profile"); content = root.get_node("Content")
	var guarded := "--ui-preview" in OS.get_cmdline_user_args() and "--audio-identity-check" in OS.get_cmdline_user_args()
	_record("synthetic_no_read_flags", guarded)
	_record("profile_writes_blocked", not profile.writable)
	if not guarded or profile.writable: _finish(); return
	_record("initial_audio_disabled", not sound._audible)
	for path in ["res://scripts/core/main.gd","res://scripts/state/run.gd","res://scripts/systems/attacks.gd","res://scripts/core/simulation.gd","res://scripts/systems/shop.gd","res://scripts/systems/enemy_brain.gd","res://scripts/ui/lobby_screen.gd"]:
		var script := load(path) as GDScript
		_record("compile_"+path.get_file(), script != null and script.can_instantiate())
	var invalid: Array = []
	for id in content.data.sfx:
		var definition: Dictionary = content.data.sfx[id]
		var urls: Array = definition.get("urls",[])
		if urls.size() != 1: invalid.append(str(id)+":not_one_source")
		for url in urls:
			var stream := load(str(url)) as AudioStreamWAV
			var valid := stream != null
			var fact := {"cue":id,"url":url,"loaded":valid,"sha256":FileAccess.get_sha256(str(url))}
			if valid:
				fact.merge({"rate":stream.mix_rate,"bits16":stream.format == AudioStreamWAV.FORMAT_16_BITS,"stereo":stream.stereo,"length":stream.get_length()})
				valid = stream.mix_rate == 48000 and stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.stereo == bool(definition.get("loop",false)) and stream.get_length() > 0
				sound._cache[url] = stream
			if not valid: invalid.append(url)
			wavs.append(fact)
	_record("fixed_single_wav_formats", invalid.is_empty(), {"count":wavs.size(),"invalid":invalid})
	var identities: Dictionary = content.data.audioConnections.get("identities",{})
	var absent: Array = []
	for monster_id in content.data.enemies:
		if not identities.get("monsterMaterials",{}).has(monster_id): absent.append("monster:"+str(monster_id))
	for weapon_id in content.data.weapons:
		if not identities.get("weaponHits",{}).has(weapon_id): absent.append("weapon:"+str(weapon_id))
	for item_id in content.data.items:
		if not identities.get("items",{}).has(item_id): absent.append("item:"+str(item_id))
	_record("content_identity_coverage", absent.is_empty(), absent)
	var bad_routes: Array = []
	for weapon_id in content.data.weapons:
		for monster_id in content.data.enemies:
			var hit: Dictionary = sound.describe_cue("enemyHit",{"weaponId":weapon_id,"monsterId":monster_id,"stage":"hit"})
			if (str(weapon_id) == "manaField" and not hit.is_empty()) or (str(weapon_id) != "manaField" and hit.is_empty()): bad_routes.append(str(weapon_id)+"/"+str(monster_id))
	for item_id in content.data.items:
		if sound.describe_cue("purchase",{"itemId":item_id}).is_empty(): bad_routes.append("item:"+str(item_id))
	_record("all_hit_and_item_routes", bad_routes.is_empty(), bad_routes)
	var baseline: Dictionary = sound.describe_cue("enemyHit",{"weaponId":"manaSword","monsterId":"crawler","stage":"hit"})
	var repeats: Array = []
	var repeat_ok := not baseline.is_empty()
	for index in range(10):
		sound.describe_cue("enemyHit",{"weaponId":"manaBolt","monsterId":"gatekeeper"})
		var fact: Dictionary = sound.describe_cue("critical" if index % 2 else "enemyHit",{"weaponId":"manaSword","monsterId":"crawler","stage":"hit","critical":index % 2 == 1,"attackId":index,"level":index+1,"pos":Vector2(index*100,-index*50)})
		repeats.append(fact); repeat_ok = repeat_ok and fact == baseline
	_record("ten_hits_interleaved_normal_critical_identical", repeat_ok, repeats)
	_record("weapon_and_material_distinguish", baseline != sound.describe_cue("enemyHit",{"weaponId":"manaBolt","monsterId":"crawler"}) and baseline != sound.describe_cue("enemyHit",{"weaponId":"manaSword","monsterId":"gatekeeper"}))
	_record("unknown_fixed_fallback", sound.describe_cue("enemyHit",{"weaponId":"unknown","monsterId":"unknown"}) == sound.describe_cue("enemyHit"))
	_record("sustained_field_silent", sound.describe_cue("enemyHit",{"weaponId":"manaField","monsterId":"crawler"}).is_empty())
	var acquisition_cases: Array = [
		{"id":"magicStoneCollected","context":{"pickupType":"magicStone"}},
		{"id":"magicStoneCollected","context":{"pickupType":"associationCoin"}},
		{"id":"magicStoneCollected","context":{"pickupType":"revivalStone","grade":"low"}},
		{"id":"magicStoneCollected","context":{"pickupType":"revivalStone","grade":"mid"}},
		{"id":"magicStoneCollected","context":{"pickupType":"revivalStone","grade":"high"}}
	]
	for item_id in content.data.items: acquisition_cases.append({"id":"purchase","context":{"itemId":item_id}})
	var acquisitions_fixed := true
	for acquisition in acquisition_cases:
		var expected: Dictionary = sound.describe_cue(acquisition.id,acquisition.context)
		acquisitions_fixed = acquisitions_fixed and not expected.is_empty()
		for index in range(10):
			sound.describe_cue("buttonClick",{"unrelated":index})
			acquisitions_fixed = acquisitions_fixed and sound.describe_cue(acquisition.id,acquisition.context) == expected
	_record("ten_repeats_per_drop_grade_and_item", acquisitions_fixed,{"events":acquisition_cases.size(),"repeatsPerEvent":10})
	# No MP3 player is started; only Dummy WAV voices are enabled here.
	sound._audible = true; sound._primed = true; sound._hidden = false; sound.set_paused(false)
	var playback: Array = []
	var fixed_playback := true
	for index in range(10):
		_clear_voices()
		sound.cue("buttonClick")
		sound.cue("critical" if index % 2 else "enemyHit",{"weaponId":"manaSword","monsterId":"crawler","stage":"hit","attackId":index})
		var played := false
		for voice in sound._voices:
			if str(voice.id) != str(baseline.id): continue
			var player: AudioStreamPlayer = voice.node
			var fact := {"url":player.stream.resource_path,"pitch":player.pitch_scale,"gain":db_to_linear(player.volume_db),"centerPlayer":player.get_class() == "AudioStreamPlayer"}
			playback.append(fact); played = true
			fixed_playback = fixed_playback and fact.url == baseline.url and is_equal_approx(fact.pitch,1.0) and is_equal_approx(fact.gain,float(baseline.gain)) and fact.centerPlayer
		fixed_playback = fixed_playback and played
	_record("actual_voice_fixed_source_pitch_gain_center", fixed_playback, playback)
	_clear_voices()
	var max_voices := 0
	var max_normal := 0
	for id in content.data.sfx:
		var definition: Dictionary = content.data.sfx[id]
		if bool(definition.get("loop",false)) or bool(definition.get("protected",false)): continue
		sound.cue(str(id))
		max_voices = maxi(max_voices,sound._voices.size()); max_normal = maxi(max_normal,_normal_count())
	var fixed_gains := true
	for voice in sound._voices:
		fixed_gains = fixed_gains and is_equal_approx(db_to_linear(voice.node.volume_db),float(content.data.sfx[voice.id].gain))
	_record("busy_mix_keeps_individual_gain", fixed_gains)
	for id in content.data.audioConfig.protected:
		sound.cue(str(id))
		max_voices = maxi(max_voices,sound._voices.size()); max_normal = maxi(max_normal,_normal_count())
	_record("voice_budget_16_normal_12", max_voices <= 16 and max_normal == 12,{"maximum":max_voices,"normalMaximum":max_normal})
	_clear_voices()
	var hops: Array = []
	for index in range(1,4):
		for voice in sound._voices: sound._stop_voice(voice)
		sound._voices.clear(); sound._last.clear()
		sound.cue("chainHop",{"attackId":"fixed-chain","hopIndex":index,"delay":0.0})
		hops.append({"count":int(sound._hops.get("fixed-chain",{}).get("count",0)),"voices":sound._voices.size()})
	_record("chain_two_hops", hops[0].count == 1 and hops[1].count == 2 and hops[2].count == 2 and hops[2].voices == 0,hops)
	_clear_voices()
	sound.cue("weaponFired",{"delay":0.12}); sound.set_paused(true); sound.advance_combat(1.0)
	var paused: bool = sound._pending.size() == 1 and sound._voices.is_empty()
	sound.set_paused(false); sound.advance_combat(0.10)
	var not_early: bool = sound._pending.size() == 1
	sound.advance_combat(0.03)
	_record("pause_and_combat_dt", paused and not_early and sound._pending.is_empty() and sound._voices.size() == 1)
	sound.cue("weaponFired",{"delay":0.2}); sound.stop_combat(); sound.advance_combat(1.0)
	_record("cleanup_cancels_delayed", sound._pending.is_empty() and sound._voices.is_empty())
	_event_contexts()
	_clear_voices()
	sound.ambience("officeDay")
	var loop_stream: AudioStreamWAV = sound._ambient.stream
	_record("office_stereo_loop", loop_stream != null and loop_stream.stereo and loop_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and sound._playing_ambience == "officeDay")
	var settings: Dictionary = profile.meta.settings.duplicate(true)
	profile.meta.settings.muted = true; sound.apply_settings()
	_record("existing_bgm_mute", AudioServer.is_bus_mute(AudioServer.get_bus_index("BGM")))
	profile.meta.settings = settings; sound.apply_settings()
	_record("existing_gain_buses", is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Combat"))),float(settings.combatVolume)*float(settings.soundVolume)))
	sound.cue("weaponFired",{"delay":0.2}); sound._focus_lost = true; sound._update_hidden()
	_record("focus_loss_clears_voices_pending", sound._hidden and sound._voices.is_empty() and sound._pending.is_empty() and not sound._ambient.playing)
	sound._focus_lost = false; sound._update_hidden()
	_record("focus_returns_only_environment", sound._ambient.playing and sound._voices.is_empty() and sound._pending.is_empty())
	sound.ambience(""); await create_timer(0.40).timeout
	_record("environment_stops_outside_lobby", not sound._ambient.playing and sound._ambient.stream == null)
	_record("music_never_started", not sound._music.playing and sound._music.stream == null)
	_finish()

func _event_contexts() -> void:
	var run := _new_run()
	var audio: Array = []
	var legacy: Array = []
	run.audio_event.connect(func(id,context): audio.append({"id":id,"context":context}))
	run.event.connect(func(id): legacy.append(id))
	var attacks := HeroAttacks.new(HeroSpatial.new())
	var enemy := {"id":1,"definition":"crawler","hp":10000.0,"armor":0.0,"pos":Vector2(10,0),"flash":0.0}
	for critical_chance in [0.0,1.0]:
		attacks.hit(run,enemy,1.0,{"weapon":"manaSword","contextId":1,"criticalChance":critical_chance,"criticalDamage":2.0,"lifesteal":0.0,"healingRemaining":0.0})
	_record("hit_emit_once_and_keep_critical_visual_event", audio.size() == 2 and audio[0].id == "enemyHit" and audio[1].id == "enemyHit" and audio[0].context.monsterId == "crawler" and legacy == ["enemyHit","critical"],audio)
	audio.clear(); legacy.clear()
	var dead := HeroSpawn.spawn(run,"crawler",false,1.0,1.0,[],Vector2.ZERO)
	dead.hp = 0.0
	attacks._deaths(run)
	_record("death_monster_emit_once", audio.size() == 1 and audio[0].id == "enemyKilled" and audio[0].context.monsterId == "crawler" and legacy == ["enemyKilled"],audio)
	audio.clear(); legacy.clear()
	var simulation := HeroSimulation.new(run)
	run.pickups = [{"pos":Vector2.ZERO,"units":1.0,"value":1.0}]
	run.loot_pickups = [{"pos":Vector2.ZERO,"type":"coin","amount":1},{"pos":Vector2.ZERO,"type":"revivalStone","grade":"high","amount":1}]
	simulation._pickups(0.01)
	_record("drop_type_grade_emit_once", audio.size() == 3 and legacy.size() == 3 and audio[0].context.pickupType == "magicStone" and audio[1].context.pickupType == "associationCoin" and audio[2].context.pickupType == "revivalStone" and audio[2].context.grade == "high",audio)
	audio.clear(); legacy.clear()
	run.phase = "shop"; run.currency = 1000000.0; run.wave = 20
	var item_id: String = run.available_items[0]
	run.item_stock = [{"id":item_id,"locked":false,"level":0,"free":true},{"id":""},{"id":""},{"id":""}]
	var bought := HeroShop.buy(run,0,false)
	_record("item_id_purchase_emit_once", bought and audio.size() == 1 and legacy == ["purchase"] and audio[0].context.itemId == item_id,audio)
	audio.clear(); legacy.clear()
	run.weapon_stock = [{"id":"manaBolt","locked":false,"level":2},{"id":""},{"id":""},{"id":""}]
	bought = HeroShop.buy(run,0,true)
	_record("weapon_id_purchase_emit_once", bought and audio.size() == 1 and legacy == ["weaponPurchase"] and audio[0].context.weaponId == "manaBolt",audio)
	# Calling just the bridge does not mount UI or run main's save callbacks.
	var main_script := load("res://scripts/core/main.gd") as GDScript
	var bridge: Node = main_script.new()
	_clear_voices()
	for id in ["enemyHit","critical","enemyKilled","playerHit","magicStoneCollected","purchase","weaponPurchase"]: bridge.call("_legacy_run_sound",id)
	_record("legacy_bridge_suppresses_semantic_duplicates", sound._voices.is_empty())
	for field in ["world","movement","canvas","ui_fx"]:
		var node: Node = bridge.get(field)
		if is_instance_valid(node): node.free()
	bridge.free()

func _finish() -> void:
	if sound != null: sound.shutdown()
	var path := ProjectSettings.globalize_path("res://../audio-library/reborn-02/qa/runtime-audio.json").simplify_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var report := {"scope":"synthetic audio-only Dummy output; no player file reads/writes, music playback, or full gameplay","checks":checks,"wavFiles":wavs,"errors":errors,"passed":errors.is_empty(),"unverified":["physical speaker listening","device playback","full gameplay and performance"]}
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"\t")+"\n")
	else: errors.append("report_write_failed")
	print("AUDIO_IDENTITY_CHECK ","PASS" if errors.is_empty() else "FAIL"," ",errors)
	quit(0 if errors.is_empty() else 1)
