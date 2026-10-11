class_name HeroShop
extends RefCounted

static func eligible(run: HeroRun) -> Array:
	var result: Array = []
	for id in run.available_weapons:
		var definition: Dictionary = run.data.weapons[id]
		var owned := run.owned.filter(func(slot): return slot.id == id)
		if not owned.is_empty():
			if owned[0].level < definition.maxLevel: result.append({"id":id,"level":int(owned[0].level) + 1,"locked":false})
		elif id not in run.guild_support.excludedWeaponIds and run.owned.size() < int(run.data.weaponConfig.maxSlots) and not definition.has("signatureOwnerId"):
			result.append({"id":id,"level":1,"locked":false})
	return result

static func price(run: HeroRun, offer: Dictionary) -> int:
	if offer.get("id", "").is_empty(): return 0
	var prices: Dictionary = run.data.shop.weaponPrices
	if int(offer.level) == 1: return int(prices.newStructure if run.data.weapons[offer.id].has("structure") else prices.newWeapon)
	return int(prices.upgrade.get(str(int(offer.level)), 999999))

static func refresh(run: HeroRun, weapon: bool) -> void:
	var stock: Array = run.weapon_stock if weapon else run.item_stock
	while stock.size() < 4: stock.append({"id":"","locked":false,"level":0})
	var excluded: Array = []
	for slot in stock:
		if (slot.locked or slot.get("free",false)) and not slot.id.is_empty(): excluded.append(slot.id)
	for i in range(4):
		if stock[i].locked and not stock[i].id.is_empty():
			if not weapon or eligible(run).any(func(offer): return offer.id == stock[i].id and offer.level == stock[i].level): continue
		# An unclaimed elite supply stays on the shelf through rerolls and later shops.
		if stock[i].get("free",false) and not stock[i].id.is_empty(): continue
		var pool: Array = eligible(run) if weapon else _item_pool(run)
		pool = pool.filter(func(offer): return offer.id not in excluded)
		var offer: Dictionary = {"id":"","locked":false,"level":0}
		if not pool.is_empty():
			if weapon: offer = pool.pick_random().duplicate()
			else:
				var weights: Array = []
				var counts := {}
				for item in pool: counts[item.rarity] = counts.get(item.rarity, 0) + 1
				for item in pool:
					var rarity: Dictionary = run.data.shop.rarities[item.rarity]
					weights.append((rarity.weight * (1.0 + maxf(0.0, run.stats.luck) / run.data.shop.luckScale * rarity.luckBoost)) / counts[item.rarity])
				var roll: float = randf() * weights.reduce(func(a,b): return a + b, 0.0)
				var selected := pool.size() - 1
				for j in range(pool.size()):
					roll -= weights[j]
					if roll < 0: selected = j; break
				offer = {"id":pool[selected].id,"locked":false,"level":0}
		stock[i] = offer
		if not offer.id.is_empty(): excluded.append(offer.id)

static func item_price(run: HeroRun, offer: Dictionary) -> int:
	return 0 if offer.get("free",false) else int(run.data.items[offer.id].basePrice)

# Elite supply: one free item of the given rarities takes the first unlocked item slot.
static func grant_supply(run: HeroRun, rarities: Array) -> bool:
	if rarities.is_empty(): return false
	var shown: Array = run.item_stock.map(func(slot): return slot.id)
	var pool: Array = _item_pool(run,true).filter(func(item): return item.id not in shown)
	var choices: Array = pool.filter(func(item): return item.rarity in rarities)
	if choices.is_empty(): choices = pool.filter(func(item): return item.rarity in run.data.featuredElites.supplyRarities)
	if choices.is_empty(): choices = pool
	if choices.is_empty(): return false
	for i in range(run.item_stock.size()):
		var slot: Dictionary = run.item_stock[i]
		if not slot.id.is_empty() and (slot.locked or slot.get("free",false)): continue
		run.item_stock[i] = {"id":choices.pick_random().id,"locked":false,"level":0,"free":true}
		return true
	return false

static func _item_pool(run: HeroRun, any_wave: bool = false) -> Array:
	var pool: Array = []
	for id in run.available_items:
		if id in run.guild_support.excludedItemIds: continue
		var item: Dictionary = run.data.items[id]
		if not any_wave and run.data.shop.rarities[item.rarity].wave > run.wave: continue
		if item.maxStacks != null and run.items.get(id, 0) >= item.maxStacks: continue
		pool.append(item)
	return pool

static func offer_block_reason(run: HeroRun, offer: Dictionary, weapon: bool) -> String:
	var id: String = offer.get("id","")
	if id.is_empty(): return "soldOut"
	if not run.pending_branch.is_empty(): return "branch"
	var cost := price(run,offer) if weapon else item_price(run,offer)
	if run.currency < cost: return "currency"
	if weapon:
		if eligible(run).any(func(candidate): return candidate.id == id and candidate.level == offer.level): return ""
		var owned := run.owned.filter(func(slot): return slot.id == id)
		if owned.is_empty() and run.owned.size() >= int(run.data.weaponConfig.maxSlots): return "weaponSlots"
		if not owned.is_empty() and owned[0].level >= run.data.weapons[id].maxLevel: return "weaponMax"
	else:
		if _item_pool(run,offer.get("free",false)).any(func(item): return item.id == id): return ""
		var limit = run.data.items[id].maxStacks
		if limit != null and run.items.get(id,0) >= limit: return "itemMax"
	return "unavailable"

static func buy(run: HeroRun, index: int, weapon: bool) -> bool:
	if run.phase != "shop" or index < 0 or index >= 4: return false
	var stock: Array = run.weapon_stock if weapon else run.item_stock
	var offer: Dictionary = stock[index]
	if not offer_block_reason(run,offer,weapon).is_empty(): return false
	var cost := price(run, offer) if weapon else item_price(run,offer)
	if weapon:
		var matches := run.owned.filter(func(slot): return slot.id == offer.id)
		var slot: Dictionary
		if matches.is_empty():
			slot = {"id":offer.id,"level":1,"branch":"","cooldown":0.0}
			run.owned.append(slot)
		else:
			slot = matches[0]
			slot.level = offer.level
		if slot.level == run.data.weapons[slot.id].branchAtLevel and slot.branch.is_empty(): run.pending_branch = slot.id
	else:
		run.items[offer.id] = run.items.get(offer.id, 0) + 1
		run.recalculate()
	run.currency -= cost
	HeroTelemetry.purchase(run,offer.id,cost,weapon,int(offer.level))
	stock[index] = {"id":"","level":0,"locked":false}
	run.audio_cue("weaponPurchase" if weapon else "purchase", {"weaponId":offer.id,"stage":"purchase"} if weapon else {"itemId":offer.id,"stage":"acquire"})
	run.event.emit("weaponPurchase" if weapon else "purchase")
	return true

static func choose_branch(run: HeroRun, branch_id: String) -> bool:
	if run.phase != "shop" or run.pending_branch.is_empty() or branch_id not in ["A","B"]: return false
	var definition: Dictionary = run.data.weapons[run.pending_branch]
	if not definition.branches.any(func(branch): return branch.id == branch_id): return false
	for slot in run.owned:
		if slot.id == run.pending_branch and slot.level == definition.branchAtLevel and slot.branch.is_empty():
			slot.branch = branch_id
			run.pending_branch = ""
			run.event.emit("branchChoice")
			return true
	return false

static func reroll_cost(run: HeroRun, weapon: bool) -> int:
	return int(run.data.shop.weaponRerollBase + run.weapon_rerolls * run.data.shop.weaponRerollStep) if weapon else int(run.data.shop.itemRerollBase + run.item_rerolls * run.data.shop.itemRerollStep)

static func reroll(run: HeroRun, weapon: bool) -> bool:
	if run.phase != "shop" or not run.pending_branch.is_empty() or run.currency < reroll_cost(run, weapon): return false
	var stock: Array = run.weapon_stock if weapon else run.item_stock
	if stock.all(func(slot): return slot.locked): return false
	run.currency -= reroll_cost(run, weapon)
	run.telemetry.spent += reroll_cost(run,weapon)
	if weapon: run.weapon_rerolls += 1
	else: run.item_rerolls += 1
	refresh(run, weapon)
	run.event.emit("reroll")
	return true
