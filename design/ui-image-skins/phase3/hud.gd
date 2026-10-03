extends RefCounted
# Frozen battle illustration and independent HUD/pause proposals only.
static func build(ui, parent: Control, screen: String) -> void:
	_world(ui,parent)
	if screen.contains("pause"): _pause(ui,parent)
	else: _hud(ui,parent,screen.contains("low"))

static func _world(ui, parent: Control) -> void:
	ui.image(parent,ui.content.maps.seoul.thumbnail,Rect2(0,0,915,412),false,true)
	var actors := [
		["crawler",Vector2(164,137)],["swarm",Vector2(261,100)],["runner",Vector2(631,152)],
		["crawler",Vector2(742,227)],["swarm",Vector2(333,315)],["crawler",Vector2(553,336)],
		["bulwark",Vector2(700,341)],["spitter",Vector2(616,280)],["crawler",Vector2(186,293)],
		["swarm",Vector2(807,119)],["runner",Vector2(297,220)],["crawler",Vector2(485,130)]
	]
	for fixture in actors:
		var enemy: Dictionary = ui.content.enemies[fixture[0]]
		var base := float(enemy.radius)*2.6*(915.0/1600.0)
		var display := float(ui.content.enemyPresentation.get(fixture[0],{}).get("displayScale",1.0))
		var width := base*display
		var image_id := str(enemy.visual.sprite)
		var source: Texture2D = ui.texture(image_id)
		var height := width*source.get_height()/float(source.get_width())
		var point: Vector2 = fixture[1]
		var shadow: TextureRect = ui.image(parent,"res://assets/visuals/vfx/contact_shadow.png",Rect2(point.x-width*0.5,point.y-4,width,10))
		shadow.modulate.a = 0.4
		ui.image(parent,image_id,Rect2(point.x-width*0.5,point.y-height,width,height))
	var character: Dictionary = ui.content.characters.awakener
	var character_height := 98.0*0.8*(915.0/1600.0)
	var character_source: Texture2D = ui.texture(character.portraitSprite)
	var character_width := character_height*character_source.get_width()/float(character_source.get_height())
	ui.image(parent,"res://assets/visuals/vfx/contact_shadow.png",Rect2(437,237,39,9)).modulate.a = 0.44
	ui.image(parent,character.portraitSprite,Rect2(456-character_width*0.5,240-character_height,character_width,character_height))
	for point in [Vector2(317,279),Vector2(569,246),Vector2(725,282),Vector2(400,344),Vector2(125,230)]:
		ui.image(parent,"res://assets/visuals/resources/magic_stone_casual.png",Rect2(point.x,point.y,11,15))
	var projectile: TextureRect = ui.image(parent,"manaBolt",Rect2(502,210,14,29))
	projectile.pivot_offset = Vector2(7,14); projectile.rotation = -0.78
	var slash: TextureRect = ui.image(parent,"vfxSlashWide",Rect2(465,216,55,44))
	slash.modulate.a = 0.68
	var impact: TextureRect = ui.image(parent,"vfxImpact",Rect2(604,245,36,36))
	impact.modulate.a = 0.73

static func _hud(ui, parent: Control, low: bool) -> void:
	var hp := 17 if low else 84
	ui.material(parent,"console/hp_track",Rect2(20,34,190,6))
	var fill: NinePatchRect = ui.material(parent,"console/hp_fill",Rect2(20,34,190*hp/100.0,6))
	if low and fill != null: fill.modulate = Color("#e57568")
	ui.hud_text(parent,"%d / 100" % hp,Rect2(21,6,188,26),"number",21)
	ui.image(parent,"res://assets/visuals/resources/magic_stone_casual.png",Rect2(20,47,22,25))
	ui.hud_text(parent,"987,654" if low else "240",Rect2(47,45,101,28),"number",22)
	var wallet: TextureRect = ui.image(parent,"wallet",Rect2(152,47,24,25))
	wallet.modulate = Color(0.90,0.98,1.0,1)
	ui.hud_text(parent,"12,480" if low else "36",Rect2(180,45,100,28),"number",22)
	var weapons := ["manaSword","guardianDaggers","manaBolt","piercingShot","chainLightning","manaBombard"]
	for i in range(weapons.size()):
		ui.image(parent,str(ui.content.weaponArt[weapons[i]]),Rect2(20+i*39,79,33,30))
	ui.hud_text(parent,"웨이브 7 / 20",Rect2(365,8,185,26),"control",15,HORIZONTAL_ALIGNMENT_CENTER)
	ui.hud_text(parent,"00:28",Rect2(400,33,115,34),"number",27,HORIZONTAL_ALIGNMENT_CENTER)
	ui.icon(parent,"pause",Rect2(858,15,28,28))
	var hit := Button.new()
	hit.position = Vector2(850,7); hit.size = Vector2(44,44)
	for state in ["normal","hover","pressed","focus"]: hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	parent.add_child(hit)
	ui.controls.append({"caption":"일시정지","role":"unframed","rect":[850,7,44,44],"minimum44":true})

static func _pause(ui, parent: Control) -> void:
	ui.wash(parent,Color(0.07,0.13,0.20,0.42))
	ui.material(parent,"command/panel",Rect2(294,84,327,250))
	ui.material(parent,"command/title",Rect2(317,105,281,43))
	ui.text(parent,"일시정지",Rect2(328,108,259,36),"heading",24,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(parent,"광화문 광장 · 심도 6",Rect2(317,160,281,29),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(parent,"7 / 20 웨이브",Rect2(317,192,281,29),"control",16,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	ui.button(parent,"계속하기",Rect2(325,233,265,44),"controls/primary",17)
	ui.button(parent,"출동 종료",Rect2(325,281,265,44),"controls/secondary",16)
	ui.labels.back().add_theme_color_override("font_color",ui.color("danger"))
