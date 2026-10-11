extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	_check.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _meta() -> Dictionary:
	var value: Dictionary = Content.data.defaultMeta.duplicate(true)
	value.guild = HeroGuildState.create(Content.data,1000.0)
	return value

func _job(target: String, slot: int, level: int = 1) -> Dictionary:
	return {"id":"17","type":"construction","targetId":target,"slot":slot,"targetLevel":level,"startedAt":900.25,"endsAt":4600.75,"employeeIds":[]}

func _legacy(office_level: int, built_slot: int, job_slot: int) -> Dictionary:
	var value := _meta()
	var guild: Dictionary = value.guild
	guild.erase("unlockedFloors")
	guild.facilities.office.level = office_level
	guild.facilities.research = {"level":1,"slot":built_slot}
	guild.employees[0].assignment = "research"
	guild.employees[0].experience = 7.25
	guild.jobs = [_job("production",job_slot)]
	guild.nextJobId = 18
	guild.pendingRewards.materials = 29
	guild.productionCarry.coins = 0.375
	guild.productionAccumulated = 73.5
	guild.extraPreservedField = {"notes":["keep",34],"stamp":123.5}
	value.wallet.associationCoins = 987
	value.association.upgrades = {"vitality":2}
	return {"formatVersion":2,"savedAt":"2026-10-05T00:00:00Z","sourceSaveVersion":Content.data.sourceSaveVersion,"meta":value}

func _check_migration(old: Dictionary, expected_floors: int) -> void:
	var input_copy: Dictionary = old.duplicate(true)
	var migrated: Dictionary = Profile._migrate(old)
	expect(not migrated.is_empty(),"valid v2 profile accepted")
	if migrated.is_empty(): return
	expect(migrated.formatVersion == 3 and migrated.meta.guild.unlockedFloors == expected_floors,"v2 capacity preserved as whole floors")
	expect(HeroGuildState.valid(Content.data,migrated.meta.guild),"migrated profile validates under v3")
	var restored: Dictionary = migrated.duplicate(true)
	restored.formatVersion = 2
	restored.meta.guild.erase("unlockedFloors")
	expect(restored == input_copy,"all preexisting fields, slots, rewards and work timestamps preserved")
	expect(old == input_copy,"migration never mutates its input")

func _check() -> void:
	if "--guild-floor-save-check" not in OS.get_cmdline_user_args():
		push_error("Run with -- --ui-preview --guild-floor-save-check to avoid user file access.")
		get_tree().quit(1)
		return
	var data: Dictionary = Content.data
	var fresh := _meta()
	expect(not Profile.writable,"memory verification disables profile writes")
	expect(fresh.guild.unlockedFloors == 1 and HeroGuildRules.rooms(data,fresh.guild) == 3 and HeroGuildState.valid(data,fresh.guild),"new guild starts with one valid three-room floor")
	var v1: Dictionary = data.defaultMeta.duplicate(true)
	v1.wallet.associationCoins = 654
	var migrated_v1: Dictionary = Profile._migrate({"formatVersion":1,"meta":v1})
	expect(not migrated_v1.is_empty() and migrated_v1.formatVersion == 3 and migrated_v1.meta.guild.unlockedFloors == 1,"v1 replacement guild does not receive v2 grandfather floors")
	expect(not migrated_v1.is_empty() and migrated_v1.meta.wallet.associationCoins == 654,"v1 non-guild progress survives")
	_check_migration(_legacy(1,3,2),2)
	_check_migration(_legacy(1,1,3),2)
	_check_migration(_legacy(3,7,6),3)
	var v3 := _meta()
	v3.guild.facilities.office.level = 3
	v3.guild.unlockedFloors = 3
	v3.guild.facilities.research = {"level":1,"slot":8}
	expect(HeroGuildState.valid(data,v3.guild),"v3 built facility can occupy slot 8")
	v3.guild.facilities.research = {"level":0,"slot":-1}
	v3.guild.jobs = [_job("research",8)]
	expect(HeroGuildState.valid(data,v3.guild),"v3 construction can reserve slot 8")
	expect(Profile._valid(JSON.parse_string(JSON.stringify({"formatVersion":3,"meta":v3}))),"v3 JSON profile round trip validates")
	var invalid := _legacy(3,8,6)
	expect(Profile._migrate(invalid).is_empty(),"v2 rejects built slot 8 under old maximum")
	invalid = _legacy(3,7,8)
	expect(Profile._migrate(invalid).is_empty(),"v2 rejects construction slot 8 under old capacity")
	invalid = _legacy(1,1,3)
	invalid.meta.guild.jobs[0].endsAt = 1.0
	expect(Profile._migrate(invalid).is_empty(),"corrupt v2 work timestamp rejected before migration")
	expect(Profile._migrate({"formatVersion":4,"meta":v3}).is_empty(),"future profile rejected")
	fresh.guild.facilities.office.level = 2
	expect(HeroGuildClock.advance(data,fresh,1000.0) and fresh.guild.unlockedFloors == 2,"same timestamp persists newly eligible floor")
	fresh.guild.facilities.office.level = 3
	expect(HeroGuildClock.advance(data,fresh,999.0) and fresh.guild.unlockedFloors == 3 and fresh.guild.lastAdvancedAt == 1000.0,"backward timestamp syncs floor without rewinding clock")
	fresh.guild.facilities.office.level = 1
	expect(not HeroGuildState.sync_unlocked_floors(data,fresh.guild) and fresh.guild.unlockedFloors == 3,"unlocked floor count never decreases")
	fresh = _meta()
	fresh.guild.jobs = [_job("office",0,2)]
	fresh.guild.jobs[0].endsAt = 1000.0
	expect(HeroGuildClock.advance(data,fresh,1000.0) and fresh.guild.facilities.office.level == 2 and fresh.guild.unlockedFloors == 2,"office construction completion immediately opens next floor")
	var extended: Dictionary = data.duplicate(true)
	extended.guildManagement.balance.floorUnlockOfficeLevels.append(4)
	fresh.guild.facilities.office.level = 4
	expect(HeroGuildState.valid(extended,fresh.guild) and HeroGuildState.sync_unlocked_floors(extended,fresh.guild) and HeroGuildRules.rooms(extended,fresh.guild) == 12,"future floor data loads older v3 state and grows capacity")
	print("Guild floor migration checks: ",checks,"; failures: ",failures,"; user profile reads/writes: false")
	get_tree().quit(1 if failures > 0 else 0)
