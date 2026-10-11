extends Node

var art: Dictionary
var profile: Dictionary
var canvas := CanvasLayer.new()
var folder: String

func _ready() -> void:
	_capture.call_deferred()

func _capture() -> void:
	if Profile.writable: get_tree().quit(1); return
	folder = ProjectSettings.globalize_path("res://../design/ui-image-skins/guild-management-01")
	var visuals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visuals/guild.json"))
	art = {"rooms":Content.texture(visuals.rooms.file),"states":Content.texture(visuals.states.file),"facilityOrder":visuals.rooms.facility_order,"tiers":visuals.rooms.tiers}
	DisplayServer.window_set_size(Vector2i(915,412)); add_child(canvas)
	profile = Content.data.defaultMeta.duplicate(true); HeroMeta.initialize(Content.data,profile)
	profile.guild = HeroGuildState.create(Content.data,Time.get_unix_time_from_system())
	HeroMeta.weekly(Content.data,profile,Time.get_unix_time_from_system())
	await _screen("01-office",{})
	var g: Dictionary = profile.guild
	g.wallet = {"coins":1480,"materials":360,"researchData":85,"speedupTickets":4}
	var slot := 0
	for id in g.facilities:
		g.facilities[id] = {"level":7 if id=="office" else 5 if id=="production" else 3 if id in ["research","expedition","recovery"] else 1,"slot":slot}; slot += 1
	g.researchLevels = {"offlineCapacity":3,"productionEfficiency":2,"expeditionTeams":2,"expeditionParty":2,"shopExclusions":4}
	g.employees[0].assignment = "production"; g.employees[1].assignment = "expedition"
	g.employees.append({"id":"staffJiWoo","assignment":"research","level":3,"experience":16.0})
	g.jobs = [{"id":"1","type":"construction","targetId":"workshop","targetLevel":2,"slot":5,"startedAt":Time.get_unix_time_from_system(),"endsAt":Time.get_unix_time_from_system()+280,"employeeIds":[]}]
	g.pendingRewards.coins = 248; g.productionAccumulated = 14400.0
	await _screen("02-building",{"slot":5})
	await _screen("03-production",{"slot":3})
	await _screen("04-staff",{"panel":"staff"})
	await _screen("05-expedition",{"panel":"expedition"})
	await _screen("06-jobs",{"panel":"jobs"})
	await _screen("07-workshop",{"slot":5})
	var run := HeroRun.new(Content.data,{"character":"awakener","weapon":"manaBolt","map":"seoul","depth":1,"weekly":profile.weeklyGate.ruleId,"blessing":""},profile)
	run.phase = "shop"; run.items = {"lens":1,"energyDrink":1,"riceBall":1,"vest":1,"wallet":1,"magnet":1}
	run.guild_support.unlockedRecipeIds = Content.data.guildManagement.recipes.keys()
	var root := HeroImageSkin.root(); HeroUI.background(root,"premiumLobbyRain")
	HeroGuildScreen.crafting_dialog(root,run,func(): pass)
	await _capture_control(root,"08-crafting")
	var shop := HeroShopScreen.build(run,true,func(_tab): pass,func(): pass,func(): pass,func(): pass)
	await _capture_control(shop,"09-shop")
	print("Guild PNG previews: ",folder," (isolated state; no saves)")
	get_tree().quit()

func _screen(id: String, overrides: Dictionary) -> void:
	var ui := {"panel":"facility","slot":0,"employee":"","expedition":"cityScout","selectedStaff":[]}
	ui.merge(overrides,true)
	var screen := HeroGuildScreen.build(profile,func(_a,_b): pass,func(): pass,func(): pass,art,ui)
	await _capture_control(screen,id)

func _capture_control(screen: Control, id: String) -> void:
	canvas.add_child(screen)
	for frame in range(5): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	image.save_png(folder.path_join(id+".png"))
	image.save_jpg(folder.path_join(id+".jpg"),0.86)
	canvas.remove_child(screen); screen.queue_free()
