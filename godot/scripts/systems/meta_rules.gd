class_name HeroMeta
extends RefCounted

static func initialize(data: Dictionary, meta: Dictionary) -> void:
	for id in data.characters:
		if not meta.characters.has(id): meta.characters[id] = {"unlocked":data.defaultMeta.characters.get(id,{}).get("unlocked",false),"fragments":0,"breakthrough":0}
	for id in data.weapons:
		if not meta.sharedWeapons.has(id): meta.sharedWeapons[id] = {"unlocked":not data.weapons[id].get("requiresUnlock", false),"fragments":0,"level":0}
	for id in data.blessings:
		if not meta.blessings.has(id): meta.blessings[id] = {"unlocked":false,"fragments":0,"level":0}

static func weekly(data: Dictionary, meta: Dictionary, now: float) -> void:
	# Sunday 05:00 KST = Saturday 20:00 UTC. Unix epoch's first boundary was Jan 3.
	var week_key := str(floori((now - 244800.0) / 604800.0))
	if meta.weeklyGate.weekKey == week_key and data.weeklyRules.has(meta.weeklyGate.ruleId): return
	var pool: Array = meta.weeklyGate.remainingRuleIds.filter(func(id): return data.weeklyRules.has(id))
	if pool.is_empty(): pool = data.weeklyRules.keys()
	pool.shuffle()
	meta.weeklyGate.ruleId = pool.pop_back()
	meta.weeklyGate.remainingRuleIds = pool
	meta.weeklyGate.weekKey = week_key

static func modifiers(data: Dictionary, meta: Dictionary, setup: Dictionary) -> Array:
	var result: Array = []
	var training: int = meta.guild.facilityLevels.get("training", 0)
	if training > 0: result.append({"stat":"maxHp","operation":"multiply","value":1.0 + training * 0.02})
	for id in meta.association.upgrades:
		if not data.upgrades.has(id): continue
		var upgrade: Dictionary = data.upgrades[id]
		var effect: Dictionary = upgrade.effect
		if effect.type == "stat": result.append({"stat":effect.stat,"operation":effect.operation,"value":effect.value * meta.association.upgrades[id] + (1.0 if effect.operation == "multiply" else 0.0)})
	result.append_array(data.weeklyRules.get(setup.weekly, {}).get("benefit", []))
	var blessing_id: String = setup.get("blessing", "")
	var progress: Dictionary = meta.blessings.get(blessing_id, {})
	if progress.get("unlocked", false):
		for effect in data.blessings[blessing_id].modifiers:
			result.append({"stat":effect.stat,"operation":effect.operation,"value":1.0 + (effect.value - 1.0) * progress.level if effect.operation == "multiply" else effect.value * progress.level})
	return result

static func association_cost(data: Dictionary, meta: Dictionary, id: String) -> int:
	var upgrade: Dictionary = data.upgrades[id]
	var level: int = meta.association.upgrades.get(id, 0)
	return -1 if level >= int(upgrade.maxLevel) else ceili(upgrade.baseCost * pow(upgrade.costGrowth, level))

static func buy_association(data: Dictionary, meta: Dictionary, id: String) -> bool:
	if not data.upgrades.has(id): return false
	var cost := association_cost(data, meta, id)
	if cost < 0 or meta.wallet.associationCoins < cost: return false
	var effect: Dictionary = data.upgrades[id].effect
	if effect.type == "unlock":
		match effect.target:
			"character":
				if meta.characters[effect.contentId].unlocked: return false
				meta.characters[effect.contentId].unlocked = true
			"weapon":
				if meta.sharedWeapons[effect.contentId].unlocked: return false
				meta.sharedWeapons[effect.contentId].unlocked = true
			_:
				var key: String = {"item":"unlockedItemIds","stage":"unlockedMapIds","feature":"unlockedFeatureIds"}[effect.target]
				if effect.contentId in meta.account[key]: return false
				meta.account[key].append(effect.contentId)
	meta.wallet.associationCoins -= cost
	meta.association.upgrades[id] = meta.association.upgrades.get(id, 0) + 1
	return true

static func grow(data: Dictionary, meta: Dictionary, kind: String, id: String) -> bool:
	var collection: Dictionary = meta[{"character":"characters","weapon":"sharedWeapons","blessing":"blessings"}[kind]]
	if not collection.has(id): return false
	var progress: Dictionary = collection[id]
	var level_key := "breakthrough" if kind == "character" else "level"
	var level: int = progress[level_key]
	if level >= int(data.growth.maxLevel): return false
	if kind != "blessing" and not progress.unlocked: return false
	var costs: Array = data.growth[{"character":"characterCosts","weapon":"weaponCosts","blessing":"blessingCosts"}[kind]]
	var cost: int = costs[level]
	if progress.fragments < cost: return false
	progress.fragments -= cost
	progress[level_key] = level + 1
	if kind == "blessing": progress.unlocked = true
	return true

static func weighted(entries: Array) -> Dictionary:
	var total := 0.0
	for entry in entries: total += entry.weight
	var roll := randf() * total
	for entry in entries:
		roll -= entry.weight
		if roll < 0: return entry
	return entries.back()

static func grant(data: Dictionary, meta: Dictionary, reward: Dictionary) -> void:
	match reward.type:
		"associationCoin": meta.wallet.associationCoins += reward.amount
		"supplyTicket": meta.wallet.supplyTickets += reward.amount
		"revivalStone": meta.wallet.revivalStones[reward.contentId] += reward.amount
		_:
			var key: String = {"weaponFragment":"sharedWeapons","characterFragment":"characters","blessingFragment":"blessings"}.get(reward.type, "")
			if not key.is_empty() and meta[key].has(reward.contentId): meta[key][reward.contentId].fragments += reward.amount

static func fragment(data: Dictionary, kind: String, amount: int) -> Dictionary:
	var content: Dictionary = data[{"weaponFragment":"weapons","characterFragment":"characters","blessingFragment":"blessings"}[kind]]
	return {"type":kind,"contentId":content.keys().pick_random(),"amount":amount}

static func open_supply(data: Dictionary, meta: Dictionary, count: int) -> Array:
	if count not in [1,10] or meta.wallet.supplyTickets < count * data.supply.ticketCost: return []
	meta.wallet.supplyTickets -= count * data.supply.ticketCost
	var record: Dictionary = meta.supply.boxes.get(data.supply.id, {"opened":0,"pity":0})
	var results: Array = []
	for i in range(count):
		var coins := {"type":"associationCoin","contentId":"","amount":weighted(data.supply.coinAmounts).amount + meta.guild.facilityLevels.supply}
		results.append(coins)
		grant(data, meta, coins)
		var got_fragment := false
		for bonus in data.supply.bonusRewards:
			if randf() >= bonus.chance: continue
			var amount := randi_range(int(bonus.min), int(bonus.max))
			var reward: Dictionary = fragment(data, bonus.type, amount) if bonus.type.ends_with("Fragment") else {"type":bonus.type,"contentId":bonus.get("contentId", ""),"amount":amount}
			got_fragment = got_fragment or bonus.type.ends_with("Fragment")
			grant(data, meta, reward)
			results.append(reward)
		record.pity = 0 if got_fragment else record.pity + 1
		if record.pity >= data.supply.pityLimit:
			var bonus := fragment(data, ["weaponFragment","characterFragment","blessingFragment"].pick_random(), 1)
			grant(data, meta, bonus)
			results.append(bonus)
			record.pity = 0
		record.opened += 1
	meta.supply.boxes[data.supply.id] = record
	return results

static func accrue_offline(data: Dictionary, meta: Dictionary, now: float) -> void:
	var last: String = meta.offlineReward.lastExitAt
	if last.is_empty(): return
	var then := Time.get_unix_time_from_datetime_string(last)
	var interval: float = data.offline.coinIntervalMinutes * 60.0
	var count := floori(minf(data.offline.capHours * 3600.0, maxf(0.0, now - then)) / interval)
	var pending: Dictionary = meta.offlineReward.pendingRewards
	for i in range(count):
		pending.associationCoins += weighted(data.offline.coinAmounts).amount + meta.guild.facilityLevels.recovery
		for stone in data.offline.revivalStones:
			if randf() < stone.baseChance + i * stone.chancePerInterval: pending.revivalStones[stone.grade] += 1

static func claim_offline(meta: Dictionary) -> bool:
	var rewards: Dictionary = meta.offlineReward.pendingRewards
	var any_reward: bool = rewards.associationCoins > 0 or rewards.supplyTickets > 0
	meta.wallet.associationCoins += rewards.associationCoins
	meta.wallet.supplyTickets += rewards.supplyTickets
	rewards.associationCoins = 0; rewards.supplyTickets = 0
	for grade in rewards.revivalStones:
		any_reward = any_reward or rewards.revivalStones[grade] > 0
		meta.wallet.revivalStones[grade] += rewards.revivalStones[grade]
		rewards.revivalStones[grade] = 0
	return any_reward

static func settle(data: Dictionary, meta: Dictionary, run: HeroRun, clear: bool) -> int:
	if run.settled: return run.reward
	run.settled = true
	var id: String = run.setup.character
	var progress: Dictionary = meta.gateProgression.characters.get(id, {"highestClearedDepth":0,"rewardedThroughDepth":0,"bestWaveByDepth":{}})
	var depth: int = run.setup.depth
	var completed := run.wave if clear or run.previous_phase == "shop" else maxi(0, run.wave - 1)
	progress.bestWaveByDepth[str(depth)] = maxi(int(progress.bestWaveByDepth.get(str(depth), 0)), completed)
	var coins := 0
	if clear:
		coins = maxi(0, depth - int(progress.rewardedThroughDepth)) * int(data.gate.firstClearReward)
		progress.rewardedThroughDepth = maxi(int(progress.rewardedThroughDepth), depth)
		progress.highestClearedDepth = maxi(int(progress.highestClearedDepth), depth)
		meta.gateProgression.highestUnlockedDepth = maxi(int(meta.gateProgression.highestUnlockedDepth), depth + 1)
	elif depth > progress.highestClearedDepth: coins = completed * int(data.gate.failureRewardPerCompletedWave)
	meta.gateProgression.characters[id] = progress
	meta.wallet.associationCoins += coins
	var stats: Dictionary = meta.statistics
	stats.runs += 1; stats.kills += run.kills
	stats.clears += 1 if clear else 0
	stats.bestWave = maxi(int(stats.bestWave), run.wave)
	stats.bestTime = maxf(stats.bestTime, run.combat_time)
	for pair in [["byCharacter",id],["byMap",run.setup.map]]:
		var summary: Dictionary = stats[pair[0]].get(pair[1], {"runs":0,"clears":0,"kills":0,"bestWave":0,"bestTime":0})
		summary.runs += 1; summary.clears += 1 if clear else 0; summary.kills += run.kills
		summary.bestWave = maxi(int(summary.bestWave), run.wave); summary.bestTime = maxf(summary.bestTime, run.combat_time)
		stats[pair[0]][pair[1]] = summary
	stats.lastRun = {"recordedAt":Time.get_datetime_string_from_system(true),"outcome":"stageClear" if clear else "gameOver","mapId":run.setup.map,"characterId":id,"gateDepth":depth,"reachedWave":run.wave,"kills":run.kills,"combatSeconds":run.combat_time,"associationCoins":coins}
	run.reward = coins
	return coins
