class_name HeroGuildState
extends RefCounted

const LEGACY_RESOURCES := ["coins","materials","researchData","speedupTickets"]
const RESOURCES := ["coins","materials","researchData","speedupTickets","constructionParts","electronicParts","manaCatalysts","bioReagents"]
const FRAGMENTS := {"characterFragments":"characters","weaponFragments":"sharedWeapons","blessingFragments":"blessings"}
const JOB_TYPES := ["construction","research","expedition","training","manufacture","itemUpgrade","recipe"]

static func rewards() -> Dictionary:
	return {"coins":0,"materials":0,"researchData":0,"speedupTickets":0,"constructionParts":0,"electronicParts":0,"manaCatalysts":0,"bioReagents":0,"supplyTickets":0,"blueprintIds":[],"characterFragments":{},"weaponFragments":{},"blessingFragments":{},"revivalStones":{"low":0,"mid":0,"high":0}}

static func create(data: Dictionary, now: float) -> Dictionary:
	var config: Dictionary = data.guildManagement
	var facilities := {}
	for id in config.facilities: facilities[id] = {"level":1 if id == "office" else 0,"slot":0 if id == "office" else -1}
	var employees: Array = []
	for id in config.initialEmployees: employees.append({"id":id,"level":1,"experience":0.0,"assignment":""})
	return {"wallet":config.initialWallet.duplicate(true),"facilities":facilities,"unlockedFloors":1,"employees":employees,"jobs":[],"researchLevels":{},"itemLevels":{},"blueprints":[],"unlockedRecipeIds":[],"excludedWeaponIds":[],"excludedItemIds":[],"productionTargets":{"characterId":"awakener","weaponId":"manaBolt","blessingId":data.blessings.keys()[0]},"productionCarry":{"coins":0.0,"characterFragments":{},"weaponFragments":{},"blessingFragments":{}},"productionAccumulated":0.0,"pendingRewards":rewards(),"characterAffixes":{},"pendingAffix":{},"lastAdvancedAt":maxf(0.0,now),"nextJobId":1}

static func eligible_floors(data: Dictionary, office_level: int) -> int:
	var levels: Array = data.guildManagement.balance.floorUnlockOfficeLevels
	var count := 1
	for index in levels.size():
		if office_level < int(levels[index]): break
		count = index+1
	return count

static func floors(data: Dictionary, g: Dictionary) -> int:
	var level: int = g.get("facilities",{}).get("office",{}).get("level",1)
	return maxi(int(g.get("unlockedFloors",1)),eligible_floors(data,level))

static func room_count(data: Dictionary, g: Dictionary) -> int:
	return floors(data,g)*int(data.guildManagement.balance.roomsPerFloor)

static func sync_unlocked_floors(data: Dictionary, g: Dictionary) -> bool:
	var unlocked := floors(data,g)
	if int(g.get("unlockedFloors",0)) >= unlocked: return false
	g.unlockedFloors = unlocked
	return true

static func number(value: Variant, low: float = 0.0, high: float = 1.0e15, whole: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high and (not whole or value == floor(value))

static func ids(value: Variant, known: Dictionary, limit: int = 100) -> bool:
	if not value is Array or value.size() > limit: return false
	var seen := {}
	for id in value:
		if not id is String or not known.has(id) or seen.has(id): return false
		seen[id] = true
	return true

static func amounts(value: Variant, known: Dictionary, high: float = 1.0e15, whole: bool = true) -> bool:
	if not value is Dictionary: return false
	for id in value:
		if not known.has(id) or not number(value[id],0,high,whole): return false
	return true

static func valid_rewards(data: Dictionary, value: Variant, legacy: bool = false) -> bool:
	if not value is Dictionary: return false
	for key in LEGACY_RESOURCES if legacy else RESOURCES:
		if not number(value.get(key),0,1.0e15,true): return false
	# Association supply tickets were added to guild rewards later; older saves omit them.
	if value.has("supplyTickets") and not number(value.supplyTickets,0,1.0e15,true): return false
	if not ids(value.get("blueprintIds"),data.guildManagement.recipes): return false
	for key in FRAGMENTS:
		var known: Dictionary = data[{"characterFragments":"characters","weaponFragments":"weapons","blessingFragments":"blessings"}[key]]
		if not amounts(value.get(key),known): return false
	if not value.get("revivalStones") is Dictionary: return false
	for grade in ["low","mid","high"]:
		if not number(value.revivalStones.get(grade),0,1.0e15,true): return false
	return true

static func valid_affix(data: Dictionary, value: Variant) -> bool:
	if not value is Dictionary: return false
	for option in data.guildManagement.affixPool:
		if value.get("stat") == option.stat and value.get("operation") == option.operation:
			return number(value.get("value"),option.min,option.max)
	return false

static func valid(data: Dictionary, g: Variant) -> bool:
	return _valid(data,g,0)

# Validate v2 before converting capacities, including unfinished construction.
static func valid_legacy_v2(data: Dictionary, g: Variant) -> bool:
	return _valid(data,g,2)

static func valid_legacy_v3(data: Dictionary, g: Variant) -> bool:
	return _valid(data,g,3)

static func _valid(data: Dictionary, g: Variant, legacy_version: int) -> bool:
	if not g is Dictionary: return false
	var legacy_v2 := legacy_version == 2
	var legacy_resources := legacy_version > 0
	var config: Dictionary = data.guildManagement
	if not legacy_v2 and not number(g.get("unlockedFloors"),1,config.balance.floorUnlockOfficeLevels.size(),true): return false
	for key in ["wallet","facilities","researchLevels","itemLevels","productionTargets","productionCarry","characterAffixes","pendingAffix"]:
		if not g.get(key) is Dictionary: return false
	for key in LEGACY_RESOURCES if legacy_resources else RESOURCES:
		if not number(g.wallet.get(key),0,1.0e15,true): return false
	if not number(g.get("lastAdvancedAt")) or not number(g.get("productionAccumulated"),0,config.balance.offlineHoursMax*3600.0) or not number(g.get("nextJobId"),1,1.0e15,true): return false
	var occupied := {}
	var maximum_slot: int = 7 if legacy_v2 else config.balance.floorUnlockOfficeLevels.size()*int(config.balance.roomsPerFloor)-1
	for id in config.facilities:
		var f: Variant = g.facilities.get(id)
		if not f is Dictionary or not number(f.get("level"),1 if id == "office" else 0,10,true) or not number(f.get("slot"),-1,maximum_slot,true): return false
		if f.level == 0:
			if f.slot != -1: return false
		else:
			if f.slot < 0 or occupied.has(f.slot): return false
			occupied[f.slot] = id
	if g.facilities.office.slot != 0: return false
	var capacity: int = (8 if g.facilities.office.level >= 3 else 4) if legacy_v2 else room_count(data,g)
	for id in config.facilities:
		if g.facilities[id].level > g.facilities.office.level or g.facilities[id].slot >= capacity: return false
	if not amounts(g.researchLevels,config.research,5) or not amounts(g.itemLevels,data.items,5): return false
	for pair in [["blueprints",config.recipes,100],["unlockedRecipeIds",config.recipes,100],["excludedWeaponIds",data.weapons,2],["excludedItemIds",data.items,4]]:
		if not ids(g.get(pair[0]),pair[1],pair[2]): return false
	for pair in [["characterId",data.characters],["weaponId",data.weapons],["blessingId",data.blessings]]:
		if not pair[1].has(g.productionTargets.get(pair[0],"")): return false
	if not number(g.productionCarry.get("coins"),0,1): return false
	for key in FRAGMENTS:
		if not amounts(g.productionCarry.get(key),data[{"characterFragments":"characters","weaponFragments":"weapons","blessingFragments":"blessings"}[key]],1,false): return false
	if not valid_rewards(data,g.get("pendingRewards"),legacy_resources) or not g.get("employees") is Array or not g.get("jobs") is Array: return false
	var staff := {}
	for e in g.employees:
		if not e is Dictionary or not config.employees.has(e.get("id","")) or staff.has(e.id) or not number(e.get("level"),1,5,true) or not number(e.get("experience"),0,160): return false
		if not e.get("assignment") is String or (e.assignment != "" and not config.facilities.has(e.assignment)): return false
		if e.assignment != "" and g.facilities[e.assignment].level == 0: return false
		if e.level < 5 and e.experience >= config.balance.staffLevelExperience[int(e.level)-1]: return false
		if e.level == 5 and e.experience != 0: return false
		staff[e.id] = e
	if staff.size() > mini(config.employees.size(),2+(int(g.facilities.office.level)-1)*2): return false
	var reserved := {}; var jobs := {}; var lanes := {}; var targets := {}
	for job in g.jobs:
		if not job is Dictionary or not job.get("id") is String or jobs.has(job.id) or job.get("type") not in JOB_TYPES: return false
		if not number(job.get("startedAt")) or not number(job.get("endsAt")) or job.endsAt < job.startedAt or not ids(job.get("employeeIds"),staff): return false
		jobs[job.id] = true
		for id in job.employeeIds:
			if reserved.has(id): return false
			reserved[id] = true
		var lane: String = "research" if job.type == "recipe" else job.type
		lanes[lane] = lanes.get(lane,0)+1
		var target: String = str(job.get("targetId",""))
		var key: String = lane+":"+target
		if targets.has(key): return false
		targets[key] = true
		var known: Dictionary = {"construction":config.facilities,"research":config.research,"expedition":config.expeditions,"training":staff,"manufacture":data.revivalStones,"itemUpgrade":data.items,"recipe":config.recipes}[job.type]
		if not known.has(target): return false
		if job.type in ["construction","research","training","itemUpgrade"]:
			if not number(job.get("targetLevel"),1,10 if job.type == "construction" else 5,true): return false
		if job.type == "construction":
			if not number(job.get("slot"),0,capacity-1,true): return false
			if occupied.has(job.slot) and occupied[job.slot] != target: return false
			if int(job.targetLevel) != int(g.facilities[target].level)+1: return false
			if target != "office" and job.targetLevel > g.facilities.office.level: return false
			occupied[job.slot] = target
		if job.type in ["research","recipe","training"] and job.employeeIds.size() != 1: return false
		if job.type == "expedition" and job.employeeIds.size() not in [1,2,3]: return false
		if job.type in ["expedition","manufacture"] and not valid_rewards(data,job.get("rewards"),legacy_resources): return false
	if lanes.get("construction",0) > (2 if g.facilities.office.level >= 4 else 1) or lanes.get("research",0) > 1 or lanes.get("expedition",0) > 3 or lanes.get("manufacture",0) > 1 or lanes.get("itemUpgrade",0) > 1: return false
	for id in g.characterAffixes:
		if not data.characters.has(id) or not valid_affix(data,g.characterAffixes[id]): return false
	if not g.pendingAffix.is_empty() and (not data.characters.has(g.pendingAffix.get("characterId","")) or not valid_affix(data,g.pendingAffix.get("option"))): return false
	return true
