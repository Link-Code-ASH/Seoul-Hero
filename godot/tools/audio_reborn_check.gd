extends SceneTree

# One-off audio-only smoke check. No run, save writes, MP3 playback, or gameplay.
var sound: Variant
var profile: Variant
var content: Variant
var checks: Array = []
var errors: Array = []
var wavs: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _record(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name": name, "passed": passed, "detail": detail})
	if not passed: errors.append(name)

func _normal_count() -> int:
	var count := 0
	for voice in sound._voices:
		if not bool(voice.protected): count += 1
	return count

func _run() -> void:
	await process_frame
	sound = root.get_node("Sound")
	profile = root.get_node("Profile")
	content = root.get_node("Content")
	_record("profile_writes_blocked", not profile.writable)
	_record("preview_audio_disabled", not sound._audible)
	if profile.writable:
		_finish(); return
	for path in ["res://scripts/core/main.gd", "res://scripts/state/run.gd", "res://scripts/systems/attacks.gd", "res://scripts/systems/enemy_brain.gd", "res://scripts/ui/lobby_screen.gd"]:
		var script := load(path) as GDScript
		_record("script_compile_" + path.get_file(), script != null and script.can_instantiate(), path)
	var missing: Array = []
	for id in content.data.sfx:
		var cue: Dictionary = content.data.sfx[id]
		for url in cue.urls:
			var stream := load(str(url)) as AudioStreamWAV
			var valid := stream != null
			var fact := {"cue": id, "url": url, "loaded": valid}
			if valid:
				fact.merge({"rate": stream.mix_rate, "bits16": stream.format == AudioStreamWAV.FORMAT_16_BITS, "stereo": stream.stereo, "length": stream.get_length()})
				valid = stream.mix_rate == 48000 and stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.stereo == bool(cue.get("loop", false)) and stream.get_length() > 0
				sound._cache[url] = stream
			if not valid: missing.append(url)
			wavs.append(fact)
	_record("128_wav_formats", wavs.size() == 128 and missing.is_empty(), {"count": wavs.size(), "invalid": missing})
	var bad_mapping: Array = []
	var connections: Dictionary = content.data.audioConnections
	for weapon in connections.weaponStages:
		for stage in connections.weaponStages[weapon]:
			var target: Variant = connections.weaponStages[weapon][stage]
			if typeof(target) == TYPE_STRING and not content.data.sfx.has(target): bad_mapping.append(str(weapon) + "/" + str(stage))
	for group in ["enemyActions", "lobbyBackgrounds"]:
		for action in connections.get(group, {}):
			if not content.data.sfx.has(connections[group][action]): bad_mapping.append(group + "/" + str(action))
	_record("audio_mapping_paths", bad_mapping.is_empty(), bad_mapping)
	_record("music_data_only", is_equal_approx(float(content.data.bgm.combat.gain), 0.12) and is_equal_approx(float(content.data.audioConfig.musicFade), 0.35) and is_equal_approx(float(content.data.audioConfig.pauseGain), 0.25))
	# Dummy output is deliberately enabled only for short WAV voices here.
	sound._audible = true; sound._primed = true
	sound._hidden = false; sound.set_paused(false)
	var variants: Array = []
	for index in range(5):
		sound.cue("weaponFired")
		variants.append(sound._last_variant.get("weaponFired", ""))
		sound.stop_combat()
	var distinct := not variants.has("")
	for index in range(1, variants.size()):
		if variants[index] == variants[index - 1]: distinct = false
	_record("no_consecutive_variant", distinct, variants)
	var maximum := 0
	var normal_maximum := 0
	for id in content.data.sfx:
		var cue: Dictionary = content.data.sfx[id]
		if bool(cue.get("loop", false)) or bool(cue.get("protected", false)): continue
		sound.cue(str(id))
		maximum = maxi(maximum, sound._voices.size())
		normal_maximum = maxi(normal_maximum, _normal_count())
	sound.cue("playerHit")
	var hit_gain := 0.0
	for voice in sound._voices:
		if voice.id == "playerHit": hit_gain = db_to_linear(voice.node.volume_db)
	var hit: Dictionary = content.data.sfx.playerHit
	var minimum_gain := float(hit.gain) * (1.0 - float(hit.volumeVariation))
	_record("protected_hit_without_busy_attenuation", hit_gain >= minimum_gain - 0.0001, {"gain": hit_gain, "minimum": minimum_gain, "busyNormals": normal_maximum})
	for id in content.data.audioConfig.protected:
		sound.cue(str(id))
		maximum = maxi(maximum, sound._voices.size())
		normal_maximum = maxi(normal_maximum, _normal_count())
	_record("voice_reserve_limits", maximum <= 16 and normal_maximum == 12, {"max": maximum, "normalMax": normal_maximum})
	for voice in sound._voices: sound._stop_voice(voice)
	sound._voices.clear(); sound.stop_combat()
	# Isolate the attack budget from real-clock throttle and cue concurrency.
	# Retire previous voices without clearing the attack's hop count.
	var hop_steps: Array = []
	for hop in range(1, 4):
		for voice in sound._voices: sound._stop_voice(voice)
		sound._voices.clear()
		sound._last["chainHop"] = -999.0
		sound.cue("chainHop", {"attackId": "audio-check-chain", "hopIndex": hop, "delay": 0.0})
		hop_steps.append({"hop": hop, "count": int(sound._hops.get("audio-check-chain", {}).get("count", 0)), "ticks": Time.get_ticks_msec(), "voices": sound._voices.size(), "lastVariant": sound._last_variant.get("chainHop", "")})
	var hop_limit_ok: bool = hop_steps[0].count == 1 and hop_steps[1].count == 2 and hop_steps[2].count == 2 and hop_steps[2].voices == 0 and hop_steps[2].lastVariant == hop_steps[1].lastVariant
	_record("two_hops_per_attack", hop_limit_ok, hop_steps)
	sound.stop_combat()
	sound.cue("weaponFired", {"delay": 0.12})
	sound.set_paused(true); sound.advance_combat(1.0)
	var frozen: bool = sound._pending.size() == 1 and sound._voices.is_empty()
	sound.set_paused(false); sound.advance_combat(0.10)
	var not_early: bool = sound._pending.size() == 1
	sound.advance_combat(0.03)
	_record("scheduled_combat_dt_and_pause", frozen and not_early and sound._pending.is_empty() and sound._voices.size() == 1)
	sound.cue("weaponFired", {"delay": 0.2}); sound.stop_combat(); sound.advance_combat(1.0)
	_record("cleanup_cancels_queued_audio", sound._pending.is_empty() and sound._voices.is_empty())
	sound.ambience("rain")
	var loop_stream := sound._ambient.stream as AudioStreamWAV
	var loop_ok := loop_stream != null and loop_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and loop_stream.loop_end > 0 and loop_stream.stereo
	sound.ambience("wind")
	await create_timer(0.75).timeout
	var ambience_voices := 0
	for child in sound.get_children():
		if child is AudioStreamPlayer and child.bus == "BGM" and child.playing: ambience_voices += 1
	_record("single_stereo_loop", loop_ok and ambience_voices == 1 and sound._playing_ambience == "lobbyWind", {"active": ambience_voices, "id": sound._playing_ambience})
	sound.ambience("")
	await create_timer(0.40).timeout
	_record("ambience_stops_outside_lobby", not sound._ambient.playing and sound._ambient.stream == null)
	_record("no_mp3_playback", not sound._music.playing and sound._music.stream == null)
	_finish()

func _finish() -> void:
	sound.shutdown()
	var path := ProjectSettings.globalize_path("res://../audio-library/reborn-01/qa/runtime-audio.json").simplify_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var report := {"scope": "audio-only Dummy output smoke check; no gameplay or saved writes", "checkedAt": Time.get_datetime_string_from_system(true), "checks": checks, "wavFiles": wavs, "errors": errors, "passed": errors.is_empty(), "unverified": ["direct listening", "device playback", "MP3 fade listening", "full tests/build/performance"]}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t") + "\n")
	else: errors.append("qa_report_write_failed")
	print("AUDIO_REBORN_CHECK ", "PASS" if errors.is_empty() else "FAIL", " ", errors)
	quit(0 if errors.is_empty() else 1)
