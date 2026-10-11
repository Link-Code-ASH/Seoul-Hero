class_name HeroEliteHud
extends RefCounted

# Combat HUD additions for featured elites: the kill-supply/surge banner and the surge tag.
# An elite or boss arriving and an elite escaping put no text on screen.
# Elites and bosses carry no name; their HP shows only on the overhead bar in the world.
const SURGE := Rect2(342,68,230,24)

static func build(root: Control, run: HeroRun) -> void:
	# The surge tag sits on the night-ops row plate so it stays legible over any map art.
	var backing := HeroImageSkin.material(root,"ops/row",SURGE.grow_individual(8,1,8,1)); backing.name = "SurgeBacking"
	var surge := HeroCombatUI._hud_text(root,"",SURGE,"control",14,HORIZONTAL_ALIGNMENT_CENTER)
	surge.name = "SurgeTag"
	surge.add_theme_color_override("font_color",Color("ffb45e"))
	var banner := HeroCombatUI._hud_text(root,"",Rect2(157,126,600,32),"heading",20,HORIZONTAL_ALIGNMENT_CENTER)
	banner.name = "EliteBanner"
	banner.add_theme_color_override("font_color",Color("ffe08a"))
	update(root,run)

static func update(root: Control, run: HeroRun) -> void:
	var surge := root.find_child("SurgeTag",true,false) as Label
	if surge:
		var rule := HeroFeaturedElites.surge(run)
		surge.text = "" if rule.is_empty() else "%s · 생성·마력석 ×%s" % [rule.name,str(rule.rewardMultiplier)]
		surge.modulate.a = 0.88 + sin(run.combat_time * 9.0) * 0.12
		var backing := root.find_child("SurgeBacking",true,false) as Control
		if backing: backing.visible = not rule.is_empty()
	var banner := root.find_child("EliteBanner",true,false) as Label
	if banner:
		var age: float = run.combat_time - float(run.notice.time)
		var life := float(run.data.featuredElites.announceSeconds)
		banner.text = str(run.notice.text) if age >= 0.0 and age < life else ""
		banner.modulate.a = clampf((life - age) / 0.5,0.0,1.0)
