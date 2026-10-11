class_name HeroGuildRules
extends RefCounted

# Why the last act() call was refused, in player-facing Korean. Empty when it succeeded.
static var last_error := ""

static func _fail(message: String) -> bool:
	last_error = message
	return false

static func _name(data: Dictionary, key: String) -> String:
	return str(data.resources.get(key,{}).get("name",key))

static func _facility_name(data: Dictionary, id: String) -> String:
	return str(data.guildManagement.facilities.get(id,{}).get("name",id))

# Lists what is missing for a cost, e.g. "길드 코인 120 · 전자 부품 3 부족".
static func shortfall(data: Dictionary, meta: Dictionary, cost: Dictionary) -> String:
	var parts: Array[String] = []
	for key in HeroGuildState.RESOURCES:
		var missing := int(cost.get(key,0))-int(meta.guild.wallet[key])
		if missing > 0: parts.append("%s %d" % [_name(data,key),missing])
	var coins := int(cost.get("associationCoins",0))-int(meta.wallet.get("associationCoins",0))
	if coins > 0: parts.append("협회 코인 %d" % coins)
	return "" if parts.is_empty() else " · ".join(parts)+" 부족"

static func level(g: Dictionary, id: String) -> int:
	return int(g.facilities.get(id,{}).get("level",0))

static func rooms(data: Dictionary, g: Dictionary) -> int:
	return HeroGuildState.room_count(data,g)

static func staff_capacity(data: Dictionary, g: Dictionary) -> int:
	var b: Dictionary = data.guildManagement.balance
	return mini(data.guildManagement.employees.size(),int(b.staffCapacityBase+(level(g,"office")-1)*b.staffCapacityPerOfficeLevel))

static func afford(g: Dictionary, cost: Dictionary, association_wallet: Dictionary = {}) -> bool:
	for key in HeroGuildState.RESOURCES:
		if g.wallet[key] < cost.get(key,0): return false
	if association_wallet.get("associationCoins",0) < cost.get("associationCoins",0): return false
	return true

static func _pay(meta: Dictionary, cost: Dictionary) -> bool:
	if not afford(meta.guild,cost,meta.wallet):
		var missing := shortfall(Content.data,meta,cost) if Content.data.has("resources") else ""
		return _fail(missing if not missing.is_empty() else "재화가 부족해요")
	for key in HeroGuildState.RESOURCES: meta.guild.wallet[key] -= cost.get(key,0)
	meta.wallet.associationCoins -= cost.get("associationCoins",0)
	return true

static func _has(g: Dictionary, types: Array, id: String = "") -> bool:
	return g.jobs.any(func(job): return job.type in types and (id == "" or job.targetId == id))

static func _free(g: Dictionary, ids: Array) -> bool:
	var known := {}
	for e in g.employees: known[e.id] = e
	return HeroGuildState.ids(ids,known) and ids.all(func(id): return not HeroGuildClock.busy(g,id))

static func _speed(data: Dictionary, g: Dictionary, facility: String, ids: Array = []) -> float:
	var selected: Array = HeroGuildClock.assigned(g,facility) if ids.is_empty() else ids
	return (1.0+HeroGuildClock.work_bonus(data,g,selected,facility))*(1.0+maxi(0,level(g,facility)-1)*data.guildManagement.balance.facilityWorkBonusPerLevel)

static func _job(g: Dictionary, kind: String, target: String, now: float, duration_ms: float, ids: Array = [], extra: Dictionary = {}) -> void:
	var job := {"id":str(int(g.nextJobId)),"type":kind,"targetId":target,"startedAt":now,"endsAt":now+duration_ms/1000.0,"employeeIds":ids.duplicate()}
	job.merge(extra,true)
	g.jobs.append(job); g.nextJobId += 1

# Highest cleared gate depth needed before the office can reach this level.
static func office_depth(data: Dictionary, target_level: int) -> int:
	var table: Array = data.guildManagement.balance.get("officeDepthByLevel",[])
	return int(table[target_level-1]) if target_level >= 1 and target_level <= table.size() else 0

static func _construction_available(data: Dictionary, g: Dictionary, id: String) -> bool:
	var limit := 2 if level(g,"office") >= data.guildManagement.balance.parallelConstructionOfficeLevel else 1
	return not _has(g,["construction"],id) and g.jobs.filter(func(job): return job.type == "construction").size() < limit

static func _reserved(g: Dictionary, slot: int, except: String = "") -> bool:
	for id in g.facilities:
		if id != except and level(g,id) > 0 and g.facilities[id].slot == slot: return true
	return g.jobs.any(func(job): return job.type == "construction" and job.targetId != except and job.slot == slot)

# All mutating commands settle old rates first; controller persists accepted commands.
static func act(data: Dictionary, meta: Dictionary, action: String, args: Dictionary, now: float, rng: Callable = Callable()) -> bool:
	last_error = ""
	if not is_finite(now) or now <= 0: return _fail("시간 정보가 올바르지 않아요")
	HeroGuildClock.advance(data,meta,now)
	now = maxf(now,meta.guild.lastAdvancedAt)
	var g: Dictionary = meta.guild
	var config: Dictionary = data.guildManagement
	var b: Dictionary = config.balance
	var id: String = str(args.get("id",""))
	var ids: Array = args.get("employees",[])
	var effects := HeroGuildSupport.effects(data,g)
	match action:
		"construct","upgrade":
			if not config.facilities.has(id): return _fail("알 수 없는 시설이에요")
			if _has(g,["construction"],id): return _fail("이미 공사 중인 시설이에요")
			if not _construction_available(data,g,id): return _fail("동시 공사 한도에 걸렸어요 · 운영실 Lv.%d부터 2곳 동시 공사" % int(b.parallelConstructionOfficeLevel))
			var current := level(g,id)
			var slot := int(args.get("slot",g.facilities[id].slot))
			if action == "construct":
				if id == "office" or current > 0: return _fail("이미 지어진 시설이에요")
				if slot < 1 or slot >= rooms(data,g): return _fail("빈 사무실을 먼저 고르세요")
				if _reserved(g,slot): return _fail("이 사무실은 이미 사용 중이에요")
				if level(g,"office") < config.facilities[id].unlockOfficeLevel: return _fail("운영실 Lv.%d부터 지을 수 있어요" % int(config.facilities[id].unlockOfficeLevel))
			elif current <= 0: return _fail("먼저 시설을 지어야 해요")
			if current >= config.facilities[id].maxLevel: return _fail("최고 레벨이에요")
			if id != "office" and current >= level(g,"office"): return _fail("운영실 레벨보다 높게 올릴 수 없어요 · 운영실을 먼저 올리세요")
			if id == "office" and HeroMeta.cleared_depth(meta) < office_depth(data,current+1): return _fail("게이트 %d층 클리어 필요 · 현재 %d층" % [office_depth(data,current+1),HeroMeta.cleared_depth(meta)])
			var spec: Dictionary = config.facilities[id].levels[current]
			if not _pay(meta,spec.cost): return false
			_job(g,"construction",id,now,spec.durationMs/(1.0+HeroGuildClock.work_bonus(data,g,HeroGuildClock.assigned(g,"office"),"office")),[],{"slot":slot,"targetLevel":current+1})
		"move":
			var slot := int(args.get("slot",-1))
			if not config.facilities.has(id) or id == "office" or level(g,id) <= 0 or _has(g,["construction"],id) or slot < 1 or slot >= rooms(data,g): return false
			if g.jobs.any(func(job): return job.type == "construction" and job.slot == slot): return false
			var previous: int = g.facilities[id].slot
			for other in g.facilities:
				if other != id and level(g,other) > 0 and g.facilities[other].slot == slot:
					if _has(g,["construction"],other): return false
					g.facilities[other].slot = previous
			g.facilities[id].slot = slot
		"hire":
			if not config.employees.has(id): return _fail("알 수 없는 직원이에요")
			if g.employees.any(func(e): return e.id == id): return _fail("이미 채용한 직원이에요")
			if g.employees.size() >= staff_capacity(data,g): return _fail("직원 정원이 찼어요 · 운영실을 올리면 늘어나요")
			if not _pay(meta,config.employees[id].hireCost): return false
			g.employees.append({"id":id,"level":1,"experience":0.0,"assignment":""})
		"assign","train":
			var found: Array = g.employees.filter(func(e): return e.id == id)
			if found.is_empty(): return _fail("직원을 먼저 고르세요")
			if HeroGuildClock.busy(g,id): return _fail("작업 중인 직원은 바꿀 수 없어요")
			var employee: Dictionary = found[0]
			if action == "assign":
				var facility: String = str(args.get("facility",""))
				if facility != "" and (not config.facilities.has(facility) or level(g,facility) <= 0): return _fail("지어진 시설에만 배치할 수 있어요")
				employee.assignment = facility
			else:
				if employee.level >= b.maxStaffLevel: return _fail("최고 레벨 직원이에요")
				if not _pay(meta,b.educationCost): return false
				_job(g,"training",id,now,b.educationDurationMs,[id],{"targetLevel":int(employee.level)+1})
		"research","recipe":
			if level(g,"research") <= 0: return _fail("연구실을 먼저 지어야 해요" if action == "research" else "조합법 해금은 연구실에서 해요 · 연구실을 먼저 지으세요")
			if _has(g,["research","recipe"]): return _fail("연구실이 다른 연구를 진행 중이에요")
			if ids.size() != 1: return _fail("연구할 직원 1명을 고르세요")
			if not _free(g,ids): return _fail("그 직원은 다른 작업 중이에요")
			if action == "research":
				if not config.research.has(id): return _fail("알 수 없는 연구예요")
				var definition: Dictionary = config.research[id]
				var current: int = g.researchLevels.get(id,0)
				if current >= definition.maxLevel: return _fail("최고 단계까지 연구했어요")
				if level(g,definition.facility) < definition.unlockFacilityLevel: return _fail("%s Lv.%d 필요" % [_facility_name(data,str(definition.facility)),int(definition.unlockFacilityLevel)])
				var spec: Dictionary = definition.levels[current]
				if not _pay(meta,spec.cost): return false
				_job(g,"research",id,now,spec.durationMs/_speed(data,g,"research",ids),ids,{"targetLevel":current+1})
			else:
				if not config.recipes.has(id): return _fail("알 수 없는 조합법이에요")
				if level(g,"workshop") <= 0: return _fail("장비공방을 먼저 지어야 해요")
				if id in g.unlockedRecipeIds: return _fail("이미 해금한 조합법이에요")
				if config.recipes[id].blueprintId not in g.blueprints: return _fail("설계도가 필요해요 · 탐험에서 얻을 수 있어요")
				var recipe: Dictionary = config.recipes[id]
				if not _pay(meta,recipe.cost): return false
				_job(g,"recipe",id,now,recipe.durationMs/_speed(data,g,"research",ids),ids)
		"expedition":
			if not config.expeditions.has(id): return _fail("알 수 없는 탐험이에요")
			if level(g,"expedition") <= 0: return _fail("탐험본부를 먼저 지어야 해요")
			if ids.is_empty(): return _fail("보낼 직원을 고르세요")
			if ids.size() > effects.expeditionPartySize: return _fail("한 번에 %d명까지 보낼 수 있어요" % int(effects.expeditionPartySize))
			if not _free(g,ids): return _fail("고른 직원 중 작업 중인 사람이 있어요")
			if HeroMeta.cleared_depth(meta) < int(config.expeditions[id].get("minDepth",0)): return _fail("게이트 %d층 클리어 필요" % int(config.expeditions[id].minDepth))
			if g.jobs.filter(func(job): return job.type == "expedition").size() >= effects.expeditionTeams: return _fail("탐험팀이 모두 나가 있어요")
			var definition: Dictionary = config.expeditions[id]
			if not _pay(meta,definition.cost): return false
			var reward := HeroGuildState.rewards()
			var bonus: float = (1.0+HeroGuildClock.work_bonus(data,g,ids,"expedition"))*(1.0+maxi(0,level(g,"expedition")-1)*b.expeditionRewardPerFacilityLevel)
			bonus *= HeroMeta.region_multiplier(data,meta)
			for key in HeroGuildState.RESOURCES: reward[key] = floori(definition.baseRewards.get(key,0)*bonus)
			# Results are fixed at dispatch so reconnecting cannot reroll them.
			if _roll(rng) < float(definition.get("supplyTicketChance",0.0)): reward.supplyTickets = 1
			if int(definition.get("fragmentAmount",0)) > 0:
				var pick := HeroMeta.pick_fragment(data,meta,data.daily.kindWeights,func(): return _roll(rng))
				reward[pick.key][pick.id] = int(definition.fragmentAmount)
			var pool: Array = definition.rareBlueprintIds.filter(func(key): return key not in g.blueprints and key not in g.pendingRewards.blueprintIds and not g.jobs.any(func(job): return key in job.get("rewards",{}).get("blueprintIds",[])))
			if not pool.is_empty() and _roll(rng) < minf(1.0,definition.rareChance+effects.expeditionRarityBonus): reward.blueprintIds.append(pool[mini(pool.size()-1,floori(_roll(rng)*pool.size()))])
			_job(g,"expedition",id,now,definition.durationMs,ids,{"rewards":reward})
		"production":
			var kind: String = str(args.get("kind",""))
			if not b.productionFragmentUnlockLevels.has(kind) or level(g,"production") < b.productionFragmentUnlockLevels[kind]: return false
			var collection: String = {"character":"characters","weapon":"weapons","blessing":"blessings"}[kind]
			if not data[collection].has(id): return false
			if kind != "blessing" and meta["sharedWeapons" if kind == "weapon" else "characters"][id].unlocked: return false
			g.productionTargets[kind+"Id"] = id
		"claim":
			var reward: Dictionary = g.pendingRewards
			g.pendingRewards = HeroGuildState.rewards(); g.productionAccumulated = 0.0
			for key in HeroGuildState.RESOURCES: g.wallet[key] += reward[key]
			for key in HeroGuildState.FRAGMENTS:
				for content_id in reward[key]: meta[HeroGuildState.FRAGMENTS[key]][content_id].fragments += reward[key][content_id]
			for grade in reward.revivalStones: meta.wallet.revivalStones[grade] += reward.revivalStones[grade]
			meta.wallet.supplyTickets += int(reward.get("supplyTickets",0))
			for blueprint in reward.blueprintIds:
				if blueprint not in g.blueprints: g.blueprints.append(blueprint)
		"itemUpgrade":
			if not data.items.has(id): return _fail("아이템을 먼저 고르세요")
			if level(g,"workshop") <= 0: return _fail("장비공방을 먼저 지어야 해요")
			if _has(g,["itemUpgrade"]): return _fail("장비공방이 다른 강화를 진행 중이에요")
			var current: int = g.itemLevels.get(id,0)
			if current >= b.maxItemLevel: return _fail("최고 강화 단계예요")
			var spec: Dictionary = b.itemUpgradeLevels[current]
			if not _pay(meta,spec.cost): return false
			_job(g,"itemUpgrade",id,now,spec.durationMs/_speed(data,g,"workshop"),[],{"targetLevel":current+1})
		"manufacture":
			if level(g,"revival") <= 0: return _fail("생환공방을 먼저 지어야 해요")
			if _has(g,["manufacture"]): return _fail("이미 생환석을 만들고 있어요")
			var cost: Dictionary = b.manufactureCost.duplicate()
			cost.materials = ceili(cost.materials*effects.stoneCostMultiplier)
			if not _pay(meta,cost): return false
			var value := _roll(rng)
			var grade := "high" if value < effects.stoneHighChance else "mid" if value < effects.stoneHighChance+effects.stoneMidChance else "low"
			var reward := HeroGuildState.rewards(); reward.revivalStones[grade] = 1
			_job(g,"manufacture",grade,now,b.manufactureDurationMs/_speed(data,g,"revival"),[],{"rewards":reward})
		"synthesize":
			if id not in ["low","mid"]: return _fail("합성할 생환석을 고르세요")
			if not effects.canSynthesizeStones: return _fail("생환석 합성 연구가 필요해요")
			if meta.wallet.revivalStones[id] < b.synthesisStoneCount: return _fail("같은 등급 생환석 %d개가 필요해요" % int(b.synthesisStoneCount))
			if not _pay(meta,b.synthesisCost): return false
			meta.wallet.revivalStones[id] -= b.synthesisStoneCount
			meta.wallet.revivalStones["mid" if id == "low" else "high"] += 1
		"exclude":
			var kind: String = str(args.get("kind",""))
			if kind not in ["weapon","item"] or not data["weapons" if kind == "weapon" else "items"].has(id): return false
			var excluded: Array = g["excludedWeaponIds" if kind == "weapon" else "excludedItemIds"]
			if id in excluded: excluded.erase(id)
			else:
				var slots: int = effects.weaponExclusionSlots if kind == "weapon" else effects.itemExclusionSlots
				if slots <= 0: return _fail("등장 제외는 연구실의 '선별 납품' 연구 후 쓸 수 있어요")
				if excluded.size() >= slots: return _fail("제외 칸 %d개를 모두 썼어요 · 하나를 풀고 다시 고르세요" % slots)
				excluded.append(id)
		"affix":
			if level(g,"analysis") <= 0: return _fail("각성분석실을 먼저 지어야 해요")
			if not data.characters.has(id) or not meta.characters[id].unlocked: return _fail("해금한 각성자만 분석할 수 있어요")
			if not g.pendingAffix.is_empty(): return _fail("이전 분석 결과를 먼저 정하세요")
			var cost: Dictionary = b.affixCost.duplicate()
			# The association's fixed fee is independent of guild work speed.
			for key in cost:
				if key != "associationCoins": cost[key] = ceili(cost[key]/_speed(data,g,"analysis"))
			if not _pay(meta,cost): return false
			var pool: Array = config.affixPool
			var definition: Dictionary = pool[mini(pool.size()-1,floori(_roll(rng)*pool.size()))]
			g.pendingAffix = {"characterId":id,"option":{"stat":definition.stat,"operation":definition.operation,"value":snappedf(lerpf(definition.min,definition.max,_roll(rng)),0.0001)}}
		"resolveAffix":
			if g.pendingAffix.is_empty() or id != g.pendingAffix.characterId: return false
			if args.get("accept",false): g.characterAffixes[id] = g.pendingAffix.option.duplicate(true)
			g.pendingAffix = {}
		"speedup":
			var found: Array = g.jobs.filter(func(job): return job.id == id)
			if found.is_empty(): return false
			var job: Dictionary = found[0]
			if job.endsAt <= now: return _fail("이미 끝난 작업이에요")
			if args.get("method","") == "ticket":
				if g.wallet.speedupTickets <= 0: return _fail("가속권이 없어요")
				g.wallet.speedupTickets -= 1
				job.endsAt = maxf(now,job.endsAt-b.speedupTicketMs/1000.0)
			elif args.get("method","") == "coins":
				var cost := ceili((job.endsAt-now)/60.0)*int(b.speedupCoinsPerMinute)
				if g.wallet.coins < cost: return _fail("길드 코인 %d 부족" % (cost-int(g.wallet.coins)))
				g.wallet.coins -= cost; job.endsAt = now
			else: return false
			HeroGuildClock.advance(data,meta,now)
		_: return false
	return true

# Dry run on a copy: returns why the command would be refused now, or "" if it would work.
static func check(data: Dictionary, meta: Dictionary, action: String, args: Dictionary) -> String:
	var copy: Dictionary = meta.duplicate(true)
	var now := maxf(Time.get_unix_time_from_system(),float(meta.guild.get("lastAdvancedAt",0.0)))
	var accepted := act(data,copy,action,args,now,func(): return 0.5)
	var reason := "" if accepted else last_error
	last_error = ""
	return reason

static func _roll(rng: Callable) -> float:
	var value: float = rng.call() if rng.is_valid() else randf()
	return clampf(value,0.0,0.999999999) if is_finite(value) else 0.0
