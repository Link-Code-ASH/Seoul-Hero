extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	_check.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func _check() -> void:
	var data: Dictionary = Content.data
	var legacy: Dictionary = data.defaultMeta.duplicate(true)
	legacy.wallet.associationCoins = 987
	legacy.association.upgrades = {"vitality":2}
	legacy.characters.awakener.breakthrough = 3
	legacy.guild.facilityLevels.training = 3
	var migrated: Dictionary = Profile._migrate({"formatVersion":1,"meta":legacy})
	expect(not migrated.is_empty(),"v1 migration")
	expect(migrated.meta.wallet.associationCoins == 987 and migrated.meta.association.upgrades.vitality == 2 and migrated.meta.characters.awakener.breakthrough == 3,"non-guild account progress preserved")
	expect(migrated.meta.guild.wallet.coins == 200 and migrated.meta.guild.facilities.office.level == 1 and not migrated.meta.guild.has("facilityLevels"),"only old guild reset; no refund")
	expect(Profile._migrate({"formatVersion":3,"meta":legacy}).is_empty(),"future profile rejected")
	var bad: Dictionary = migrated.duplicate(true); bad.meta.guild.employees[0].experience = -1
	expect(Profile._migrate(bad).is_empty(),"corrupted nested guild rejected")
	var meta: Dictionary = migrated.meta
	HeroMeta.initialize(data,meta)
	meta.guild.lastAdvancedAt = 1000.0
	meta.guild.facilities.production = {"level":1,"slot":1}
	meta.guild.employees[0].assignment = "production"
	meta.guild.employees[0].experience = 19.0
	meta.guild.productionCarry.coins = 0.25
	var one: Dictionary = meta.duplicate(true); var split: Dictionary = meta.duplicate(true)
	HeroGuildClock.advance(data,one,1000.0+6*3600.0)
	HeroGuildClock.advance(data,split,1000.0+360.0)
	HeroGuildClock.advance(data,split,1000.0+6*3600.0)
	expect(one.guild.pendingRewards == split.guild.pendingRewards and absf(one.guild.productionCarry.coins-split.guild.productionCarry.coins)<0.00001 and one.guild.employees==split.guild.employees,"level boundaries independent of reload frequency")
	var before: Dictionary = one.guild.pendingRewards.duplicate(true)
	HeroGuildClock.advance(data,one,one.guild.lastAdvancedAt)
	expect(one.guild.pendingRewards==before,"same timestamp never pays twice")
	var round_trip: Variant = JSON.parse_string(JSON.stringify({"formatVersion":2,"meta":one}))
	expect(Profile._valid(round_trip),"v2 complete nested state round-trip")
	one.guild.productionAccumulated = 24*3600.0
	one.guild.employees[0].level = 1; one.guild.employees[0].experience = 0.0
	before = one.guild.pendingRewards.duplicate(true)
	HeroGuildClock.advance(data,one,one.guild.lastAdvancedAt+96*3600.0)
	expect(one.guild.pendingRewards==before and one.guild.employees[0].level==5,"full storage caps rewards but not work experience")
	var g: Dictionary = meta.guild
	g.wallet.coins = 9999; g.facilities.expedition = {"level":1,"slot":2}
	var now: float = g.lastAdvancedAt
	expect(HeroGuildRules.act(data,meta,"expedition",{"id":"cityScout","employees":["staffMinJae"]},now,func(): return 0.01),"expedition dispatch")
	var job: Dictionary = g.jobs[0].duplicate(true)
	expect(not HeroGuildRules.act(data,meta,"assign",{"id":"staffMinJae","facility":"office"},now),"reserved employee cannot move")
	var resumed: Dictionary = JSON.parse_string(JSON.stringify(meta))
	HeroGuildClock.advance(data,resumed,job.endsAt+72*3600.0)
	expect(resumed.guild.pendingRewards.materials==job.rewards.materials and resumed.guild.pendingRewards.blueprintIds==job.rewards.blueprintIds,"saved random reward survives days offline")
	before = resumed.guild.pendingRewards.duplicate(true)
	HeroGuildClock.advance(data,resumed,job.endsAt+72*3600.0)
	expect(resumed.guild.pendingRewards==before and resumed.guild.jobs.is_empty(),"completed expedition removed once")
	expect(HeroGuildRules.act(data,resumed,"claim",{},resumed.guild.lastAdvancedAt),"claim settled rewards")
	var wallet_before: Dictionary = resumed.guild.wallet.duplicate()
	HeroGuildRules.act(data,resumed,"claim",{},resumed.guild.lastAdvancedAt)
	expect(wallet_before==resumed.guild.wallet,"claim never duplicates rewards")
	resumed.guild.facilities.analysis = {"level":1,"slot":3}; resumed.guild.wallet.coins=9999; resumed.guild.wallet.materials=9999; resumed.guild.wallet.researchData=9999
	expect(HeroGuildRules.act(data,resumed,"affix",{"id":"awakener"},resumed.guild.lastAdvancedAt,func(): return 0.3),"affix draw")
	var paid: Dictionary = resumed.guild.wallet.duplicate(); var pending: Dictionary = resumed.guild.pendingAffix.duplicate(true)
	var reloaded: Dictionary = JSON.parse_string(JSON.stringify(resumed))
	expect(not HeroGuildRules.act(data,reloaded,"affix",{"id":"awakener"},reloaded.guild.lastAdvancedAt) and HeroGuildState.RESOURCES.all(func(key): return float(reloaded.guild.wallet[key])==float(paid[key])) and reloaded.guild.pendingAffix.characterId==pending.characterId and reloaded.guild.pendingAffix.option.stat==pending.option.stat and absf(reloaded.guild.pendingAffix.option.value-pending.option.value)<0.0000001,"pending affix protects cost and draw across reconnect")
	expect(HeroGuildRules.act(data,reloaded,"resolveAffix",{"id":"awakener","accept":true},reloaded.guild.lastAdvancedAt) and reloaded.guild.pendingAffix.is_empty(),"affix choice committed once")
	print("Guild migration / persistence boundary checks: ",checks,"; failures: ",failures,"; profile writes: false")
	get_tree().quit(1 if failures>0 else 0)
