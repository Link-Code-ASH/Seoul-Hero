class_name HeroGuildSupport
extends RefCounted

static func empty() -> Dictionary:
	return {"itemLevels":{},"weaponDamageMultipliers":{},"excludedWeaponIds":[],"excludedItemIds":[],"unlockedRecipeIds":[],"firstClearMultiplier":1.0}

static func effects(data: Dictionary, g: Dictionary) -> Dictionary:
	var b: Dictionary = data.guildManagement.benefits
	var recovery_bonus := HeroGuildClock.work_bonus(data,g,HeroGuildClock.assigned(g,"recovery"),"recovery")
	var capacity := research(g,"offlineCapacity","recovery")
	var purity := research(g,"stonePurity","revival")
	var exclusions := research(g,"shopExclusions","workshop")
	return {"offlineYieldMultiplier":1.0+b.offlineYieldPerLevel*research(g,"offlineYield","recovery")+maxi(0,int(g.facilities.recovery.level)-1)*b.recoveryYieldPerFacilityLevel+recovery_bonus,"offlineCapHours":b.offlineCapHours[capacity],"expeditionRarityBonus":b.expeditionRarityPerLevel*research(g,"expeditionRarity","expedition")+maxi(0,int(g.facilities.expedition.level)-1)*b.expeditionRarityPerFacilityLevel,"expeditionTeams":b.expeditionTeamsByLevel[research(g,"expeditionTeams","expedition")],"expeditionPartySize":b.expeditionPartyByLevel[research(g,"expeditionParty","expedition")],"productionMultiplier":1.0+b.productionPerLevel*research(g,"productionEfficiency","production"),"stoneCostMultiplier":1.0-b.stoneEfficiencyPerLevel*research(g,"stoneEfficiency","revival"),"stoneMidChance":b.stoneMidBase+b.stoneMidPerLevel*purity,"stoneHighChance":b.stoneHighBase+b.stoneHighPerLevel*purity,"canSynthesizeStones":research(g,"stoneSynthesis","revival")>0,"weaponExclusionSlots":b.weaponExclusionsByLevel[exclusions],"itemExclusionSlots":b.itemExclusionsByLevel[exclusions],"firstClearMultiplier":1.0+b.firstClearPerLevel*research(g,"firstClearBonus","research")}

static func research(g: Dictionary, id: String, facility: String) -> int:
	return clampi(int(g.researchLevels.get(id,0)),0,5) if g.facilities[facility].level > 0 else 0

static func snapshot(data: Dictionary, meta: Dictionary) -> Dictionary:
	var g: Dictionary = meta.guild
	var result := empty()
	var e := effects(data,g)
	if g.facilities.workshop.level > 0:
		result.itemLevels = g.itemLevels.duplicate(true)
		result.unlockedRecipeIds = g.unlockedRecipeIds.duplicate()
	result.excludedWeaponIds = g.excludedWeaponIds.slice(0,int(e.weaponExclusionSlots))
	result.excludedItemIds = g.excludedItemIds.slice(0,int(e.itemExclusionSlots))
	result.firstClearMultiplier = e.firstClearMultiplier
	# Weapons have no permanent levels: fragments only unlock new weapons.
	return result

static func character_modifiers(data: Dictionary, meta: Dictionary, id: String) -> Array:
	var result: Array = []
	# Characters differ by traits only; there is no per-character breakthrough power.
	if meta.guild.facilities.analysis.level > 0 and meta.guild.characterAffixes.has(id): result.append(meta.guild.characterAffixes[id].duplicate(true))
	return result

static func item_modifiers(data: Dictionary, items: Dictionary, support: Dictionary) -> Array:
	var result: Array = []
	for id in items:
		var boost: float = 1.0+clampi(int(support.itemLevels.get(id,0)),0,5)*data.guildManagement.benefits.itemStrengthPerLevel
		for i in range(int(items[id])):
			for authored in data.items[id].statModifiers:
				var modifier: Dictionary = authored.duplicate(true)
				# Curves affect positive numeric stats, never penalties or special counts.
				if modifier.stat != "curse":
					if modifier.operation == "multiply" and modifier.value > 1.0: modifier.value = 1.0+(modifier.value-1.0)*boost
					elif modifier.operation == "add" and modifier.value > 0.0: modifier.value *= boost
				result.append(modifier)
	return result

static func valid(data: Dictionary, support: Variant) -> bool:
	if not support is Dictionary: return false
	var b: Dictionary = data.guildManagement.benefits
	return HeroGuildState.amounts(support.get("itemLevels"),data.items,5) and HeroGuildState.amounts(support.get("weaponDamageMultipliers"),data.weapons,1.0+5*b.weaponDamagePerLevel,false) and HeroGuildState.ids(support.get("excludedWeaponIds"),data.weapons,2) and HeroGuildState.ids(support.get("excludedItemIds"),data.items,4) and HeroGuildState.ids(support.get("unlockedRecipeIds"),data.guildManagement.recipes) and HeroGuildState.number(support.get("firstClearMultiplier"),1.0,1.0+5*b.firstClearPerLevel)
