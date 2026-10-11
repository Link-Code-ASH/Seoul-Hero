extends Node

var _music := AudioStreamPlayer.new()
var _ambient := AudioStreamPlayer.new()
var _mode := ""
var _playing_mode := ""
var _track := -1
var _ambience_id := ""
var _playing_ambience := ""
var _music_tween: Tween
var _ambience_tween: Tween
var _music_changing := false
var _ambience_changing := false
var _last: Dictionary = {}
var _voices: Array = []
var _pending: Array = []
var _hops: Dictionary = {}
var _cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _combat_clock := 0.0
var _hop_cleanup_at := 0.0
var _primed := false
var _audible := true
var _paused := false
var _hidden := false
var _app_paused := false
var _focus_lost := false
var _music_position := 0.0
var _ambience_position := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_audible = DisplayServer.get_name() != "headless" and "--ui-preview" not in OS.get_cmdline_user_args()
	_rng.randomize()
	for name in ["BGM", "Combat", "UI"]:
		if AudioServer.get_bus_index(name) >= 0: continue
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, name)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var compressor := AudioEffectCompressor.new()
	compressor.threshold = -5.0; compressor.ratio = 4.0
	AudioServer.add_bus_effect(0, compressor)
	add_child(_music); add_child(_ambient)
	_music.bus = "BGM"; _ambient.bus = "BGM"
	_music.finished.connect(_music_finished)
	apply_settings()

func _config() -> Dictionary:
	return Content.data.get("audioConfig", {})

func _connections() -> Dictionary:
	return Content.data.get("audioConnections", {})

func apply_settings() -> void:
	var settings: Dictionary = Profile.meta.settings
	for pair in [["Master", "masterVolume"], ["BGM", "musicVolume"], ["Combat", "combatVolume"], ["UI", "uiVolume"]]:
		var gain: float = float(settings.get(pair[1], 0.7))
		if pair[0] in ["Combat", "UI"]: gain *= float(settings.get("soundVolume", 0.7))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(pair[0]), linear_to_db(maxf(0.0001, gain)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("BGM"), bool(settings.get("muted", false)))

func prime() -> void:
	if _primed: return
	_primed = true
	if not _mode.is_empty(): _next_track()
	if not _ambience_id.is_empty(): _commit_ambience(_ambience_id)

func bgm_enabled() -> bool:
	return _audible and not _hidden and _music.playing and not Profile.meta.settings.muted and Profile.meta.settings.masterVolume > 0 and Profile.meta.settings.musicVolume > 0

func _stream(url: String) -> AudioStream:
	if not _cache.has(url): _cache[url] = load(url) as AudioStream
	return _cache[url] as AudioStream

func _fade_duration() -> float:
	return maxf(0.0, float(_config().get("musicFade", 0.35)))

func _kill_music_tween() -> void:
	if _music_tween != null and _music_tween.is_valid(): _music_tween.kill()
	_music_tween = null

func _kill_ambience_tween() -> void:
	if _ambience_tween != null and _ambience_tween.is_valid(): _ambience_tween.kill()
	_ambience_tween = null

func _music_gain() -> float:
	var group: Dictionary = Content.data.bgm.get(_mode, {})
	var gain := float(group.get("gain", 0.5))
	if _paused: gain *= float(_config().get("pauseGain", 0.25))
	return gain

func _fade_music_gain() -> void:
	if not _audible or _hidden or not _music.playing: return
	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", linear_to_db(maxf(0.0001, _music_gain())), _fade_duration())

func music(mode: String) -> void:
	if _mode == mode: return
	_mode = mode; _track = -1
	_kill_music_tween()
	if not _audible or not _primed or _hidden:
		_music.stop()
		_music.stream = null
		_playing_mode = ""
		return
	_music_changing = true
	if _music.playing:
		_music_tween = create_tween()
		_music_tween.tween_property(_music, "volume_db", -80.0, _fade_duration())
		_music_tween.tween_callback(_commit_music.bind(mode))
	else:
		_commit_music(mode)

func _commit_music(expected_mode: String) -> void:
	if expected_mode != _mode: return
	_music_tween = null; _music_changing = false
	_music.stop(); _music.stream = null; _playing_mode = ""
	if _mode.is_empty() or not _audible or not _primed or _hidden: return
	_next_track()

func _next_track() -> void:
	if not _audible or not _primed or _hidden or _mode.is_empty(): return
	var group: Dictionary = Content.data.bgm.get(_mode, {})
	var tracks: Array = group.get("tracks", [])
	if tracks.is_empty(): return
	var candidates: Array = []
	for index in range(tracks.size()):
		if index != _track or tracks.size() == 1: candidates.append(index)
	_track = int(candidates[_rng.randi_range(0, candidates.size() - 1)])
	_music.stream = _stream(str(tracks[_track].url))
	if _music.stream == null: return
	_playing_mode = _mode
	_music.volume_db = -80.0
	_music.play()
	_fade_music_gain()

func _music_finished() -> void:
	if _music_changing:
		_kill_music_tween()
		_commit_music(_mode)
	else:
		_next_track()

func _resolve_cue(id: String, context: Dictionary) -> String:
	var connections := _connections()
	var identities: Dictionary = connections.get("identities", {})
	var aliases: Dictionary = identities.get("aliases", {})
	id = str(aliases.get(id, id))
	var weapon_id := str(context.get("weaponId", ""))
	var monster_id := str(context.get("monsterId", ""))
	var materials: Dictionary = identities.get("monsterMaterials", {})
	var material := str(materials.get(monster_id, identities.get("defaultMaterial", "soft")))
	# Resolve semantic events before weapon stages: purchase/hit are not launches.
	if id == "enemyHit":
		var hits: Dictionary = identities.get("weaponHits", {})
		if hits.has(weapon_id):
			if hits[weapon_id] == null: return ""
			var profile: Dictionary = hits[weapon_id]
			return str(profile.get(material, profile.get(str(identities.get("defaultMaterial", "soft")), id)))
		return id
	if id == "enemyKilled":
		return str(identities.get("materialDeaths", {}).get(material, id))
	if id == "magicStoneCollected":
		var pickup: Variant = identities.get("pickups", {}).get(str(context.get("pickupType", "magicStone")), id)
		if pickup is Dictionary: return str(pickup.get(str(context.get("grade", "")), id))
		return str(pickup)
	if id == "purchase":
		return str(identities.get("items", {}).get(str(context.get("itemId", "")), id))
	if id == "weaponPurchase":
		return str(identities.get("weaponPurchases", {}).get(weapon_id, id))
	if id == "playerHit": return id
	var stage := str(context.get("stage", ""))
	var weapons: Dictionary = connections.get("weaponStages", {})
	if weapons.has(weapon_id):
		var stages: Dictionary = weapons[weapon_id]
		if stages.has(stage): return "" if stages[stage] == null else str(stages[stage])
	var behavior := str(context.get("behavior", ""))
	var actions: Dictionary = connections.get("enemyActions", {})
	if actions.has(behavior): return str(actions[behavior])
	if actions.has(id): return str(actions[id])
	return id

# Read-only description used by audio-only diagnostics and the listening report.
# Selection has no RNG, instance IDs, spatial parameters, or mutable history.
func describe_cue(id: String, context: Dictionary = {}) -> Dictionary:
	var resolved := _resolve_cue(id, context)
	var definition: Dictionary = Content.data.sfx.get(resolved, {})
	var urls: Array = definition.get("urls", [])
	if resolved.is_empty() or urls.is_empty(): return {}
	return {"id":resolved,"url":str(urls[0]),"pitch":1.0,"gain":float(definition.get("gain",0.25)),"pan":0.0,"group":str(definition.get("group","ui"))}

func cue(id: String, context: Dictionary = {}) -> void:
	if not _audible or _hidden: return
	var resolved := _resolve_cue(id, context)
	if resolved.is_empty(): return
	var definition: Dictionary = Content.data.sfx.get(resolved, {})
	if definition.is_empty() or bool(definition.get("loop", false)): return
	var delay := maxf(0.0, float(context.get("delay", 0.0)))
	if resolved == "chainHop" and not context.has("delay"):
		delay = float(_config().get("chainHopDelay", 0.09)) * maxf(1.0, float(context.get("hopIndex", 1)))
	if delay > 0.0:
		_pending.append({"id": resolved, "context": context.duplicate(true), "remaining": delay})
	else:
		_play_cue(resolved, context)

func _prune_voices() -> void:
	var active: Array = []
	for voice in _voices:
		if not is_instance_valid(voice.get("node")): continue
		var player := voice.node as AudioStreamPlayer
		if is_instance_valid(player) and player.playing: active.append(voice)
	_voices = active

func _protected(id: String, definition: Dictionary) -> bool:
	var ids: Array = _config().get("protected", [])
	return bool(definition.get("protected", false)) or ids.has(id)

func _stop_voice(voice: Dictionary) -> void:
	if not is_instance_valid(voice.get("node")): return
	var player := voice.get("node") as AudioStreamPlayer
	if not is_instance_valid(player): return
	player.stop(); player.stream = null
	if not player.is_queued_for_deletion(): player.queue_free()

func _play_cue(id: String, context: Dictionary) -> void:
	if not _audible or _hidden: return
	var definition: Dictionary = Content.data.sfx.get(id, {})
	var urls: Array = definition.get("urls", [])
	if urls.is_empty(): return
	var group := str(definition.get("group", "ui"))
	if group == "combat" and _paused: return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(id, -999.0)) < float(definition.get("interval", 0.0)): return
	_prune_voices()
	var same := 0
	var normal := 0
	for voice in _voices:
		if voice.id == id: same += 1
		if not bool(voice.protected): normal += 1
	if same >= int(definition.get("concurrency", 1)): return
	var attack_id := str(context.get("attackId", ""))
	var hop_limit := int(_config().get("chainHopMaxPerAttack", 2))
	var hop_state: Dictionary = _hops.get(attack_id, {})
	if id == "chainHop" and not attack_id.is_empty() and int(hop_state.get("count", 0)) >= hop_limit: return
	var important := _protected(id, definition)
	var priority := int(definition.get("priority", 1))
	var full := _voices.size() >= int(_config().get("maxVoices", 16))
	var normal_full := not important and normal >= int(_config().get("normalVoices", 12))
	if full or normal_full:
		var victim: Dictionary = {}
		for voice in _voices:
			if bool(voice.protected) or int(voice.priority) >= priority: continue
			if victim.is_empty() or int(voice.priority) < int(victim.priority) or (int(voice.priority) == int(victim.priority) and float(voice.started) < float(victim.started)):
				victim = voice
		if victim.is_empty(): return
		_stop_voice(victim); _voices.erase(victim)
	# Each profile owns a single authored composite. Legacy multi-url cues also
	# use their fixed first source; runtime never changes timbre or loudness.
	var url := str(urls[0])
	var stream := _stream(url)
	if stream == null: return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Combat" if group == "combat" else "UI"
	var gain := float(definition.get("gain", 0.25))
	player.volume_db = linear_to_db(maxf(0.0001, gain))
	player.pitch_scale = 1.0
	add_child(player)
	player.finished.connect(player.queue_free)
	_voices.append({"node": player, "id": id, "group": group, "priority": priority, "protected": important, "started": now})
	_last[id] = now
	if id == "chainHop" and not attack_id.is_empty(): _hops[attack_id] = {"count": int(hop_state.get("count", 0)) + 1, "at": _combat_clock}
	player.play()

# Main supplies exactly the same dt used by simulation.tick, only in waveActive.
func advance_combat(dt: float) -> void:
	if not _audible or _hidden or _paused or dt <= 0.0: return
	_combat_clock += dt
	var waiting: Array = []
	var ready: Array = []
	for pending in _pending:
		pending.remaining -= dt
		if float(pending.remaining) <= 0.0: ready.append(pending)
		else: waiting.append(pending)
	_pending = waiting
	for pending in ready: _play_cue(str(pending.id), pending.context)
	if _combat_clock >= _hop_cleanup_at:
		_hop_cleanup_at = _combat_clock + 2.0
		for attack_id in _hops.keys():
			if _combat_clock - float(_hops[attack_id].at) > 8.0: _hops.erase(attack_id)

func stop_combat() -> void:
	_pending.clear(); _hops.clear()
	var retained: Array = []
	for voice in _voices:
		if str(voice.get("group", "")) == "combat": _stop_voice(voice)
		else: retained.append(voice)
	_voices = retained
	for id in _last.keys():
		var definition: Dictionary = Content.data.sfx.get(id, {})
		if str(definition.get("group", "")) == "combat": _last.erase(id)

func set_paused(value: bool) -> void:
	if _paused == value: return
	_paused = value
	for voice in _voices:
		if not is_instance_valid(voice.get("node")): continue
		var player := voice.node as AudioStreamPlayer
		if is_instance_valid(player) and str(voice.get("group", "")) == "combat": player.stream_paused = value
	if not _music_changing: _fade_music_gain()
	if not _ambience_changing: _fade_ambience_gain()

func _ambience_gain() -> float:
	var definition: Dictionary = Content.data.sfx.get(_ambience_id, {})
	var gain := float(definition.get("gain", 0.1))
	if _paused: gain *= float(_config().get("pauseGain", 0.25))
	return gain

func _fade_ambience_gain() -> void:
	if not _audible or _hidden or not _ambient.playing: return
	_kill_ambience_tween()
	_ambience_tween = create_tween()
	_ambience_tween.tween_property(_ambient, "volume_db", linear_to_db(maxf(0.0001, _ambience_gain())), _fade_duration())

func ambience(id: String) -> void:
	var backgrounds: Dictionary = _connections().get("lobbyBackgrounds", {})
	var resolved := str(backgrounds.get(id, id))
	if _ambience_id == resolved: return
	_ambience_id = resolved
	_kill_ambience_tween()
	if not _audible or not _primed or _hidden:
		_ambient.stop(); _ambient.stream = null; _playing_ambience = ""
		return
	_ambience_changing = true
	if _ambient.playing:
		_ambience_tween = create_tween()
		_ambience_tween.tween_property(_ambient, "volume_db", -80.0, _fade_duration())
		_ambience_tween.tween_callback(_commit_ambience.bind(resolved))
	else:
		_commit_ambience(resolved)

func _commit_ambience(expected_id: String) -> void:
	if expected_id != _ambience_id: return
	_ambience_tween = null; _ambience_changing = false
	_ambient.stop(); _ambient.stream = null; _playing_ambience = ""
	if _ambience_id.is_empty() or not _audible or not _primed or _hidden: return
	var definition: Dictionary = Content.data.sfx.get(_ambience_id, {})
	var urls: Array = definition.get("urls", [])
	if urls.is_empty() or not bool(definition.get("loop", false)): return
	var stream := _stream(str(urls[0]))
	if stream == null: return
	if stream is AudioStreamWAV:
		var loop_stream := stream.duplicate() as AudioStreamWAV
		loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop_stream.loop_begin = 0
		loop_stream.loop_end = roundi(loop_stream.get_length() * loop_stream.mix_rate)
		stream = loop_stream
	_ambient.stream = stream
	_playing_ambience = _ambience_id
	_ambient.volume_db = -80.0
	_ambient.play()
	_fade_ambience_gain()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_app_paused = true; _update_hidden()
		NOTIFICATION_APPLICATION_RESUMED:
			_app_paused = false; _update_hidden()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focus_lost = true; _update_hidden()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focus_lost = false; _update_hidden()

func _update_hidden() -> void:
	var value := _app_paused or _focus_lost
	if _hidden == value: return
	_hidden = value
	if _hidden:
		_music_position = _music.get_playback_position() if _music.playing else 0.0
		_ambience_position = _ambient.get_playback_position() if _ambient.playing else 0.0
		_kill_music_tween(); _kill_ambience_tween()
		_music_changing = false; _ambience_changing = false
		_music.stop(); _ambient.stop()
		for voice in _voices: _stop_voice(voice)
		_voices.clear(); _pending.clear(); _hops.clear()
	elif _audible and _primed:
		if not _mode.is_empty() and _mode == _playing_mode and _music.stream != null:
			_music.volume_db = -80.0; _music.play(_music_position); _fade_music_gain()
		elif not _mode.is_empty(): _next_track()
		if not _ambience_id.is_empty() and _ambience_id == _playing_ambience and _ambient.stream != null:
			_ambient.volume_db = -80.0; _ambient.play(_ambience_position); _fade_ambience_gain()
		elif not _ambience_id.is_empty(): _commit_ambience(_ambience_id)

func shutdown() -> void:
	_audible = false
	_kill_music_tween(); _kill_ambience_tween()
	_music.stop(); _music.stream = null
	_ambient.stop(); _ambient.stream = null
	for voice in _voices: _stop_voice(voice)
	_voices.clear(); _pending.clear(); _hops.clear(); _cache.clear()

func _exit_tree() -> void:
	shutdown()
