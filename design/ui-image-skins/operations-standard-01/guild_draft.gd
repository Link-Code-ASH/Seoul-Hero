extends RefCounted

# Independent frozen composition. All figures are illustrative; no profile or jobs run.
const WORLD = preload("res://world.gd")
const BUILDING_RECT := Rect2(12,72,547,328)
const PANE_RECT := Rect2(573,72,330,328)
const FACILITIES := ["office","research","expedition","production","recovery","workshop","revival","analysis"]

static func build(ui, parent: Control) -> void:
	var backdrop: TextureRect = ui.image(parent,"premiumLobbyRain",Rect2(0,0,915,412),false,true)
	backdrop.modulate = Color(0.52,0.59,0.70,1.0)
	_header(ui,parent)
	_building(ui,parent)
	_management(ui,parent)

static func _header(ui, parent: Control) -> void:
	ui.header(parent,"길드 본부","","",{"title_width":300})
	var resources := [["길드 코인","2,460"],["마력자재","185"],["연구자료","42"],["가속권","3"]]
	for index in range(resources.size()):
		_resource(ui,parent,str(resources[index][0]),str(resources[index][1]),Vector2(446+index*130,38))

static func _resource(ui, parent: Control, caption: String, amount: String, center: Vector2) -> void:
	var name_width := ceilf(ui.font("aux").get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x)+2.0
	var amount_width := ceilf(ui.font("number").get_string_size(amount,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x)+2.0
	var left := center.x-(name_width+6.0+amount_width)*0.5
	ui.text(parent,caption,Rect2(left,center.y-14,name_width,28),"aux",13,"scene")
	ui.text(parent,amount,Rect2(left+name_width+6.0,center.y-16,amount_width,32),"number",18,"scene")

static func _building(ui, parent: Control) -> void:
	var viewport := Control.new()
	viewport.position = BUILDING_RECT.position; viewport.size = BUILDING_RECT.size
	viewport.clip_contents = true; viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(viewport)
	var world := WORLD.new()
	viewport.add_child(world)
	world.configure(_world_assets(ui)); world.set_viewport_width(BUILDING_RECT.size.x)
	var facilities: Array = []
	var levels := [7,4,1,7,1,4,1,1]
	for slot in range(FACILITIES.size()):
		facilities.append({"id":FACILITIES[slot],"slot":slot,"level":levels[slot],"construction":slot==6})
	world.set_model({"unlockedFloors":3,"selectedSlot":5,"facilities":facilities,"staff":[
		{"id":"staffSeoYeon","slot":3,"activity":"work","level":2},
		{"id":"staffMinJae","slot":2,"activity":"expedition","level":1},
		{"id":"staffHaEun","slot":5,"activity":"research","level":3},
		{"id":"staffSiWoo","slot":0,"activity":"office","level":2}]})
	world._process(0.0)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.position.y = -clampf(world.floor_center(2).y-BUILDING_RECT.size.y*0.5,0.0,maxf(0.0,world.get_content_height()-BUILDING_RECT.size.y))
	ui.controls.append({"caption":"길드 건물 내부 스크롤","role":"frozen building preview","rect":[12,72,547,328],"minimum44":true})

static func _world_assets(ui) -> Dictionary:
	var visuals: Dictionary = ui.json_file(ui.repo_dir.path_join("godot/data/visuals/guild.json"))
	var staff: Dictionary = ui.actor_visuals.npcs.hanSeoa.duplicate(true)
	var awakener: Dictionary = ui.actor_visuals.characters.awakener.duplicate(true)
	var staff_texture := _actor_texture(ui,staff)
	var awakener_texture := _actor_texture(ui,awakener)
	staff.texture = staff_texture; awakener.texture = awakener_texture
	var rows := {}; var names := {}
	for index in range(FACILITIES.size()):
		rows[FACILITIES[index]] = index
		names[FACILITIES[index]] = str(ui.content.guildManagement.facilities[FACILITIES[index]].name)
	return {"rooms":ui.texture(str(visuals.rooms.file),false),"states":ui.texture(str(visuals.states.file),false),"structure":ui.texture(str(visuals.walk.file),false),"structure_meta":visuals.walk,"staff_texture":staff_texture,"awk_texture":awakener_texture,"staff_profile":staff,"awk_profile":awakener,"roomRows":rows,"roomNames":names,"font":ui.font("heading")}

static func _actor_texture(ui, profile: Dictionary) -> Texture2D:
	var file: String = ui.repo_dir.path_join("godot/"+str(profile.sprite).trim_prefix("res://"))
	var bitmap := Image.load_from_file(file)
	if bitmap == null or bitmap.is_empty(): return null
	var region: Array = profile.get("region",[0,0,bitmap.get_width(),bitmap.get_height()])
	bitmap = bitmap.get_region(Rect2i(int(region[0]),int(region[1]),int(region[2]),int(region[3])))
	bitmap.generate_mipmaps()
	profile.region = [0,0,bitmap.get_width(),bitmap.get_height()]
	return ImageTexture.create_from_image(bitmap)

static func _management(ui, parent: Control) -> void:
	var pane := Control.new()
	pane.position = PANE_RECT.position; pane.size = PANE_RECT.size
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(pane)
	ui.material(pane,"ops/info",Rect2(0,0,330,328))
	ui.text(pane,"장비공방",Rect2(20,12,214,28),"heading",18,"ink")
	ui.button(pane,"닫기",Rect2(250,9,64,44),"ops/secondary",16)
	ui.text(pane,"2층 · 사무실 3 · Lv.4 / 10",Rect2(20,45,290,23),"body",14,"muted")
	for index in range(3):
		ui.button(pane,["관리","직원","작업"][index],Rect2(20+index*100,75,90,44),"ops/tab_selected" if index == 0 else "ops/tab",16)
	ui.text(pane,"아이템 영구 강화 · 조합법 연구",Rect2(20,132,290,28),"body",14,"ink")
	ui.material(pane,"ops/row",Rect2(20,167,290,78))
	ui.text(pane,"다음 단계 · Lv.5",Rect2(32,174,266,22),"control",16,"ink")
	var definition: Dictionary = ui.content.guildManagement.facilities.workshop
	var price: Dictionary = definition.levels[4].cost
	ui.text(pane,"길드 코인 %s · 자재 %s" % [str(int(price.coins)),str(int(price.materials))],Rect2(32,200,266,20),"aux",13,"muted")
	ui.text(pane,"연구자료 %s" % str(int(price.researchData)),Rect2(32,222,266,18),"aux",13,"muted")
	ui.button(pane,"시설 강화",Rect2(20,255,290,44),"ops/primary",16)
	ui.text(pane,"조합법과 영구 강화는 관리 탭에서 확인",Rect2(20,302,290,20),"aux",13,"muted")
