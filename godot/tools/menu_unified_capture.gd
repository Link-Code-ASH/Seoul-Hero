extends Node

# Baseline, approval, and applied screenshots from real UI builders and callbacks. Both preview flags
# are mandatory: Profile never reads or writes player files in this isolated mode.
const FIXED_SEED := 20261011
const FIXED_WEEK := 2961
const ARCHIVE_GROUPS := ["characters","weapons","enemies","items","weeklyRules","blessings"]
const GATE_STEPS := ["map","floor","character","weapon","blessing","formation"]
var output := ""
var stage := "before"
var main_scene: Node
var shots: Array = []
var checks: Array = []
var baseline_meta: Dictionary
var blessing_id := ""
var capture_clock := 0.0
var animation_nodes: Array[Node] = []
var shader_materials: Array[ShaderMaterial] = []
var parse_only := false
var representative_only := false
var refresh_only := false
var production_presentation_default := false
var focus_check_only := false

func _ready() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count): await get_tree().process_frame

func _check(title: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"title":title,"passed":passed,"detail":detail})
	print("[%s] %s %s" % ["ok" if passed else "FAIL",title,str(detail)])

func _freeze(node: Node) -> void:
	node.set_process(false)
	if node.name == "OfficeKeyMotion" and "_focused" in node:
		node.set("_focused",true)
		if node.has_method("set_hover_for_capture"): node.set_hover_for_capture(false)
		if node.has_method("_reset"): node._reset()
	if "clock" in node or node.has_method("advance_for_capture"):
		if "clock" in node: node.set("clock",0.0)
		if "capture_clock" in node: node.set("capture_clock",true)
		if node.has_method("advance_for_capture"): node.advance_for_capture(0.0)
		animation_nodes.append(node)
		if node is CanvasItem: node.queue_redraw()
	if node is CanvasItem and node.material is ShaderMaterial:
		var material: ShaderMaterial = node.material
		if "TIME" in material.shader.code:
			var shader := Shader.new()
			# shader_type must remain the first declaration in Godot shader syntax.
			shader.code = material.shader.code.replace("TIME","capture_clock_value").replace("void fragment()", "uniform float capture_clock_value = 0.0;\nvoid fragment()")
			material.shader = shader
			shader_materials.append(material)
	for child in node.get_children(): _freeze(child)

func _advance(delta: float) -> void:
	capture_clock += delta
	for tween: Tween in get_tree().get_processed_tweens(): tween.custom_step(delta)
	for node in animation_nodes:
		if not is_instance_valid(node): continue
		if node.has_method("advance_for_capture"): node.advance_for_capture(delta)
		else:
			node.set("clock",capture_clock)
			if node is CanvasItem: node.queue_redraw()
	for material in shader_materials: material.set_shader_parameter("capture_clock_value",capture_clock)

func _mount_screen(screen: String) -> void:
	main_scene.screen = screen
	main_scene._render()
	await _frames(3)
	for tween: Tween in get_tree().get_processed_tweens(): tween.custom_step(1.0)
	await _frames(2)
	capture_clock = 0.0
	animation_nodes.clear(); shader_materials.clear()
	_freeze(main_scene.view)
	await _frames(2)

func _shot(id: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	_check(id+" viewport",image.get_size() == Vector2i(915,412))
	image.save_png(output.path_join(id+".png"))
	var record := {"file":id+".png","screen":main_scene.screen,"gateStep":main_scene.gate_step,"draft":main_scene.draft.duplicate(true),"archive":main_scene.archive.duplicate(true),"associationId":main_scene.growth.get("associationId",""),"coins":Profile.meta.wallet.associationCoins}
	var previous := -1
	for i in range(shots.size()):
		if shots[i].file == id+".png": previous = i; break
	if previous >= 0: shots[previous] = record
	else: shots.append(record)

func _node(name: String) -> Node:
	return main_scene.view.find_child(name,true,false)

func _signal(name: String, event: String = "pressed") -> bool:
	var target := _node(name)
	if target == null or not target.has_signal(event):
		_check("Native control exists: "+name,false)
		return false
	target.emit_signal(event)
	await _frames(4)
	return true

func _refresh_current() -> void:
	await _mount_screen(main_scene.screen)

func _reset_state() -> void:
	Profile.meta = baseline_meta.duplicate(true)
	main_scene.draft = {"map":"seoul","depth":1,"character":"awakener","weapon":"manaBolt","blessing":blessing_id,"weekly":Profile.meta.weeklyGate.ruleId,"week":FIXED_WEEK}
	main_scene.gate_ui = {"inspected":{},"scroll":{}}

func _hover_button(target: Button, enabled: bool) -> void:
	var motion := target.get_node_or_null("OfficeKeyMotion")
	if motion != null and motion.has_method("set_hover_for_capture"):
		motion.set_hover_for_capture(enabled)
	else:
		target.emit_signal("mouse_entered" if enabled else "mouse_exited")

func _preview_states() -> void:
	# Native sliders apply in memory; backup/import/folder actions are never invoked.
	_reset_state()
	await _mount_screen("settings")
	var volume: HSlider = _node("Volume_masterVolume")
	_check("Four native volume sliders",main_scene.view.find_children("Volume_*","HSlider",true,false).size() == 4)
	if volume:
		volume.value = 55
		await _frames(3)
		_check("Volume callback updates only synthetic memory",is_equal_approx(float(Profile.meta.settings.masterVolume),0.55) and not Profile.writable)
		await _shot("settings-slider")
	_reset_state()
	main_scene.archive = {"group":"characters","id":"awakener","page":0,"growthPage":0,"map":"seoul","scroll":0}
	await _mount_screen("archive")
	await _signal("ArchiveTab_weapons")
	_check("Archive native category callback",main_scene.archive.group == "weapons")
	var entries := HeroArchive.entries(main_scene.archive)
	if entries.size() > 1:
		await _signal("Archive_"+str(entries[1]))
		_check("Archive native item callback",main_scene.archive.id == str(entries[1]))
	await _signal("ArchivePage_1")
	_check("Archive detail tab callback",main_scene.archive.page == 1)
	await _refresh_current()
	await _shot("archive-weapon-detail")
	main_scene.archive = {"group":"items","id":str(Content.data.items.keys()[0]),"page":0,"growthPage":0,"map":"seoul","scroll":0}
	await _mount_screen("archive")
	var collection: ScrollContainer = _node("ArchiveCollection")
	if collection:
		collection.scroll_vertical = 130
		await _frames(3)
		_check("Archive list scroll works",collection.scroll_vertical > 0)
		await _shot("archive-items-scroll")
	_reset_state()
	main_scene.growth.associationId = "draw:blessing"
	Profile.meta.wallet.associationCoins = 0
	await _mount_screen("association")
	_check("Insufficient funds disable draw",bool(_node("AssociationDraw").disabled))
	await _shot("association-no-funds")
	for id in Profile.meta.blessings: Profile.meta.blessings[id].unlocked = true
	Profile.meta.wallet.associationCoins = 1850
	await _mount_screen("association")
	_check("Complete collection disables draw",bool(_node("AssociationDraw").disabled))
	await _shot("association-complete")
	_reset_state()
	main_scene.growth.associationId = "circuit"
	await _mount_screen("association")
	await _shot("association-locked")
	Profile.meta.association.upgrades["circuit"] = 1
	await _mount_screen("association")
	_check("Unlocked one-time content disables purchase",bool(_node("AssociationBuy").disabled))
	await _shot("association-unlocked")
	if stage == "applied":
		await _association_feedback_states()
	else:
		_reset_state()
		main_scene.growth.associationId = "draw:blessing"
		await _mount_screen("association")
		var reward_meta := Profile.meta.duplicate(true)
		HeroMetaScreens.rewards_popup(main_scene.view,[{"type":"characterUnlock","contentId":"awakener","amount":1}],"협회 뽑기")
		await _frames(3)
		for tween: Tween in get_tree().get_processed_tweens(): tween.custom_step(1.0)
		await _frames(2)
		_check("Reward popup opens without payout",_node("AssociationRewardOverlay") != null and Profile.meta == reward_meta)
		await _shot("association-reward")
		await _settle_reward()
		await _shot("association-reward-settled")
		await _signal("AssociationRewardConfirm")
		_check("Reward confirm closes without payout",_node("AssociationRewardOverlay") == null and Profile.meta == reward_meta)
	_reset_state()
	main_scene.gate_step = 0
	await _mount_screen("gate")
	await _signal("GatePrimary")
	_check("Gate next preserves six-step route",main_scene.gate_step == 1)
	await _signal("DepthPageNext")
	_check("Floor page callback selects 21",main_scene.draft.depth == 21)
	await _refresh_current()
	await _shot("gate-floor-page")
	for kind in ["character","weapon","blessing"]:
		_reset_state()
		var table: String = {"character":"characters","weapon":"sharedWeapons","blessing":"blessings"}[kind]
		var locked_id: String = str(Content.data[{"character":"characters","weapon":"weapons","blessing":"blessings"}[kind]].keys()[1])
		if kind == "weapon": locked_id = "manaSword"
		Profile.meta[table][locked_id].unlocked = false
		main_scene.gate_step = {"character":2,"weapon":3,"blessing":4}[kind]
		await _mount_screen("gate")
		var original: String = str(main_scene.draft[kind])
		await _signal("GateChoice_"+locked_id)
		_check("Locked "+kind+" inspection preserves selected item",main_scene.gate_ui.inspected.get(kind,"") == locked_id and main_scene.draft[kind] == original)
		_check("Locked "+kind+" blocks next",bool(_node("GatePrimary").disabled))
		await _refresh_current()
		await _shot("gate-"+kind+"-locked")
	_reset_state()
	main_scene.gate_step = 4
	await _mount_screen("gate")
	await _signal("GateChoice_")
	_check("Blessing none remains selectable",main_scene.draft.blessing == "" and not bool(_node("GatePrimary").disabled))
	await _refresh_current()
	await _shot("gate-blessing-none")
	await _signal("GatePrimary")
	_check("Blessing none advances to formation",main_scene.gate_step == 5)
	await _refresh_current()
	await _shot("gate-formation-none")
	for kind in ["character","weapon","blessing"]:
		_reset_state()
		main_scene.gate_step = 5
		await _mount_screen("gate")
		await _signal("GateFormationEdit_"+kind)
		_check("Formation edits "+kind,main_scene.gate_step == {"character":2,"weapon":3,"blessing":4}[kind])
	await _signal("HeaderBack")
	_check("Native previous returns to prior gate step",main_scene.gate_step == 3)
	_reset_state()
	main_scene.gate_step = 0
	await _mount_screen("gate")
	await _signal("HeaderBack")
	_check("First gate back returns to lobby",main_scene.screen == "lobby")
	_reset_state()
	main_scene.gate_step = 5
	await _mount_screen("gate")
	await _primary_states()
	if stage == "applied":
		_check("Applied gate omits standalone subtitle and footer explanation",_node("GateSubtitle") == null and _node("GateFooterText") == null)
	_check("No gameplay or user file action during preview",main_scene.run == null and not Profile.writable)

func _primary_states() -> void:
	var primary: Button = _node("GatePrimary")
	var initial_rect: Rect2 = primary.get_global_rect()
	var face: Control = primary.get_node("Face")
	var initial_face_position := face.position
	_hover_button(primary,true)
	for i in range(24): _advance(1.0/60.0)
	await _shot("gate-primary-hover")
	primary.button_down.emit()
	for i in range(8): _advance(1.0/60.0)
	await _shot("gate-primary-pressed")
	_check("Pressed input rectangle stays fixed",primary.get_global_rect() == initial_rect)
	primary.button_up.emit(); _hover_button(primary,false)
	for i in range(24): _advance(1.0/60.0)
	await _shot("gate-primary-restored")
	_check("Pressed face returns to resting position",face.position == initial_face_position)
	primary.grab_focus()
	await _shot("gate-primary-focus")
	_check("Native focus uses no default box",primary.get_theme_stylebox("focus") is StyleBoxEmpty)
	primary.release_focus()

func _focus_check() -> void:
	_reset_state()
	main_scene.gate_step = 5
	await _mount_screen("gate")
	var primary: Button = _node("GatePrimary")
	var motion := primary.get_node("OfficeKeyMotion")
	var rect := primary.get_global_rect()
	_hover_button(primary,true)
	primary.button_down.emit()
	for i in range(6): _advance(1.0/60.0)
	_check("Application-focus check begins from pressed 1.5px with visible glint",is_equal_approx(motion.face.position.y,1.5) and is_equal_approx(motion.plate.position.y,1.5) and motion.glint.visible)
	_hover_button(primary,true)
	motion.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check("Application focus loss resets Face, Plate and glint",not motion._focused and motion.face.position.y == 0.0 and motion.plate.position.y == 0.0 and not motion.glint.visible)
	_check("Application focus loss kills hover, press and sweep tweens",(motion._hover == null or not motion._hover.is_valid()) and (motion._press == null or not motion._press.is_valid()) and (motion._sweep == null or not motion._sweep.is_valid()))
	_advance(0.5)
	_check("Application focus loss stays settled",motion.face.position.y == 0.0 and motion.plate.position.y == 0.0 and not motion.glint.visible)
	motion.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_check("Application focus return restores resting control",motion._focused and motion.face.position.y == 0.0 and motion.plate.position.y == 0.0 and not motion.glint.visible and primary.get_global_rect() == rect)
	_check("Application-focus verification preserves memory and save boundary",Profile.meta == baseline_meta and not Profile.writable and main_scene.run == null)
	var file := FileAccess.open(output.path_join("focus_check.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"stage":stage,"freshProcess":true,"visualChanges":false,"checks":checks},"  "))
	print("MENU_UNIFIED_FOCUS_CHECK_DONE ",output)

func _settle_reward() -> void:
	for child in _node("AssociationRewardOverlay").get_children():
		if child is HeroLootShower:
			child.capture_clock = true
			for i in range(180): child.advance(1.0/60.0)
	await _frames(3)
	_check("Reward reveal settles without payout",Profile.meta == baseline_meta)

func _capture_commit(counter: Dictionary, succeed: bool) -> bool:
	counter.calls += 1
	return succeed

func _draw_state(kind: String) -> String:
	_reset_state()
	var table: String = {"character":"characters","weapon":"weapons","blessing":"blessings"}[kind]
	var collection: String = {"character":"characters","weapon":"sharedWeapons","blessing":"blessings"}[kind]
	var ids: Array = Content.data[table].keys()
	ids.sort()
	var chosen := str(ids[0])
	for id in Profile.meta[collection]: Profile.meta[collection][id].unlocked = str(id) != chosen
	main_scene.growth.associationId = "draw:"+kind
	return chosen

func _memory_transaction(action: String, value: String, succeed: bool = true) -> Dictionary:
	var before := Profile.meta.duplicate(true)
	var counter := {"calls":0}
	var cost := int(Content.data.draws.costs[value]) if action == "associationDraw" else HeroMeta.association_cost(Content.data,before,value)
	var result: Dictionary = main_scene._association_transaction(action,value,_capture_commit.bind(counter,succeed))
	if succeed:
		_check("Synthetic transaction commits once: "+value,not result.is_empty() and counter.calls == 1)
		_check("Synthetic transaction debits exactly once: "+value,int(Profile.meta.wallet.associationCoins) == int(before.wallet.associationCoins)-cost)
	else:
		_check("Failed synthetic commit rolls back: "+value,result.is_empty() and counter.calls == 1 and Profile.meta == before)
	return result

func _reject_transaction(action: String, value: String, reason: String) -> void:
	var before := Profile.meta.duplicate(true)
	var counter := {"calls":0}
	var result: Dictionary = main_scene._association_transaction(action,value,_capture_commit.bind(counter,true))
	_check("Rejected transaction does not commit or debit: "+reason,result.is_empty() and counter.calls == 0 and Profile.meta == before)

func _transaction_failures() -> void:
	for kind in ["character","weapon","blessing"]:
		_draw_state(kind)
		Profile.meta.wallet.associationCoins = 0
		_reject_transaction("associationDraw",kind,kind+" insufficient funds")
		_draw_state(kind)
		var collection: String = {"character":"characters","weapon":"sharedWeapons","blessing":"blessings"}[kind]
		for id in Profile.meta[collection]: Profile.meta[collection][id].unlocked = true
		_reject_transaction("associationDraw",kind,kind+" fully collected")
		_draw_state(kind)
		_memory_transaction("associationDraw",kind,false)
	for id in ["vitality","circuit"]:
		_reset_state()
		Profile.meta.wallet.associationCoins = 0
		_reject_transaction("associationBuy",id,id+" insufficient funds")
		_reset_state()
		_memory_transaction("associationBuy",id,false)
	_reset_state()
	Profile.meta.association.upgrades.circuit = 1
	_reject_transaction("associationBuy","circuit","one-time unlock already complete")
	_reset_state()

func _feedback_node() -> Node:
	return _node("AssociationFeedback")

func _start_feedback(result: Dictionary) -> Node:
	main_scene._show_association_result(result)
	var feedback := _feedback_node()
	_check("Applied association feedback controller exists",feedback != null)
	if feedback != null: _freeze(feedback)
	return feedback

func _busy_requests_remain_isolated(kind: String) -> void:
	var before := Profile.meta.duplicate(true)
	var selected := str(main_scene.growth.associationId)
	_check("Association feedback reports busy",HeroAssociationFeedback.is_busy(main_scene.view))
	main_scene._meta_action("associationSelect","vitality")
	main_scene._meta_action("associationDraw",kind)
	main_scene._meta_action("associationDraw",kind)
	_check("Rapid native requests during feedback preserve wallet and selection",Profile.meta == before and str(main_scene.growth.associationId) == selected and _feedback_node() != null)

func _association_feedback_states() -> void:
	_transaction_failures()
	for kind in ["character","weapon","blessing"]:
		var expected := _draw_state(kind)
		await _mount_screen("association")
		var result := _memory_transaction("associationDraw",kind)
		_check("Draw unlocks the deterministic unowned "+kind,str(result.get("id","")) == expected)
		await _mount_screen("association")
		var feedback := _start_feedback(result)
		if feedback == null: continue
		_busy_requests_remain_isolated(kind)
		var paid := Profile.meta.duplicate(true)
		await _shot("association-"+kind+"-draw-intro")
		await _signal("AssociationFeedbackConfirm")
		_check("First confirm reveals without closing: "+kind,_feedback_node() != null and feedback._settled and feedback._revealed and feedback._art.modulate.a == 1.0 and Profile.meta == paid)
		await _shot("association-"+kind+"-draw-result")
		await _signal("AssociationFeedbackConfirm")
		_check("Second confirm closes without another payout: "+kind,_feedback_node() == null and Profile.meta == paid)
		# The same Escape path is used by production _back().
		feedback = HeroAssociationFeedback.draw(main_scene.view,kind,expected)
		_freeze(feedback)
		main_scene._back()
		await _frames(2)
		_check("First Escape reveals the active result: "+kind,_feedback_node() != null and main_scene.screen == "association")
		main_scene._back()
		await _frames(2)
		_check("Second Escape closes the result: "+kind,_feedback_node() == null and main_scene.screen == "association" and Profile.meta == paid)
		feedback = HeroAssociationFeedback.draw(main_scene.view,kind,expected)
		_freeze(feedback)
		var sound_before: Array = [Sound._last.duplicate(true),Sound._pending.duplicate(true),Sound._voices.size()]
		feedback.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		await _frames(2)
		_check("Focus loss settles silently: "+kind,_feedback_node() != null and feedback._settled and not feedback._focused and feedback._glint.modulate.a == 0.0 and feedback._burst.modulate.a == 0.0 and Profile.meta == paid and Sound._last == sound_before[0] and Sound._pending == sound_before[1] and Sound._voices.size() == sound_before[2])
		await _shot("association-"+kind+"-focus-settled")
		feedback.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		HeroAssociationFeedback.close_or_reveal(main_scene.view)
		await _frames(2)
		_check("Focus return does not restart draw intro: "+kind,_feedback_node() == null)
	for id in ["vitality","circuit"]:
		_reset_state()
		main_scene.growth.associationId = id
		await _mount_screen("association")
		var result := _memory_transaction("associationBuy",id)
		await _mount_screen("association")
		var feedback := _start_feedback(result)
		if feedback == null: continue
		var paid := Profile.meta.duplicate(true)
		_check("Upgrade feedback starts busy: "+id,HeroAssociationFeedback.is_busy(main_scene.view))
		var selected := str(main_scene.growth.associationId)
		main_scene._meta_action("associationSelect","draw:blessing")
		main_scene._meta_action("associationBuy",id)
		_check("Rapid upgrade request preserves one committed result: "+id,Profile.meta == paid and str(main_scene.growth.associationId) == selected)
		for i in range(24): _advance(1.0/60.0)
		await _shot("association-upgrade-"+id+"-progress")
		for i in range(36): _advance(1.0/60.0)
		_check("Upgrade unlocks input after 0.8 seconds: "+id,not HeroAssociationFeedback.is_busy(main_scene.view) and Profile.meta == paid)
		await _shot("association-upgrade-"+id+"-complete")
	_reset_state()

func _applied_motion() -> void:
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	var target: Button
	for frame in range(90):
		if frame in [0,12,24,36,66,78]:
			_reset_state()
			target = null
			if frame == 0:
				await _mount_screen("settings")
				for button in main_scene.view.find_children("*","Button",true,false):
					if button.size.x > 150 and button.position.y > 100: target = button; break
			elif frame == 12:
				main_scene.archive = {"group":"characters","id":"awakener","page":0,"growthPage":0,"map":"seoul","scroll":0}
				await _mount_screen("archive")
				target = _node("ArchiveTab_characters")
			elif frame == 24:
				main_scene.gate_step = 5
				await _mount_screen("gate")
				target = _node("GatePrimary")
			elif frame == 36:
				_draw_state("blessing")
				var result := _memory_transaction("associationDraw","blessing")
				await _mount_screen("association")
				_start_feedback(result)
			else:
				var id := "vitality" if frame == 66 else "circuit"
				main_scene.growth.associationId = id
				var result := _memory_transaction("associationBuy",id)
				await _mount_screen("association")
				_start_feedback(result)
		if target:
			var local_frame := frame % 12
			if local_frame == 2: _hover_button(target,true)
			if local_frame == 5: target.button_down.emit()
			if local_frame == 7: target.button_up.emit()
			if local_frame == 10: _hover_button(target,false)
		_advance(1.0/15.0)
		await _frames(1)
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(output.path_join("frames/frame_%03d.png" % frame))

func _refresh_final() -> void:
	# Preserve verified state captures; refresh only the changed tape, reward reveal,
	# and motion frames. No production input or save operation is invoked.
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("manifest.json")))
	shots = previous.shots.duplicate(true)
	checks = previous.checks.duplicate(true)
	for shot in shots:
		if shot.file == "gate-formation.png":
			main_scene.archive = shot.archive.duplicate(true)
			main_scene.growth.associationId = shot.associationId
	for step in [0,5]:
		_reset_state()
		main_scene.gate_step = step
		await _mount_screen("gate")
		await _shot("gate-"+str(GATE_STEPS[step]))
	await _primary_states()
	_reset_state()
	main_scene.draft.blessing = ""
	main_scene.gate_step = 5
	await _mount_screen("gate")
	await _shot("gate-formation-none")
	_reset_state()
	main_scene.growth.associationId = "draw:blessing"
	await _mount_screen("association")
	HeroMetaScreens.rewards_popup(main_scene.view,[{"type":"characterUnlock","contentId":"awakener","amount":1}],"협회 뽑기")
	await _frames(3)
	for tween: Tween in get_tree().get_processed_tweens(): tween.custom_step(1.0)
	await _frames(2)
	await _settle_reward()
	await _shot("association-reward-settled")
	await _signal("AssociationRewardConfirm")
	_check("Settled reward confirms without payout",_node("AssociationRewardOverlay") == null and Profile.meta == baseline_meta)
	await _motion()

func _motion() -> void:
	if stage == "applied":
		await _applied_motion()
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	var target: Button
	for frame in range(90):
		if frame % 23 == 0 and frame <= 69:
			_reset_state()
			var part := frame / 23
			if part == 0:
				await _mount_screen("settings")
				for button in main_scene.view.find_children("*","Button",true,false):
					if button.size.x > 150 and button.position.y > 100:
						target = button; break
			elif part == 1:
				main_scene.archive = {"group":"characters","id":"awakener","page":0,"growthPage":0,"map":"seoul","scroll":0}
				await _mount_screen("archive")
				target = _node("ArchiveTab_characters")
			elif part == 2:
				main_scene.growth.associationId = "draw:blessing"
				await _mount_screen("association")
				target = _node("AssociationDraw")
			else:
				main_scene.gate_step = 5
				await _mount_screen("gate")
				target = _node("GatePrimary")
		var local_frame := frame % 23
		if target:
			if local_frame == 5: _hover_button(target,true)
			if local_frame == 12: target.button_down.emit()
			if local_frame == 15: target.button_up.emit()
			if local_frame == 18: _hover_button(target,false)
		_advance(1.0/15.0)
		await _frames(1)
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(output.path_join("frames/frame_%03d.png" % frame))

func _profile() -> void:
	Profile.meta = Content.data.defaultMeta.duplicate(true)
	HeroMeta.initialize(Content.data,Profile.meta)
	HeroMeta.apply_starter(Content.data,Profile.meta)
	for id in Content.data.characters: Profile.meta.characters[id].unlocked = true
	for id in HeroGateScreen.STARTER_ORDER: Profile.meta.sharedWeapons[id].unlocked = true
	blessing_id = str(Content.data.blessings.keys()[0])
	Profile.meta.blessings[blessing_id].unlocked = true
	Profile.meta.blessings[blessing_id].level = 1
	Profile.meta.wallet.associationCoins = 1850
	Profile.meta.settings.developerMode = false
	Profile.meta.settings.muted = false
	Profile.meta.weeklyGate.weekKey = str(FIXED_WEEK)
	Profile.meta.weeklyGate.ruleId = str(Content.data.weeklyRules.keys()[0])
	Profile.meta.gateProgression.highestUnlockedDepth = 25
	Profile.meta.gateProgression.characters["awakener"] = {"highestClearedDepth":7,"rewardedThroughDepth":7,"bestWaveByDepth":{"8":12}}
	baseline_meta = Profile.meta.duplicate(true)

func _run() -> void:
	await get_tree().process_frame
	if Profile.writable or "--ui-preview" not in OS.get_cmdline_user_args() or "--guild-office-preview" not in OS.get_cmdline_user_args():
		push_error("Requires --ui-preview --guild-office-preview for isolated synthetic captures.")
		get_tree().quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--stage="): stage = arg.trim_prefix("--stage=")
		if arg == "--parse-only": parse_only = true
		if arg == "--representative-only": representative_only = true
		if arg == "--refresh-only": refresh_only = true
		if arg == "--focus-check-only": focus_check_only = true
	if stage not in ["before","preview","applied"]:
		push_error("Use --stage=before, --stage=preview, or --stage=applied.")
		get_tree().quit(1); return
	if output.is_empty(): output = "res://../design/ui-image-skins/office-day-01/menu-unified-01/runtime/"+stage
	output = ProjectSettings.globalize_path(output)
	if not parse_only and stage == "before" and FileAccess.file_exists(output.path_join("manifest.json")):
		push_error("Existing baseline is preserved; use a fresh output folder.")
		get_tree().quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_size(Vector2i(915,412))
	get_tree().root.size = Vector2i(915,412)
	AudioServer.set_bus_mute(0,true)
	production_presentation_default = HeroDesk.presentation
	if stage != "applied": HeroDesk.presentation = stage == "preview"
	else:
		_check("Applied captures use the production presentation default",production_presentation_default)
		_check("Applied surfaces use internal runtime assets",HeroDesk.UNIFIED.begins_with("res://assets/"))
	seed(FIXED_SEED)
	_profile()
	main_scene = load("res://scenes/main.tscn").instantiate()
	main_scene.draft = {"map":"seoul","depth":1,"character":"awakener","weapon":"manaBolt","blessing":blessing_id,"weekly":Profile.meta.weeklyGate.ruleId,"week":FIXED_WEEK}
	add_child(main_scene)
	await _frames(4)
	if parse_only:
		main_scene.screen = "settings"
		main_scene._render()
		await _frames(2)
		print("MENU_UNIFIED_PARSE_OK; presentation=",HeroDesk.presentation,"; writable=",Profile.writable,"; combat=",main_scene.run != null)
		get_tree().quit(0); return
	get_tree().paused = true
	if focus_check_only:
		await _focus_check()
		get_tree().quit(0 if checks.filter(func(check): return not check.passed).is_empty() else 1)
		return
	if refresh_only:
		if stage != "preview" or not FileAccess.file_exists(output.path_join("manifest.json")):
			push_error("Refresh requires an existing approval preview manifest.")
			get_tree().quit(1); return
		await _refresh_final()
	else:
		await _mount_screen("settings")
		await _shot("settings")
		for group in ARCHIVE_GROUPS:
			if representative_only and group != "characters": continue
			main_scene.archive = {"group":group,"id":str(Content.data[group].keys()[0]),"page":0,"growthPage":0,"map":"seoul","scroll":0}
			await _mount_screen("archive")
			await _shot("archive-"+group)
		main_scene.growth.associationId = "draw:blessing"
		await _mount_screen("association")
		await _shot("association-draw")
		if not representative_only:
			main_scene.growth.associationId = "vitality"
			await _mount_screen("association")
			await _shot("association-upgrade")
		for step in range(6):
			if representative_only and step != 5: continue
			main_scene.gate_step = step
			main_scene.gate_ui = {"inspected":{},"scroll":{}}
			await _mount_screen("gate")
			await _shot("gate-"+str(GATE_STEPS[step]))
		if stage in ["preview","applied"] and not representative_only:
			await _preview_states()
			await _motion()
	_check("No save writes",not Profile.writable)
	_check("No combat started",main_scene.run == null)
	var manifest := {"stage":stage,"viewport":[915,412],"seed":FIXED_SEED,"fixedWeek":FIXED_WEEK,"userProfileRead":false,"saveWrites":Profile.writable,"productionMainScene":true,"productionPresentationDefault":production_presentation_default,"presentationOverride":stage != "applied","presentationEnabled":HeroDesk.presentation,"profile":baseline_meta,"shots":shots,"checks":checks,"representativeOnly":representative_only,"motionFrames":90 if stage in ["preview","applied"] and not representative_only else 0,"motionDurationMs":6000 if stage in ["preview","applied"] and not representative_only else 0,"userFileActionsInvoked":false,"combatStarted":main_scene.run != null}
	var file := FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"  "))
	print("MENU_UNIFIED_CAPTURE_DONE ",stage," ",output)
	var failures := checks.filter(func(check): return not check.passed)
	get_tree().quit(0 if failures.is_empty() else 1)
