class_name HeroGuildClock
extends RefCounted

const EPSILON := 0.000001

static func busy(g: Dictionary, id: String) -> bool:
	return g.jobs.any(func(job): return id in job.employeeIds)

static func assigned(g: Dictionary, facility: String) -> Array:
	return g.employees.filter(func(e): return e.assignment == facility and g.facilities[facility].level > 0 and not busy(g,e.id)).map(func(e): return e.id)

static func workers(g: Dictionary) -> Array:
	return g.employees.filter(func(e): return e.assignment != "" and g.facilities[e.assignment].level > 0 and not busy(g,e.id))

static func work_bonus(data: Dictionary, g: Dictionary, employee_ids: Array, facility: String) -> float:
	var bonus := 0.0
	var b: Dictionary = data.guildManagement.balance
	for id in employee_ids:
		for e in g.employees:
			if e.id == id: bonus += (e.level-1)*b.staffLevelBonus+(b.staffSpecialtyBonus if data.guildManagement.employees[id].specialty == facility else 0.0)
	return bonus

static func experience(data: Dictionary, e: Dictionary, amount: float) -> void:
	var b: Dictionary = data.guildManagement.balance
	if e.level >= b.maxStaffLevel: return
	e.experience += amount
	while e.level < b.maxStaffLevel and e.experience+EPSILON >= b.staffLevelExperience[int(e.level)-1]:
		e.experience = maxf(0.0,e.experience-b.staffLevelExperience[int(e.level)-1])
		e.level += 1
	if e.level >= b.maxStaffLevel: e.experience = 0.0

static func add_rewards(target: Dictionary, reward: Dictionary) -> void:
	for key in HeroGuildState.RESOURCES: target[key] += reward[key]
	target.supplyTickets = int(target.get("supplyTickets",0)) + int(reward.get("supplyTickets",0))
	for id in reward.blueprintIds:
		if id not in target.blueprintIds: target.blueprintIds.append(id)
	for key in HeroGuildState.FRAGMENTS:
		for id in reward[key]: target[key][id] = target[key].get(id,0)+reward[key][id]
	for grade in reward.revivalStones: target.revivalStones[grade] += reward.revivalStones[grade]

static func _finish(data: Dictionary, g: Dictionary, job: Dictionary) -> void:
	match job.type:
		"construction":
			g.facilities[job.targetId].level = job.targetLevel
			g.facilities[job.targetId].slot = job.slot
			HeroGuildState.sync_unlocked_floors(data,g)
		"research": g.researchLevels[job.targetId] = job.targetLevel
		"itemUpgrade": g.itemLevels[job.targetId] = job.targetLevel
		"recipe":
			if job.targetId not in g.unlockedRecipeIds: g.unlockedRecipeIds.append(job.targetId)
		"training":
			for e in g.employees:
				if e.id == job.targetId: e.level = job.targetLevel; e.experience = 0.0
	if job.has("rewards"): add_rewards(g.pendingRewards,job.rewards)
	if job.type != "training":
		for e in g.employees:
			if e.id in job.employeeIds: experience(data,e,maxf(0.0,job.endsAt-job.startedAt)/3600.0*data.guildManagement.balance.staffExperiencePerHour)

static func _finish_due(data: Dictionary, g: Dictionary, now: float) -> void:
	var due: Array = g.jobs.filter(func(job): return job.endsAt <= now)
	due.sort_custom(func(a,b): return a.endsAt < b.endsAt or (a.endsAt == b.endsAt and int(a.id) < int(b.id)))
	g.jobs = g.jobs.filter(func(job): return job.endsAt > now)
	for job in due: _finish(data,g,job)

static func _produce(data: Dictionary, meta: Dictionary, elapsed: float) -> void:
	if elapsed <= 0: return
	var g: Dictionary = meta.guild
	var b: Dictionary = data.guildManagement.balance
	var level: int = g.facilities.production.level
	var multiplier: float = HeroGuildSupport.effects(data,g).productionMultiplier*(1.0+work_bonus(data,g,assigned(g,"production"),"production"))
	g.productionCarry.coins += elapsed/3600.0*(b.baselineCoinsPerHour+level*b.productionCoinsPerLevelHour*multiplier)
	var coins := floori(g.productionCarry.coins+EPSILON)
	g.productionCarry.coins = maxf(0.0,g.productionCarry.coins-coins)
	g.pendingRewards.coins += coins
	for target in [["character","characterId","characterFragments","characters"],["weapon","weaponId","weaponFragments","sharedWeapons"],["blessing","blessingId","blessingFragments","blessings"]]:
		var id: String = g.productionTargets[target[1]]
		if level < b.productionFragmentUnlockLevels[target[0]]: continue
		if target[0] != "blessing" and meta[target[3]].get(id,{}).get("unlocked",true): continue
		var total: float = g.productionCarry[target[2]].get(id,0.0)+elapsed/3600.0*b.productionFragmentsPerHour*multiplier
		var count := floori(total+EPSILON)
		g.productionCarry[target[2]][id] = maxf(0.0,total-count)
		if count > 0: g.pendingRewards[target[2]][id] = g.pendingRewards[target[2]].get(id,0)+count

# Production storage and wall-clock jobs are independent. Staff work past storage cap.
static func advance(data: Dictionary, meta: Dictionary, now: float) -> bool:
	if not is_finite(now) or now <= 0: return false
	var g: Dictionary = meta.guild
	var floor_changed := HeroGuildState.sync_unlocked_floors(data,g)
	if now < g.lastAdvancedAt: return floor_changed
	if g.lastAdvancedAt <= 0: g.lastAdvancedAt = now; _finish_due(data,g,now); return true
	if now == g.lastAdvancedAt:
		if not g.jobs.any(func(job): return job.endsAt <= now): return floor_changed
		_finish_due(data,g,now); return true
	var cursor: float = g.lastAdvancedAt
	_finish_due(data,g,cursor)
	while cursor < now:
		var next: float = now
		for job in g.jobs:
			if job.endsAt > cursor: next = minf(next,job.endsAt)
		var active := workers(g)
		for e in active:
			if e.level >= data.guildManagement.balance.maxStaffLevel: continue
			var until_level: float = maxf(EPSILON,data.guildManagement.balance.staffLevelExperience[int(e.level)-1]-e.experience)/data.guildManagement.balance.staffExperiencePerHour*3600.0
			next = minf(next,cursor+until_level)
		var elapsed := minf(next-cursor,maxf(0.0,HeroGuildSupport.effects(data,g).offlineCapHours*3600.0-g.productionAccumulated))
		_produce(data,meta,elapsed)
		for e in active: experience(data,e,(next-cursor)/3600.0*data.guildManagement.balance.staffExperiencePerHour)
		g.productionAccumulated += elapsed
		cursor = next
		_finish_due(data,g,cursor)
	g.lastAdvancedAt = now
	return true
