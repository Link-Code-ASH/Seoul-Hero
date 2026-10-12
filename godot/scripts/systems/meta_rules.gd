class_name HeroMeta
extends RefCounted

static func feature(data: Dictionary, id: String) -> bool:
	return bool(data.get("features",{}).get(id,true))

static func initialize(data: Dictionary, meta: Dictionary) -> void:
	if not meta.guild.has("facilities"): meta.guild = HeroGuildState.create(data,0.0)
	if not meta.gateProgression.has("firstClears"): meta.gateProgression.firstClears = {}
	_initialize_offline(meta)
	# Added starter characters become usable on existing profiles without replacing progress.
	for id in data.characters:
		if not meta.characters.has(id): meta.characters[id] = {"unlocked":id in data.draws.starter.characters,"fragments":0,"breakthrough":0}
		elif id in data.draws.starter.characters: meta.characters[id].unlocked = true
	for id in data.weapons:
		if not meta.sharedWeapons.has(id): meta.sharedWeapons[id] = {"unlocked":id in data.draws.starter.weapons,"fragments":0,"level":0}
	for id in data.blessings:
		if not meta.blessings.has(id): meta.blessings[id] = {"unlocked":false,"fragments":0,"level":0}
	if not meta.get("daily") is Dictionary: meta.daily = {"claimedDayKey":-1,"streak":0}
	_refund_removed_growth(data,meta)

# Character breakthrough and weapon levels were removed (2026-10-10). Old saves get the
# association coins they paid back; the level resets so this runs once per record.
static func _refund_removed_growth(data: Dictionary, meta: Dictionary) -> void:
	for pair in [["characters","breakthrough"],["sharedWeapons","level"]]:
		for id in meta[pair[0]]:
			var progress: Dictionary = meta[pair[0]][id]
			var level := clampi(int(progress.get(pair[1],0)),0,data.growth.coinCosts.size())
			for i in range(level): meta.wallet.associationCoins += int(data.growth.coinCosts[i])
			progress[pair[1]] = 0

# Highest cleared depth on the account (any character).
static func cleared_depth(meta: Dictionary) -> int:
	return maxi(0,int(meta.gateProgression.get("highestUnlockedDepth",1))-1)

# Guild-side rewards grow with the account's gate progress.
static func region_multiplier(data: Dictionary, meta: Dictionary) -> float:
	return 1.0+minf(float(data.region.maxBonus),float(data.region.bonusPerDepth)*cleared_depth(meta))

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
	if feature(data,"guild"): result.append_array(HeroGuildSupport.character_modifiers(data,meta,setup.character))
	for id in meta.association.upgrades:
		if not data.upgrades.has(id): continue
		var upgrade: Dictionary = data.upgrades[id]
		var effect: Dictionary = upgrade.effect
		if effect.type == "stat": result.append({"stat":effect.stat,"operation":effect.operation,"value":association_bonus(upgrade,int(meta.association.upgrades[id])) + (1.0 if effect.operation == "multiply" else 0.0)})
	result.append_array(data.weeklyRules.get(setup.weekly, {}).get("benefit", []))
	var blessing_id: String = setup.get("blessing", "")
	var progress: Dictionary = meta.blessings.get(blessing_id, {})
	if progress.get("unlocked", false):
		var blessing_level := blessing_level(data,progress)
		for effect in data.blessings[blessing_id].modifiers:
			result.append({"stat":effect.stat,"operation":effect.operation,"value":1.0 + (effect.value - 1.0) * blessing_level if effect.operation == "multiply" else effect.value * blessing_level})
	return result

# Without blessing growth an unlocked blessing always works at level 1.
static func blessing_level(data: Dictionary, progress: Dictionary) -> int:
	if not progress.get("unlocked",false): return 0
	return int(progress.get("level",0)) if feature(data,"blessingLevels") else 1

# New saves start with only the starter characters and weapons; the rest come from draws.
static func apply_starter(data: Dictionary, meta: Dictionary) -> void:
	for id in meta.characters: meta.characters[id].unlocked = id in data.draws.starter.characters
	for id in meta.sharedWeapons: meta.sharedWeapons[id].unlocked = id in data.draws.starter.weapons

const DRAW_KINDS := {"character":["characters","characters"],"weapon":["weapons","sharedWeapons"],"blessing":["blessings","blessings"]}

static func draw_candidates(data: Dictionary, meta: Dictionary, kind: String) -> Array:
	var spec: Array = DRAW_KINDS[kind]
	var ids: Array = data[spec[0]].keys()
	ids.sort()
	return ids.filter(func(id): return not meta[spec[1]].get(id,{}).get("unlocked",false))

# 협회 코인 뽑기: unlocks one random locked character/weapon/blessing. Returns its id or "".
static func draw(data: Dictionary, meta: Dictionary, kind: String, roll: Callable = func(): return randf()) -> String:
	if not DRAW_KINDS.has(kind): return ""
	var cost := int(data.draws.costs[kind])
	var candidates := draw_candidates(data,meta,kind)
	if candidates.is_empty() or int(meta.wallet.associationCoins) < cost: return ""
	var id: String = candidates[mini(candidates.size()-1,floori(float(roll.call())*candidates.size()))]
	meta.wallet.associationCoins -= cost
	var record: Dictionary = meta[DRAW_KINDS[kind][1]][id]
	record.unlocked = true
	if kind == "blessing": record.level = maxi(1,int(record.get("level",0)))
	return id

const FRAGMENT_KINDS := {"character":["characters","characters","breakthrough","characterFragments"],"weapon":["weapons","sharedWeapons","level","weaponFragments"],"blessing":["blessings","blessings","level","blessingFragments"]}

# Characters and weapons: only locked ones (fragments unlock them), possibly none.
# Blessings: unmaxed first, falling back to every blessing, so blessings never run out.
static func fragment_candidates(data: Dictionary, meta: Dictionary, kind: String) -> Array:
	var spec: Array = FRAGMENT_KINDS[kind]
	var all: Array = data[spec[0]].keys()
	all.sort()
	if kind != "blessing": return all.filter(func(id): return not meta[spec[1]].get(id,{}).get("unlocked",false))
	var open: Array = all.filter(func(id): return int(meta[spec[1]].get(id,{}).get(spec[2],0)) < int(data.growth.maxLevel))
	return open if not open.is_empty() else all

# A kind with nothing left to unlock hands its fragments to blessings.
static func fragment_kind(data: Dictionary, meta: Dictionary, kind: String) -> String:
	return kind if not fragment_candidates(data,meta,kind).is_empty() else "blessing"

# roll returns 0..1. Returns {"kind","id","key"} where key is the reward bucket name.
static func pick_fragment(data: Dictionary, meta: Dictionary, weights: Dictionary, roll: Callable) -> Dictionary:
	var total := 0.0
	for kind in FRAGMENT_KINDS: total += float(weights.get(kind,0.0))
	var value: float = float(roll.call()) * total
	var chosen := "character"
	for kind in FRAGMENT_KINDS:
		value -= float(weights.get(kind,0.0))
		if value < 0.0: chosen = kind; break
	chosen = fragment_kind(data,meta,chosen)
	var candidates := fragment_candidates(data,meta,chosen)
	var id: String = candidates[mini(candidates.size()-1,floori(float(roll.call())*candidates.size()))]
	return {"kind":chosen,"id":id,"key":FRAGMENT_KINDS[chosen][3]}

# Daily gift days roll over at 05:00 KST (20:00 UTC).
static func day_key(data: Dictionary, now: float) -> int:
	return floori((now - float(data.daily.resetUtcHour) * 3600.0) / 86400.0)

static func daily_offer(data: Dictionary, meta: Dictionary, now: float) -> Dictionary:
	var today := day_key(data,now)
	var daily: Dictionary = meta.daily
	if int(daily.get("offerDayKey",-1)) != today or not daily.get("offer") is Dictionary:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("daily:%d" % today)
		var pick := pick_fragment(data,meta,data.daily.kindWeights,func(): return rng.randf())
		pick.amount = int(data.daily.fragmentAmounts[pick.kind])
		daily.offer = pick
		daily.offerDayKey = today
	return daily.offer

static func daily_available(data: Dictionary, meta: Dictionary, now: float) -> bool:
	if not feature(data,"dailyGift"): return false
	return int(meta.daily.get("claimedDayKey",-1)) != day_key(data,now)

# Returns the granted rewards in display order, or [] when already claimed today.
static func claim_daily(data: Dictionary, meta: Dictionary, now: float) -> Array:
	if not daily_available(data,meta,now): return []
	var today := day_key(data,now)
	var offer := daily_offer(data,meta,now)
	var daily: Dictionary = meta.daily
	daily.streak = int(daily.get("streak",0)) + 1 if int(daily.get("claimedDayKey",-1)) == today - 1 else 1
	daily.claimedDayKey = today
	var rewards: Array = [
		{"type":offer.kind+"Fragment","contentId":offer.id,"amount":int(offer.amount)},
		{"type":"associationCoin","contentId":"","amount":int(data.daily.associationCoins)},
	]
	if feature(data,"guild"): rewards.append({"type":"guildResource","contentId":"coins","amount":int(data.daily.guildCoins)})
	if int(daily.streak) % int(data.daily.streakDays) == 0:
		if feature(data,"supplyBox"): rewards.append({"type":"supplyTicket","contentId":"","amount":int(data.daily.streakRewards.supplyTickets)})
		rewards.append({"type":"revivalStone","contentId":"low","amount":int(data.daily.streakRewards.revivalStoneLow)})
	for reward in rewards: grant(data,meta,reward)
	return rewards

static func association_cost(data: Dictionary, meta: Dictionary, id: String) -> int:
	if not data.upgrades.has(id): return -1
	var upgrade: Dictionary = data.upgrades[id]
	var level := int(meta.association.upgrades.get(id, 0))
	if int(upgrade.maxLevel) > 0 and level >= int(upgrade.maxLevel): return -1
	return ceili(float(upgrade.baseCost) + float(upgrade.get("costStep",0)) * level)

static func association_bonus(upgrade: Dictionary, level: int) -> float:
	if upgrade.effect.type != "stat": return 0.0
	var linear := maxi(0,level) * float(upgrade.effect.value)
	var limit := float(upgrade.get("softCap",0.0))
	return limit * linear / (limit + linear) if limit > 0.0 else linear

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
	if kind not in ["character","weapon","blessing"]: return false
	var collection: Dictionary = meta[{"character":"characters","weapon":"sharedWeapons","blessing":"blessings"}[kind]]
	if not collection.has(id): return false
	var progress: Dictionary = collection[id]
	if kind != "blessing":
		# Characters and weapons never grow; enough fragments unlock them.
		var unlock_cost := int(data.growth[kind+"UnlockCost"])
		if progress.unlocked or int(progress.fragments) < unlock_cost: return false
		progress.fragments -= unlock_cost
		progress.unlocked = true
		return true
	var level_key := "level"
	var level: int = progress[level_key]
	if level >= int(data.growth.maxLevel): return false
	var costs: Array = data.growth.blessingCosts
	var cost := int(costs[level])
	var coin_cost := int(data.growth.coinCosts[level])
	if progress.fragments < cost or meta.wallet.associationCoins < coin_cost: return false
	progress.fragments -= cost
	meta.wallet.associationCoins -= coin_cost
	progress[level_key] = level + 1
	if kind == "blessing": progress.unlocked = true
	return true

static func weighted(entries: Array) -> Dictionary:
	if entries.is_empty(): return {}
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
		"guildResource":
			if data.resources.has(reward.contentId) and meta.guild.wallet.has(reward.contentId): meta.guild.wallet[reward.contentId] += reward.amount
		_:
			var key: String = {"weaponFragment":"sharedWeapons","characterFragment":"characters","blessingFragment":"blessings"}.get(reward.type, "")
			if not key.is_empty() and meta[key].has(reward.contentId): meta[key][reward.contentId].fragments += reward.amount

static func fragment(data: Dictionary, meta: Dictionary, kind: String, amount: int) -> Dictionary:
	var chosen := fragment_kind(data,meta,kind.trim_suffix("Fragment"))
	return {"type":chosen+"Fragment","contentId":fragment_candidates(data,meta,chosen).pick_random(),"amount":amount}

static func open_supply(data: Dictionary, meta: Dictionary, count: int) -> Array:
	if count not in [1,10] or meta.wallet.supplyTickets < count * data.supply.ticketCost: return []
	meta.wallet.supplyTickets -= count * data.supply.ticketCost
	var record: Dictionary = meta.supply.boxes.get(data.supply.id, {"opened":0,"pity":0})
	var results: Array = []
	for i in range(count):
		var kinds := int(weighted(data.supply.kindCounts).amount)
		var pool: Array = data.supply.entries.duplicate(true)
		var chosen: Array = []
		for slot in range(mini(kinds,pool.size())):
			var entry := weighted(pool)
			chosen.append(entry)
			pool.erase(entry)
		# Reserve a slot within the sampled kind count; the pity never adds a fourth reward.
		if int(record.pity) + 1 >= int(data.supply.pityLimit) and not chosen.any(func(entry): return str(entry.type).ends_with("Fragment")):
			var fragments: Array = data.supply.entries.filter(func(entry): return str(entry.type).ends_with("Fragment"))
			if not chosen.is_empty() and not fragments.is_empty(): chosen[chosen.size()-1] = weighted(fragments)
		var got_fragment := false
		for entry in chosen:
			var amount_entries: Array = []
			for index in range(entry.amounts.size()): amount_entries.append({"amount":entry.amounts[index],"weight":data.supply.amountWeights[index]})
			var amount := int(weighted(amount_entries).amount)
			var is_fragment := str(entry.type).ends_with("Fragment")
			var reward: Dictionary = fragment(data,meta,entry.type,amount) if is_fragment else {"type":entry.type,"contentId":entry.get("contentId",""),"amount":amount}
			got_fragment = got_fragment or is_fragment
			grant(data, meta, reward)
			results.append(reward)
		record.pity = 0 if got_fragment else record.pity + 1
		record.opened += 1
	meta.supply.boxes[data.supply.id] = record
	return results

static func accrue_offline(data: Dictionary, meta: Dictionary, now: float) -> void:
	_initialize_offline(meta)
	if not feature(data,"offlineReward"):
		# Keep the cursor current so re-enabling never pays out the time it was off.
		meta.offlineReward.lastAccruedAt = now
		return
	var state: Dictionary = meta.offlineReward
	var then := float(state.lastAccruedAt)
	if then <= 0.0:
		state.lastAccruedAt = now
		return
	if now <= then: return
	var support := HeroGuildSupport.effects(data,meta.guild)
	var cap_seconds := float(support.offlineCapHours) * 3600.0
	var remaining := maxf(0.0,cap_seconds-float(state.accumulatedSeconds))
	state.accumulatedSeconds += minf(now-then,remaining)
	# Move the cursor even at capacity, discarding time beyond the current storage cap.
	state.lastAccruedAt = now
	var interval := float(data.offline.coinIntervalMinutes) * 60.0
	var intervals := floori(float(state.accumulatedSeconds)/interval)
	var count := maxi(0,intervals-int(state.rewardedIntervals))
	if count == 0: return
	var pending: Dictionary = state.pendingRewards
	var region := region_multiplier(data,meta)
	for key in data.offline.baseRewards:
		var multiplier := 1.0 if key in data.offline.fixedRewardKeys else float(support.offlineYieldMultiplier)*region
		var amount := float(data.offline.baseRewards[key]) * count * multiplier + float(state.rewardCarry.get(key,0.0))
		var whole := floori(amount)
		pending[key] = int(pending.get(key,0)) + whole
		state.rewardCarry[key] = amount-whole
	state.rewardedIntervals = intervals

static func _initialize_offline(meta: Dictionary) -> void:
	var state: Dictionary = meta.offlineReward
	if not state.has("lastAccruedAt"):
		var last := str(state.get("lastExitAt",""))
		state.lastAccruedAt = float(Time.get_unix_time_from_datetime_string(last)) if not last.is_empty() else 0.0
	if not state.has("accumulatedSeconds"): state.accumulatedSeconds = 0.0
	if not state.has("rewardedIntervals"): state.rewardedIntervals = 0
	if not state.has("rewardCarry"): state.rewardCarry = {}
	if not state.has("pendingRewards"): state.pendingRewards = {}
	var pending: Dictionary = state.pendingRewards
	for key in ["associationCoins","supplyTickets"] + HeroGuildState.RESOURCES:
		if not pending.has(key): pending[key] = 0
	for key in ["characterFragments","weaponFragments","blessingFragments"]:
		if not pending.has(key): pending[key] = {}
	if not pending.has("revivalStones"): pending.revivalStones = {"low":0,"mid":0,"high":0}

static func has_offline_rewards(meta: Dictionary) -> bool:
	var rewards: Dictionary = meta.offlineReward.pendingRewards
	for value in rewards.values():
		if value is Dictionary:
			for amount in value.values():
				if float(amount) > 0.0: return true
		elif (value is int or value is float) and value > 0: return true
	return false

static func claim_offline(data: Dictionary, meta: Dictionary) -> bool:
	_initialize_offline(meta)
	var rewards: Dictionary = meta.offlineReward.pendingRewards
	if not has_offline_rewards(meta): return false
	meta.wallet.associationCoins += rewards.associationCoins
	meta.wallet.supplyTickets += rewards.supplyTickets
	rewards.associationCoins = 0; rewards.supplyTickets = 0
	for key in HeroGuildState.RESOURCES:
		meta.guild.wallet[key] = int(meta.guild.wallet.get(key,0)) + int(rewards.get(key,0))
		rewards[key] = 0
	for pair in [["characterFragments","characters"],["weaponFragments","sharedWeapons"],["blessingFragments","blessings"]]:
		for id in rewards[pair[0]]:
			if meta[pair[1]].has(id): meta[pair[1]][id].fragments += rewards[pair[0]][id]
		rewards[pair[0]].clear()
	for grade in rewards.revivalStones:
		meta.wallet.revivalStones[grade] += rewards.revivalStones[grade]
		rewards.revivalStones[grade] = 0
	var state: Dictionary = meta.offlineReward
	# Intervals have already become pending rewards; only the unfinished interval survives.
	state.accumulatedSeconds = maxf(0.0,float(state.accumulatedSeconds)-int(state.rewardedIntervals)*float(data.offline.coinIntervalMinutes)*60.0)
	state.rewardedIntervals = 0
	state.lastClaimedAt = Time.get_datetime_string_from_system(true)
	return true

static func settle(data: Dictionary, meta: Dictionary, run: HeroRun, outcome: String) -> int:
	if run.settled: return run.reward
	if outcome not in ["clear","death","abandon"]: return 0
	var last: Dictionary = meta.statistics.get("lastRun",{})
	if not run.run_id.is_empty() and last.get("runId","") == run.run_id:
		run.settled = true
		run.reward = int(last.get("associationCoins",0))
		run.reward_tickets = int(last.get("supplyTickets",0))
		return run.reward
	run.settled = true
	var clear := outcome == "clear"
	var id: String = run.setup.character
	var progress: Dictionary = meta.gateProgression.characters.get(id, {"highestClearedDepth":0,"rewardedThroughDepth":0,"bestWaveByDepth":{}})
	var depth := int(run.setup.depth)
	var total_waves := maxi(1,run.map.waveDefinitions.size())
	var completed := total_waves if clear else clampi(run.wave-1,0,total_waves)
	if outcome == "abandon" and (run.phase in ["shop","postWave"] or (run.phase == "paused" and run.previous_phase == "shop")): completed = mini(run.wave,total_waves)
	progress.bestWaveByDepth[str(depth)] = maxi(int(progress.bestWaveByDepth.get(str(depth), 0)), completed)
	var coins := 0
	var tickets := 0
	var gate: Dictionary = data.gate
	# 협회 코인은 전투 중 주운 만큼만 (뱀서 금화 방식). 클리어 보상 코인은 없다.
	coins = int(run.loot.get("associationCoins",0))
	for grade in run.loot.get("revivalStones",{}):
		meta.wallet.revivalStones[grade] = int(meta.wallet.revivalStones.get(grade,0))+int(run.loot.revivalStones[grade])
	if clear:
		if not meta.gateProgression.has("firstClears"): meta.gateProgression.firstClears = {}
		var first_clears: Array = meta.gateProgression.firstClears.get(run.setup.map,[])
		if depth not in first_clears:
			tickets = int(gate.firstClearTickets) if feature(data,"supplyBox") else 0
			first_clears.append(depth)
			meta.gateProgression.firstClears[run.setup.map] = first_clears
		progress.rewardedThroughDepth = maxi(int(progress.rewardedThroughDepth), depth)
		progress.highestClearedDepth = maxi(int(progress.highestClearedDepth), depth)
		meta.gateProgression.highestUnlockedDepth = maxi(int(meta.gateProgression.highestUnlockedDepth), depth + 1)
	var guild_rewards := {"materials":0,"speedupTickets":0,"constructionParts":0,"electronicParts":0}
	if outcome != "abandon" and feature(data,"guild"):
		guild_rewards.materials = completed * int(gate.runMaterialsPerWave) * (1 + floori(depth / float(gate.runMaterialsDepthStep)))
		guild_rewards.speedupTickets = floori(float(completed)/data.guildManagement.benefits.runTicketsPerWaves)
		if clear:
			var parts := int(gate.clearPartsBase) + floori(depth / float(gate.clearPartsDepthStep))
			guild_rewards.constructionParts = parts
			guild_rewards.electronicParts = parts
		for key in guild_rewards: meta.guild.wallet[key] += guild_rewards[key]
	meta.gateProgression.characters[id] = progress
	meta.wallet.associationCoins += coins
	meta.wallet.supplyTickets += tickets
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
	stats.lastRun = {"runId":run.run_id,"recordedAt":Time.get_datetime_string_from_system(true),"outcome":"stageClear" if clear else "gameOver" if outcome == "death" else "abandon","mapId":run.setup.map,"characterId":id,"gateDepth":depth,"reachedWave":run.wave,"completedWaves":completed,"kills":run.kills,"combatSeconds":run.combat_time,"associationCoins":coins,"supplyTickets":tickets,"guildRewards":guild_rewards}
	run.reward = coins
	run.reward_tickets = tickets
	return coins
