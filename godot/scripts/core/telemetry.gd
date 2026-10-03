class_name HeroTelemetry
extends RefCounted

static func create() -> Dictionary:
	return {"weapons":{},"waves":{},"enemyKills":{},"purchases":[],"spent":0.0,"walletRecovered":0.0,"damageTaken":0.0,"deathCause":"unknown","fpsTotal":0.0,"fpsSamples":0,"lowFps":0.0}

static func wave(run: HeroRun) -> Dictionary:
	var key := str(run.wave)
	if not run.telemetry.waves.has(key): run.telemetry.waves[key] = {"wave":run.wave,"seconds":0.0,"kills":0,"damageTaken":0.0,"magicStone":0.0,"peakEnemies":0}
	return run.telemetry.waves[key]

static func tick(run: HeroRun) -> void:
	var current := wave(run)
	current.seconds = run.elapsed
	current.peakEnemies = maxi(int(current.peakEnemies),run.enemies.size())

static func hit(run: HeroRun, id: String, damage: float, critical: bool, killed: bool) -> void:
	if not run.telemetry.weapons.has(id): run.telemetry.weapons[id] = {"damage":0.0,"hits":0,"criticals":0,"kills":0}
	var record: Dictionary = run.telemetry.weapons[id]
	record.damage += damage; record.hits += 1
	if critical: record.criticals += 1
	if killed: record.kills += 1

static func death(run: HeroRun, id: String) -> void:
	run.telemetry.enemyKills[id] = run.telemetry.enemyKills.get(id,0) + 1
	wave(run).kills += 1

static func player_hit(run: HeroRun, amount: float, source: String) -> void:
	run.telemetry.damageTaken += amount; wave(run).damageTaken += amount
	run.telemetry.deathCause = source

static func purchase(run: HeroRun, id: String, cost: float, weapon: bool, level: int) -> void:
	run.telemetry.spent += cost
	run.telemetry.purchases.append({"wave":run.wave,"kind":"weapon" if weapon else "item","id":id,"price":cost,"targetLevel":level})

static func fps(run: HeroRun, value: float) -> void:
	if value <= 0: return
	run.telemetry.fpsTotal += value; run.telemetry.fpsSamples += 1
	run.telemetry.lowFps = minf(value,run.telemetry.lowFps) if run.telemetry.lowFps > 0 else value

static func result(run: HeroRun) -> Dictionary:
	var record: Dictionary = run.telemetry.duplicate(true)
	var weapons: Array = []
	for slot in run.owned:
		var summary: Dictionary = record.weapons.get(slot.id,{"damage":0.0,"hits":0,"criticals":0,"kills":0})
		summary.merge({"id":slot.id,"level":slot.level,"branchId":slot.branch})
		weapons.append(summary)
	record.weapons = weapons; record.waves = record.waves.values()
	record.merge({"id":str(Time.get_unix_time_from_system()),"recordedAt":Time.get_datetime_string_from_system(true),"balanceVersion":run.data.balance.version,"characterId":run.setup.character,"startingWeaponId":run.setup.weapon,"mapId":run.setup.map,"gateDepth":run.setup.depth,"weeklyTraitId":run.setup.weekly,"blessingId":run.setup.blessing,"outcome":run.phase,"reachedWave":run.wave,"combatSeconds":run.combat_time,"kills":run.kills,"magicStoneEarned":run.collected,"magicStoneSpent":record.spent,"walletRemaining":run.wallet,"itemRerolls":run.item_rerolls,"weaponRerolls":run.weapon_rerolls,"items":run.items,"averageFps":record.fpsTotal / maxi(1,int(record.fpsSamples))},true)
	record.erase("fpsTotal"); record.erase("fpsSamples")
	return record
