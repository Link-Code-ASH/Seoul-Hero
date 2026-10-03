extends Node

const SAVE_PATH := "user://profile.json"
const BACKUP_PATH := "user://profile.backup.json"
const CHECKPOINT_PATH := "user://run.json"
var meta: Dictionary = {}
var writable := true

func _ready() -> void:
	# Read-only layout previews must never update a player's profile/checkpoint.
	if "--ui-preview" in OS.get_cmdline_user_args(): writable = false
	if FileAccess.file_exists(CHECKPOINT_PATH) and HeroRunCheckpoint.is_future(JSON.parse_string(FileAccess.get_file_as_string(CHECKPOINT_PATH))):
		writable = false
		push_warning("더 새로운 전투 체크포인트입니다. 자동 덮어쓰기를 중지했습니다.")
	meta = Content.data.defaultMeta.duplicate(true)
	if FileAccess.file_exists(SAVE_PATH):
		var stored = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if stored is Dictionary and int(stored.get("formatVersion", 0)) > 1:
			writable = false
			push_warning("더 새로운 저장 형식입니다. 자동 덮어쓰기를 중지했습니다.")
		elif _valid(stored): meta = stored.meta
		elif FileAccess.file_exists(BACKUP_PATH):
			var backup = JSON.parse_string(FileAccess.get_file_as_string(BACKUP_PATH))
			if _valid(backup): meta = backup.meta
	HeroMeta.initialize(Content.data, meta)
	HeroMeta.weekly(Content.data, meta, Time.get_unix_time_from_system())
	HeroMeta.accrue_offline(Content.data, meta, Time.get_unix_time_from_system())
	save()

func _valid(value) -> bool:
	if not value is Dictionary or value.get("formatVersion", 0) != 1 or not value.get("meta") is Dictionary: return false
	for key in Content.data.defaultMeta:
		if not value.meta.get(key) is Dictionary: return false
	return value.meta.wallet.get("associationCoins") is float or value.meta.wallet.get("associationCoins") is int

func save() -> void:
	if not writable: return
	meta.offlineReward.lastExitAt = Time.get_datetime_string_from_system(true)
	var raw := JSON.stringify({"formatVersion":1,"sourceSaveVersion":13,"savedAt":Time.get_datetime_string_from_system(true),"meta":meta}, "\t")
	var temp := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if temp == null: push_error("저장 파일을 열 수 없습니다."); return
	temp.store_string(raw)
	temp.close()
	if FileAccess.file_exists(SAVE_PATH): DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	var error := DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
	if error != OK: push_error("저장을 완료하지 못했습니다: %s" % error)

func save_run(run: HeroRun) -> void:
	if not writable or run.settled: return
	var state := {}
	for key in ["setup","phase","previous_phase","wave","elapsed","combat_time","currency","wallet","collected","kills","sequence","player","stats","modifiers","base_modifiers","item_effects","item_state","difficulty","owned","items","enemies","pickups","bullets","hostile","hazards","structures","pending","pending_branch","item_stock","weapon_stock","item_rerolls","weapon_rerolls","available_weapons","available_items","spawn_state","telemetry"]:
		state[key] = _encode(run.get(key))
	var file := FileAccess.open(CHECKPOINT_PATH + ".tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version":HeroRunCheckpoint.VERSION,"state":state}))
		file.close()
		DirAccess.rename_absolute(CHECKPOINT_PATH + ".tmp", CHECKPOINT_PATH)

func restore_run() -> HeroRun:
	if not FileAccess.file_exists(CHECKPOINT_PATH): return null
	var payload := HeroRunCheckpoint.migrate(JSON.parse_string(FileAccess.get_file_as_string(CHECKPOINT_PATH)))
	if payload.is_empty(): return null
	var state: Dictionary = _decode(payload.state)
	if not state.has("setup") or not Content.data.characters.has(state.setup.get("character", "")) or not Content.data.maps.has(state.setup.get("map", "")) or not Content.data.weapons.has(state.setup.get("weapon", "")): return null
	if state.get("phase", "") not in ["waveActive","postWave","shop","paused","revivalChoice"]: return null
	var run := HeroRun.new(Content.data, state.setup, meta)
	for key in state: run.set(key, state[key])
	if run.phase == "postWave":
		# Recovered stones are already in the wallet; never sweep or pay twice.
		run.phase = "shop"
		HeroShop.refresh(run,true); HeroShop.refresh(run,false)
	# JSON duplicates dictionaries; restore one healing budget per shared attack.
	var contexts := {}
	for attack in run.bullets + run.pending:
		if not attack.has("context"): continue
		var id: int = attack.context.get("contextId",-1)
		if id < 0: continue
		if not contexts.has(id): contexts[id] = attack.context
		attack.context = contexts[id]
	if run.phase != "paused": run.previous_phase = run.phase
	run.phase = "paused"
	return run

func import_backup(path: String) -> bool:
	if not writable: return false
	var stored = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not _valid(stored): return false
	# Keep the previous profile even after the normal rotating backup advances.
	if FileAccess.file_exists(SAVE_PATH): DirAccess.copy_absolute(SAVE_PATH,"user://before-import-%d.json" % Time.get_unix_time_from_system())
	meta = stored.meta
	HeroMeta.initialize(Content.data,meta)
	HeroMeta.weekly(Content.data,meta,Time.get_unix_time_from_system())
	clear_run(); save()
	return true

func clear_run() -> void:
	if writable and FileAccess.file_exists(CHECKPOINT_PATH): DirAccess.remove_absolute(CHECKPOINT_PATH)

func record_analytics(run: HeroRun) -> void:
	if not writable: return
	var records: Array = []
	if FileAccess.file_exists("user://analytics.json"):
		var stored = JSON.parse_string(FileAccess.get_file_as_string("user://analytics.json"))
		if stored is Array: records = stored
	records.append(HeroTelemetry.result(run))
	while records.size() > int(Content.data.balance.telemetryRuns): records.pop_front()
	var file := FileAccess.open("user://analytics.json.tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(records)); file.close()
		DirAccess.rename_absolute("user://analytics.json.tmp","user://analytics.json")

func _encode(value):
	if value is Vector2: return {"__vector2":[value.x, value.y]}
	if value is Array: return value.map(_encode)
	if value is Dictionary:
		var output := {}
		for key in value: output[key] = _encode(value[key])
		return output
	return value

func _decode(value):
	if value is Array: return value.map(_decode)
	if value is Dictionary:
		if value.has("__vector2"): return Vector2(value.__vector2[0], value.__vector2[1])
		var output := {}
		for key in value: output[key] = _decode(value[key])
		return output
	return value
