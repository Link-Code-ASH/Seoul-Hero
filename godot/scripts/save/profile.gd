extends Node

const FORMAT_VERSION := 4
const MAX_RECORDED_DEPTH := 1000000

const SAVE_PATH := "user://profile.json"
const BACKUP_PATH := "user://profile.backup.json"
const CHECKPOINT_PATH := "user://run.json"
var meta: Dictionary = {}
var writable := true
var _rotate_backup := true

func _ready() -> void:
	# This verification mode uses only synthetic memory state, never user files.
	if "--guild-floor-save-check" in OS.get_cmdline_user_args() or "--guild-office-preview" in OS.get_cmdline_user_args() or ("--audio-identity-check" in OS.get_cmdline_user_args() and "--ui-preview" in OS.get_cmdline_user_args()):
		writable = false
		meta = Content.data.defaultMeta.duplicate(true)
		meta.guild = HeroGuildState.create(Content.data,1000.0)
		return
	# Read-only layout previews must never update a player's profile/checkpoint.
	if "--ui-preview" in OS.get_cmdline_user_args(): writable = false
	if FileAccess.file_exists(CHECKPOINT_PATH) and HeroRunCheckpoint.is_future(JSON.parse_string(FileAccess.get_file_as_string(CHECKPOINT_PATH))):
		writable = false
		push_warning("더 새로운 전투 체크포인트입니다. 자동 덮어쓰기를 중지했습니다.")
	meta = Content.data.defaultMeta.duplicate(true)
	meta.guild = HeroGuildState.create(Content.data,Time.get_unix_time_from_system())
	HeroMeta.apply_starter(Content.data,meta)
	if FileAccess.file_exists(SAVE_PATH):
		var stored = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if stored is Dictionary and int(stored.get("formatVersion", 0)) > FORMAT_VERSION:
			writable = false
			push_warning("더 새로운 저장 형식입니다. 자동 덮어쓰기를 중지했습니다.")
		elif not _migrate(stored).is_empty(): meta = _migrate(stored).meta
		elif FileAccess.file_exists(BACKUP_PATH):
			var backup = JSON.parse_string(FileAccess.get_file_as_string(BACKUP_PATH))
			if backup is Dictionary and int(backup.get("formatVersion",0)) > FORMAT_VERSION:
				writable = false
				push_warning("더 새로운 백업 형식입니다. 자동 덮어쓰기를 중지했습니다.")
			elif not _migrate(backup).is_empty():
				meta = _migrate(backup).meta
				_rotate_backup = false
	# A newer backup is also protected even when the primary profile is readable.
	if FileAccess.file_exists(BACKUP_PATH):
		var preserved = JSON.parse_string(FileAccess.get_file_as_string(BACKUP_PATH))
		if preserved is Dictionary and int(preserved.get("formatVersion",0)) > FORMAT_VERSION: writable = false
	HeroMeta.initialize(Content.data, meta)
	HeroMeta.weekly(Content.data, meta, Time.get_unix_time_from_system())
	HeroMeta.accrue_offline(Content.data, meta, Time.get_unix_time_from_system())
	HeroGuildClock.advance(Content.data,meta,Time.get_unix_time_from_system())
	save()

func _valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("formatVersion",0) != FORMAT_VERSION or not value.get("meta") is Dictionary: return false
	if not _valid_meta(value.meta): return false
	return HeroGuildState.valid(Content.data,value.meta.guild)

func _valid_meta(value: Dictionary, legacy: bool = false) -> bool:
	for key in Content.data.defaultMeta:
		if not value.get(key) is Dictionary: return false
	for key in ["associationCoins","supplyTickets"]:
		if not HeroGuildState.number(value.wallet.get(key),0,1.0e15,true): return false
	if not _valid_stones(value.wallet.get("revivalStones")): return false
	if not value.association.get("upgrades") is Dictionary: return false
	for key in value.association.upgrades:
		if not key is String or not HeroGuildState.number(value.association.upgrades[key],0,1.0e15,true): return false
	for pair in [["characters",Content.data.characters,"breakthrough"],["sharedWeapons",Content.data.weapons,"level"],["blessings",Content.data.blessings,"level"]]:
		for id in value[pair[0]]:
			var progress: Variant = value[pair[0]][id]
			if not pair[1].has(id) or not progress is Dictionary or not progress.get("unlocked") is bool: return false
			if not HeroGuildState.number(progress.get("fragments"),0,1.0e15,true) or not HeroGuildState.number(progress.get(pair[2]),0,Content.data.growth.maxLevel,true): return false
	if not value.supply.get("boxes") is Dictionary: return false
	for box in value.supply.boxes.values():
		if not box is Dictionary or not HeroGuildState.number(box.get("opened"),0,1.0e15,true) or not HeroGuildState.number(box.get("pity"),0,Content.data.supply.pityLimit-1,true): return false
	if not HeroGuildState.number(value.gateProgression.get("highestUnlockedDepth"),1,MAX_RECORDED_DEPTH+1,true) or not value.gateProgression.get("characters") is Dictionary: return false
	for id in value.gateProgression.characters:
		var progress: Variant = value.gateProgression.characters[id]
		if not Content.data.characters.has(id) or not progress is Dictionary or not progress.get("bestWaveByDepth") is Dictionary: return false
		for key in ["highestClearedDepth","rewardedThroughDepth"]:
			if not HeroGuildState.number(progress.get(key),0,MAX_RECORDED_DEPTH,true): return false
		for depth in progress.bestWaveByDepth:
			if not str(depth).is_valid_int() or int(depth) < 1 or int(depth) > MAX_RECORDED_DEPTH or not HeroGuildState.number(progress.bestWaveByDepth[depth],0,1.0e15,true): return false
	if not _valid_statistics(value.statistics): return false
	var offline: Dictionary = value.offlineReward
	if not offline.get("lastExitAt") is String or not offline.get("lastClaimedAt") is String or not offline.get("pendingRewards") is Dictionary: return false
	var pending: Dictionary = offline.pendingRewards
	for key in ["associationCoins","supplyTickets"]:
		if not HeroGuildState.number(pending.get(key),0,1.0e15,true): return false
	if not _valid_stones(pending.get("revivalStones")): return false
	for key in HeroGuildState.FRAGMENTS:
		var known: Dictionary = Content.data[{"characterFragments":"characters","weaponFragments":"weapons","blessingFragments":"blessings"}[key]]
		if not HeroGuildState.amounts(pending.get(key),known): return false
	if legacy: return true
	for key in HeroGuildState.RESOURCES:
		if not HeroGuildState.number(pending.get(key),0,1.0e15,true): return false
	if not HeroGuildState.number(offline.get("lastAccruedAt")) or not HeroGuildState.number(offline.get("accumulatedSeconds"),0,Content.data.guildManagement.balance.offlineHoursMax*3600.0): return false
	if not HeroGuildState.number(offline.get("rewardedIntervals"),0,1.0e15,true) or not offline.get("rewardCarry") is Dictionary: return false
	if offline.rewardedIntervals*Content.data.offline.coinIntervalMinutes*60.0 > offline.accumulatedSeconds+0.000001: return false
	for key in offline.rewardCarry:
		if key not in HeroGuildState.RESOURCES and key not in ["associationCoins","supplyTickets"]: return false
		if not HeroGuildState.number(offline.rewardCarry[key],0,1.0): return false
	if not value.gateProgression.get("firstClears") is Dictionary: return false
	for map_id in value.gateProgression.firstClears:
		if not Content.data.maps.has(map_id) or not value.gateProgression.firstClears[map_id] is Array: return false
		var seen := {}
		for depth in value.gateProgression.firstClears[map_id]:
			if not HeroGuildState.number(depth,1,MAX_RECORDED_DEPTH,true) or seen.has(depth): return false
			seen[depth] = true
	if value.has("daily"):
		var daily: Variant = value.daily
		if not daily is Dictionary or not HeroGuildState.number(daily.get("claimedDayKey"),-1,1.0e9,true) or not HeroGuildState.number(daily.get("streak"),0,1.0e9,true): return false
	if value.statistics.has("lastRun"):
		var last: Variant = value.statistics.lastRun
		if not last is Dictionary or not last.get("runId") is String or not HeroGuildState.number(last.get("associationCoins"),0,1.0e15,true): return false
	return true

func _valid_statistics(value: Dictionary) -> bool:
	if not _valid_summary(value): return false
	for key in ["byCharacter","byMap"]:
		if not value.get(key) is Dictionary: return false
		for summary in value[key].values():
			if not summary is Dictionary or not _valid_summary(summary): return false
	return true

func _valid_summary(value: Dictionary) -> bool:
	for key in ["runs","clears","kills","bestWave"]:
		if not HeroGuildState.number(value.get(key),0,1.0e15,true): return false
	return HeroGuildState.number(value.get("bestTime"))

func _valid_stones(value: Variant) -> bool:
	if not value is Dictionary: return false
	for grade in ["low","mid","high"]:
		if not HeroGuildState.number(value.get(grade),0,1.0e15,true): return false
	return true

func _migrate(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("meta") is Dictionary: return {}
	if not HeroGuildState.number(value.get("formatVersion"),1,FORMAT_VERSION,true): return {}
	var migrated: Dictionary = value.duplicate(true)
	_retire_character(migrated.meta)
	if not _valid_meta(migrated.meta,int(migrated.formatVersion) < FORMAT_VERSION): return {}
	var version := int(migrated.formatVersion)
	while version < FORMAT_VERSION:
		if version == 1:
			# Reset only the old guild; association, growth and account progress survive.
			migrated.meta.guild = HeroGuildState.create(Content.data,Time.get_unix_time_from_system())
			version = 3
		elif version == 2:
			if not HeroGuildState.valid_legacy_v2(Content.data,migrated.meta.get("guild")): return {}
			var guild: Dictionary = migrated.meta.guild
			var old_capacity := 8 if guild.facilities.office.level >= 3 else 4
			guild.unlockedFloors = maxi(ceili(old_capacity/float(Content.data.guildManagement.balance.roomsPerFloor)),HeroGuildState.eligible_floors(Content.data,int(guild.facilities.office.level)))
			version = 3
		elif version == 3:
			if not HeroGuildState.valid_legacy_v3(Content.data,migrated.meta.get("guild")): return {}
			_migrate_economy(migrated.meta)
			version = 4
		else: return {}
	migrated.formatVersion = version
	return migrated if _valid(migrated) else {}

func _retire_character(value: Dictionary) -> void:
	# Retired content must not invalidate the rest of an existing profile.
	if value.get("characters") is Dictionary: value.characters.erase("yoonHarin")
	var gate: Variant = value.get("gateProgression")
	if gate is Dictionary and gate.get("characters") is Dictionary: gate.characters.erase("yoonHarin")
	var offline: Variant = value.get("offlineReward")
	if offline is Dictionary: _retire_character_rewards(offline.get("pendingRewards"))
	var guild: Variant = value.get("guild")
	if not guild is Dictionary: return
	if guild.get("avatarCharacterId") == "yoonHarin": guild.avatarCharacterId = "awakener"
	if guild.get("productionTargets") is Dictionary and guild.productionTargets.get("characterId") == "yoonHarin": guild.productionTargets.characterId = "awakener"
	if guild.get("characterAffixes") is Dictionary: guild.characterAffixes.erase("yoonHarin")
	if guild.get("pendingAffix") is Dictionary and guild.pendingAffix.get("characterId") == "yoonHarin": guild.pendingAffix = {}
	_retire_character_rewards(guild.get("productionCarry"))
	_retire_character_rewards(guild.get("pendingRewards"))
	if guild.get("jobs") is Array:
		for job in guild.jobs:
			if job is Dictionary: _retire_character_rewards(job.get("rewards"))

func _retire_character_rewards(value: Variant) -> void:
	if value is Dictionary and value.get("characterFragments") is Dictionary: value.characterFragments.erase("yoonHarin")

func _migrate_economy(value: Dictionary) -> void:
	var guild: Dictionary = value.guild
	for key in HeroGuildState.RESOURCES:
		if key in HeroGuildState.LEGACY_RESOURCES: continue
		guild.wallet[key] = 0
		guild.pendingRewards[key] = 0
		for job in guild.jobs:
			if job.has("rewards"): job.rewards[key] = 0
	var offline: Dictionary = value.offlineReward
	for key in HeroGuildState.RESOURCES: offline.pendingRewards[key] = 0
	var last := 0.0
	if not offline.lastExitAt.is_empty(): last = float(Time.get_unix_time_from_datetime_string(offline.lastExitAt))
	offline.lastAccruedAt = last if is_finite(last) and last > 0 else Time.get_unix_time_from_system()
	offline.accumulatedSeconds = 0.0
	offline.rewardedIntervals = 0
	offline.rewardCarry = {}
	value.gateProgression.firstClears = {}
	var completed := 0
	for progress in value.gateProgression.get("characters",{}).values():
		if progress is Dictionary: completed = maxi(completed,int(progress.rewardedThroughDepth))
	var depths: Array = []
	for depth in range(1,completed+1): depths.append(depth)
	if not depths.is_empty(): value.gateProgression.firstClears["seoul"] = depths
	for id in ["vitality","power","mobility","fortune"]:
		if value.association.upgrades.has(id): value.association.upgrades[id] = 0
	if value.statistics.get("lastRun") is Dictionary: value.statistics.lastRun["runId"] = ""

func guild_action(action: String, args: Dictionary = {}) -> bool:
	if not writable: return false
	var accepted := HeroGuildRules.act(Content.data,meta,action,args,Time.get_unix_time_from_system())
	save()
	return accepted

func save() -> bool:
	if not writable: return false
	var now := Time.get_unix_time_from_system()
	HeroMeta.accrue_offline(Content.data,meta,now)
	HeroGuildClock.advance(Content.data,meta,now)
	if not _valid_meta(meta) or not HeroGuildState.valid(Content.data,meta.guild):
		push_error("저장 상태가 잘못되었습니다. 기존 파일을 보존했습니다."); return false
	meta.offlineReward.lastExitAt = Time.get_datetime_string_from_system(true)
	var raw := JSON.stringify({"formatVersion":FORMAT_VERSION,"sourceSaveVersion":Content.data.sourceSaveVersion,"savedAt":Time.get_datetime_string_from_system(true),"meta":meta}, "\t")
	var temp := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if temp == null: push_error("저장 파일을 열 수 없습니다."); return false
	temp.store_string(raw)
	var write_error := temp.get_error()
	temp.close()
	if write_error != OK: push_error("저장 파일을 쓰지 못했습니다: %s" % write_error); return false
	if _rotate_backup and FileAccess.file_exists(SAVE_PATH):
		var backup_error := DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
		if backup_error != OK: push_error("저장 백업을 보존하지 못했습니다: %s" % backup_error); return false
	var error := DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
	if error != OK: push_error("저장을 완료하지 못했습니다: %s" % error); return false
	_rotate_backup = true
	return true

func save_run(run: HeroRun) -> void:
	if not writable or run.settled: return
	var state := {}
	for key in ["run_id","guild_support","setup","phase","previous_phase","wave","elapsed","combat_time","currency","wallet","collected","kills","sequence","player","stats","modifiers","base_modifiers","item_effects","item_state","difficulty","owned","items","enemies","pickups","loot_pickups","loot","bullets","hostile","hazards","structures","pending","pending_branch","item_stock","weapon_stock","item_rerolls","weapon_rerolls","available_weapons","available_items","spawn_state","telemetry"]:
		state[key] = _encode(run.get(key))
	# Enemy VFX identity is transient. Keep the checkpoint's existing bullet shape.
	for bullet: Dictionary in state.hostile: bullet.erase("visualId")
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
	if meta.statistics.get("lastRun",{}).get("runId","") == state.run_id: return null
	# Keep checkpoint inventory, health and earned rewards; only replace its actor.
	if state.get("setup") is Dictionary and state.setup.get("character") == "yoonHarin": state.setup.character = "awakener"
	if not state.has("setup") or not Content.data.characters.has(state.setup.get("character", "")) or not Content.data.maps.has(state.setup.get("map", "")) or not Content.data.weapons.has(state.setup.get("weapon", "")): return null
	if state.get("phase", "") not in ["waveActive","postWave","shop","paused","revivalChoice"]: return null
	var run := HeroRun.new(Content.data, state.setup, meta)
	for key in state: run.set(key, state[key])
	for bullet: Dictionary in run.hostile: bullet["visualId"] = run.next_visual_id()
	if run.phase == "postWave":
		# Recovered stones are already in the wallet; never sweep or pay twice.
		run.phase = "shop"
		HeroShop.refresh(run,true); HeroShop.refresh(run,false)
		HeroShop.grant_supply(run,HeroFeaturedElites.supply_rarities(run,int(run.spawn_state.get("featuredKills",0))))
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
	var stored := _migrate(JSON.parse_string(FileAccess.get_file_as_string(path)))
	if stored.is_empty(): return false
	# Keep the previous profile even after the normal rotating backup advances.
	if FileAccess.file_exists(SAVE_PATH): DirAccess.copy_absolute(SAVE_PATH,"user://before-import-%d.json" % Time.get_unix_time_from_system())
	meta = stored.meta
	HeroMeta.initialize(Content.data,meta)
	HeroMeta.weekly(Content.data,meta,Time.get_unix_time_from_system())
	if not save(): return false
	clear_run()
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
