class_name HeroStats
extends RefCounted

static func calculate(base: Dictionary, modifiers: Array, rules: Dictionary) -> Dictionary:
	var stats := base.duplicate(true)
	for key in base:
		var flat := 0.0
		var bonus := 0.0
		for modifier in modifiers:
			if modifier.stat != key: continue
			if modifier.operation == "add": flat += float(modifier.value)
			else: bonus += maxf(0.0, float(modifier.value)) - 1.0
		stats[key] = clampf(float(base[key]) + flat + float(base[key]) * bonus, 0.0, rules.maximumStat)
	stats.maxHp = maxf(1.0, stats.maxHp)
	stats.attackSpeed = clampf(stats.attackSpeed, rules.minimumAttackSpeed, rules.maximumAttackSpeed)
	stats.criticalChance = minf(1.0, stats.criticalChance)
	stats.criticalDamage = maxf(1.0, stats.criticalDamage)
	stats.dodge = minf(stats.dodge, rules.dodgeCap)
	stats.lifesteal = minf(stats.lifesteal, rules.lifestealRateCap)
	return stats

static func resolve_weapon(definition: Dictionary, owned: Dictionary, stats: Dictionary, effects: Array, config: Dictionary, character_trait: Dictionary) -> Dictionary:
	var result: Dictionary = definition.base.duplicate(true)
	for i in range(mini(int(owned.level) - 1, definition.levels.size())):
		result.merge(definition.levels[i], true)
	for branch in definition.branches:
		if branch.id != owned.get("branch", ""): continue
		for i in range(mini(int(owned.level) - int(definition.branchAtLevel) + 1, branch.levels.size())):
			result.merge(branch.levels[i], true)
	var caps: Array = definition.capabilities
	var trait_matches: bool = (not character_trait.has("weaponFamily") or character_trait.weaponFamily == definition.get("family", "")) and (not character_trait.has("weaponCapability") or character_trait.weaponCapability in caps)
	var character_bonus: float = character_trait.get("weaponDamageBonus", 0.0) if trait_matches else 0.0
	var bonus: float = stats.damage - 1.0 + character_bonus
	if "MELEE" in caps: bonus += stats.meleeDamage - 1.0
	if "RANGED" in caps: bonus += stats.rangedDamage - 1.0
	result.damage = maxf(0.0, roundf(result.damage * maxf(0.0, 1.0 + bonus) * config.playerDamageMultiplier))
	result.cooldown = maxf(0.05, result.cooldown / stats.attackSpeed)
	result.range *= stats.range if "HAS_RANGE" in caps else 1.0
	result.duration *= stats.duration if "DURATION" in caps else 1.0
	result.projectileSpeed *= stats.projectileSpeed if "PROJECTILE" in caps else 1.0
	result["areaScale"] = (stats.area if "AREA" in caps else 1.0) * result.get("areaMultiplier", 1.0)
	result.projectileRadius *= result.areaScale
	result["blastRadius"] = result.get("blastRadius", definition.get("blastRadius", 100.0)) * (stats.area if "AREA" in caps else 1.0)
	result["attackAngle"] = result.get("attackAngle", definition.get("attackAngle", PI))
	result["chainRange"] = definition.get("chainRange", 200.0) * (stats.range if "HAS_RANGE" in caps else 1.0)
	result["criticalChance"] = stats.criticalChance if "CAN_CRIT" in caps else 0.0
	result["criticalDamage"] = stats.criticalDamage
	var indirect: bool = "STRUCTURE" in caps or "SUMMON" in caps
	var allow_indirect := false
	for effect in effects:
		if effect.type == "indirectLifesteal": allow_indirect = true
		if effect.type == "projectileCount" and effect.tag in caps: result.projectileCount += effect.value
	result["lifesteal"] = stats.lifesteal if not indirect or allow_indirect else 0.0
	result["repeatCount"] = result.get("repeatCount", 1)
	result["repeatInterval"] = result.get("repeatInterval", 0.15)
	result["explosionDelay"] = result.get("explosionDelay", 0.0)
	return result

static func item_modifiers(items: Dictionary, owned: Dictionary) -> Array:
	var result: Array = []
	for id in owned:
		for i in range(int(owned[id])):
			result.append_array(items[id].statModifiers)
	return result

static func difficulty(data: Dictionary, depth: int, map: Dictionary, weekly: String) -> Dictionary:
	var c: Dictionary = data.gate
	var offset := maxi(0, depth - 1)
	var result := {"hp":1.0 + offset * c.hpPerDepth,"damage":1.0 + offset * c.damagePerDepth,"speed":minf(c.speedMultiplierCap,1.0 + offset * c.speedPerDepth),"spawn":1.0 + offset * c.spawnPerDepth,"reward":1.0,"eliteChance":minf(c.eliteChanceCap,offset * c.eliteChancePerDepth),"eliteModifiers":[]}
	for milestone in data.milestones:
		if milestone.depth > depth: continue
		result.spawn *= milestone.get("spawnMultiplier", 1.0)
		for id in milestone.get("eliteModifiers", []):
			if id not in result.eliteModifiers: result.eliteModifiers.append(id)
	result.spawn = minf(c.spawnMultiplierCap, result.spawn)
	var balance: Dictionary = map.get("balanceModifiers", {})
	for pair in [["hp","enemyHp"],["damage","enemyDamage"],["speed","enemySpeed"],["spawn","spawnDensity"],["reward","rewards"]]:
		result[pair[0]] *= balance.get(pair[1], 1.0)
	var penalty: Dictionary = data.weeklyRules.get(weekly, {}).get("penalty", {})
	for pair in [["hp","enemyHp"],["damage","enemyDamage"],["speed","enemySpeed"],["spawn","spawn"]]:
		result[pair[0]] *= penalty.get(pair[1], 1.0)
	result.eliteChance = minf(0.75, result.eliteChance + penalty.get("eliteChance", 0.0))
	return result
