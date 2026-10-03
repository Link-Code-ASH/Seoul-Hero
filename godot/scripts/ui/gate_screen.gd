class_name HeroGateScreen
extends RefCounted

const STARTER_ORDER := ["manaSword","guardianDaggers","manaBolt","piercingShot","chainLightning","manaBombard","manaShotgun"]
const TITLES := ["작전 구역 선택","웨이브 심도 선택","각성자 선택","시작 무기 선택","단군의 축복 선택","작전 편성 확인"]
const SUBTITLES := ["서울에서 진행할 작전 구역을 고르세요.","높은 심도일수록 침식체가 강해집니다.","함께 서울의 게이트로 들어갈 각성자를 고르세요.","선택한 무기 1종으로 시작합니다. 전투 보유 한도는 6종입니다.","이번 작전에 적용할 축복을 하나 고르세요.","선택한 구역과 편성을 확인하고 출동하세요."]
const STAT_NAMES := {"damage":"공통 피해","attackSpeed":"공격 속도","meleeDamage":"근접 피해","rangedDamage":"원거리 피해","criticalChance":"치명타 확률","criticalDamage":"치명타 피해","range":"사거리","area":"범위","duration":"지속시간","projectileSpeed":"투사체 속도","maxHp":"최대 체력","armor":"방어","dodge":"회피","lifesteal":"흡혈","hpRegeneration":"체력 재생","moveSpeed":"이동 속도","currencyGain":"마력석 획득량","pickupRange":"획득 범위","luck":"행운","curse":"저주"}
const RATIO_STATS := ["damage","attackSpeed","meleeDamage","rangedDamage","criticalChance","criticalDamage","range","area","duration","projectileSpeed","dodge","lifesteal","currencyGain"]

# Inspection and scroll offsets belong to the transient UI, never the run setup.
static func build(draft: Dictionary, step: int, change: Callable, navigate: Callable, deploy: Callable, ui_state: Dictionary = {}) -> Control:
	if not ui_state.has("inspected"): ui_state.inspected = {}
	if not ui_state.has("scroll"): ui_state.scroll = {}
	var root := HeroImageSkin.root()
	_background(root)
	_header(root,step,navigate)
	match step:
		0: _maps(root,draft,change,navigate,ui_state)
		1: _depths(root,draft,change,navigate)
		2: _selection(root,"character",draft,change,navigate,ui_state)
		3: _selection(root,"weapon",draft,change,navigate,ui_state)
		4: _selection(root,"blessing",draft,change,navigate,ui_state)
		5: _formation(root,draft,navigate,deploy)
	return root

static func _background(parent: Control) -> void:
	var wash := ColorRect.new()
	wash.color = Color("edf3f3")
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(wash)

static func _header(root: Control, step: int, navigate: Callable) -> void:
	HeroImageSkin.image_button(root,"이전",Rect2(28,18,78,44),func(): navigate.call(-1))
	HeroImageSkin.text(root,TITLES[step],Rect2(122,13,650,42),"brand",27)
	HeroImageSkin.text(root,SUBTITLES[step],Rect2(124,57,658,25),"body",14,"muted")
	HeroImageSkin.text(root,"%02d / 06" % [step+1],Rect2(793,21,92,35),"number",18,"muted",HORIZONTAL_ALIGNMENT_RIGHT)

static func _footer(root: Control, caption: String, next_caption: String, action: Callable, reason: String = "") -> void:
	HeroImageSkin.text(root,caption if reason.is_empty() else reason,Rect2(36,351,664,45),"control",14,"ink" if reason.is_empty() else "danger",HORIZONTAL_ALIGNMENT_LEFT,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
	var target := HeroImageSkin.image_button(root,next_caption,Rect2(727,351,158,45),action,"controls/primary",16)
	target.disabled = not reason.is_empty()

static func _maps(root: Control, draft: Dictionary, change: Callable, navigate: Callable, ui_state: Dictionary) -> void:
	var ids: Array = Content.data.maps.keys()
	var chosen: Dictionary = Content.data.maps[draft.map]
	var map_rect := Rect2(44,98,550,235)
	HeroImageSkin.material(root,"navigation/panel",map_rect)
	var art := HeroUI.fixed_art(root,_map_texture(draft.map),Rect2(55,109,528,213))
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.clip_contents = true
	HeroImageSkin.material(root,"navigation/selection",Rect2(57,318,525,5))
	var detail := _details(root,Rect2(618,91,267,242),"navigation/panel",Vector4(32,16,20,16))
	_copy(detail,str(chosen.name),"brand",27)
	_copy(detail,"%d 웨이브 · 마지막 보스 전투" % int(chosen.totalWaves),"control",14,"accent")
	_copy(detail,str(chosen.description),"body",14,"muted")
	if ids.size() > 1:
		var selector := HeroImageSkin.scroll(root,Rect2(48,277,541,49),ui_state.scroll,"map")
		var row := HBoxContainer.new(); selector.add_child(row)
		for map_id in ids:
			var id: String = str(map_id)
			var unlocked: bool = id in Profile.meta.account.unlockedMapIds
			var choice := HeroImageSkin.image_button(row,str(Content.data.maps[id].name),Rect2(0,0,164,44),func(): change.call("map",id),"controls/secondary",14,draft.map == id)
			choice.disabled = not unlocked
	_copy(detail,"모든 지형을 이동할 수 있습니다.","body",14,"muted")
	_weekly(detail,draft)
	_footer(root,"현재 구역 · "+str(chosen.name),"심도 선택",func(): navigate.call(1))

static func _depths(root: Control, draft: Dictionary, change: Callable, navigate: Callable) -> void:
	var progress: Dictionary = Profile.meta.gateProgression.characters.get(draft.character,{})
	var highest := int(Profile.meta.gateProgression.highestUnlockedDepth)
	for row in range(2):
		HeroImageSkin.material(root,"navigation/panel",Rect2(30,94+row*108,854,101))
	for index in range(20):
		var depth := index+1
		var x := 37.0+float(index%10)*84.0
		var y := 98.0+floorf(index/10.0)*108.0
		var locked := depth > highest
		var cleared := depth <= int(progress.get("highestClearedDepth",0))
		var selected := depth == int(draft.depth)
		HeroImageSkin.text(root,"%02d" % depth,Rect2(x+4,y+5,70,45),"number",34,"muted" if locked else "accent" if selected else "ink",HORIZONTAL_ALIGNMENT_CENTER)
		var best := int(progress.get("bestWaveByDepth",{}).get(str(depth),0))
		var status := "선택" if selected else "잠금" if locked else "클리어" if cleared else "도전" if best == 0 else "%d/20" % best
		HeroImageSkin.text(root,status,Rect2(x+2,y+53,74,26),"control",13,"muted" if locked else "accent" if selected else "reward" if cleared else "ink",HORIZONTAL_ALIGNMENT_CENTER)
		if selected: HeroImageSkin.material(root,"navigation/selection",Rect2(x+8,y+85,60,5))
		var target := HeroImageSkin.image_button(root,"",Rect2(x,y,79,96),func(): change.call("depth",depth),"plain")
		target.disabled = locked
	var difficulty := HeroStats.difficulty(Content.data,int(draft.depth),Content.data.maps[draft.map],draft.weekly)
	HeroImageSkin.text(root,"심도 %02d" % int(draft.depth),Rect2(38,312,116,35),"brand",24)
	HeroImageSkin.text(root,"적 체력 ×%.2f  피해 ×%.3f  생성 ×%.2f" % [difficulty.hp,difficulty.damage,difficulty.spawn],Rect2(166,311,550,34),"body",14)
	var weekly: Dictionary = Content.data.weeklyRules.get(draft.weekly,{})
	HeroImageSkin.text(root,str(weekly.get("name",""))+" · "+str(weekly.get("penaltyLabel","")),Rect2(38,348,646,47),"body",13,"muted",HORIZONTAL_ALIGNMENT_LEFT,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
	HeroImageSkin.image_button(root,"각성자 선택",Rect2(727,351,158,45),func(): navigate.call(2),"controls/primary",16)

static func _selection(root: Control, kind: String, draft: Dictionary, change: Callable, navigate: Callable, ui_state: Dictionary) -> void:
	var ids := _ids(kind,draft)
	var inspected: String = str(ui_state.inspected.get(kind,draft[kind]))
	if inspected not in ids: inspected = str(draft[kind])
	var scroll := HeroImageSkin.scroll(root,Rect2(28,90,572,252),ui_state.scroll,kind)
	scroll.name = "GateSelectionScroll"
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for entry in ids:
		var id: String = str(entry)
		var locked := not _unlocked(kind,id,draft)
		var caption := _name(kind,id)
		if kind == "blessing" and not id.is_empty():
			caption += "\n미해금" if locked else "\nLv.%d" % int(Profile.meta.blessings[id].level)
		var target := HeroImageSkin.card(grid,caption,_texture(kind,id),Vector2(132,120),id == str(draft[kind]),locked,func():
			change.call("uiInspect",{"kind":kind,"id":id})
			if not locked: change.call(kind,id)
		)
		target.name = "GateChoice_"+id
		target.set_meta("content_id",id)
		target.set_meta("choice_kind",kind)
	_selection_detail(root,Rect2(618,85,266,257),kind,inspected,draft,ui_state)
	var labels := {"character":"시작 무기 선택","weapon":"단군의 축복","blessing":"편성 확인"}
	var steps := {"character":3,"weapon":4,"blessing":5}
	var reason := "" if _unlocked(kind,inspected,draft) else _lock_reason(kind,inspected,draft)
	_footer(root,"현재 선택 · "+_name(kind,str(draft[kind])),str(labels[kind]),func(): navigate.call(steps[kind]),reason)

static func _selection_detail(root: Control, rect: Rect2, kind: String, id: String, draft: Dictionary, ui_state: Dictionary) -> void:
	var panel := HeroImageSkin.material(root,"cards/detail",rect)
	panel.name = "GateSelectionPanel"
	var content := HeroImageSkin.content_rect(panel)
	var title := _name(kind,id)
	var title_height := _text_height(title,content.size.x,"brand",23)
	var title_label := HeroImageSkin.text(panel,title,Rect2(content.position,Vector2(content.size.x,title_height)),"brand",23,"ink",HORIZONTAL_ALIGNMENT_CENTER,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
	title_label.name = "GateDetailTitle"
	var texture := _texture(kind,id)
	var copy_width := content.size.x - 88 if texture != null else content.size.x
	var core := _profile_core(kind,id)
	var copy_height := 0.0
	for line in core:
		copy_height += _text_height(str(line.text),copy_width,str(line.role),int(line.size))
	copy_height += 6 * maxi(0,core.size()-1)
	var profile_height := maxf(90 if texture != null else 0,copy_height)
	var profile_position := content.position + Vector2(0,title_height+7)
	if texture != null:
		var art := HeroUI.fixed_art(panel,texture,Rect2(profile_position,Vector2(76,profile_height)))
		art.name = "GateDetailArt"
	var profile := VBoxContainer.new()
	profile.name = "GateSelectionProfile_"+kind
	profile.position = profile_position + Vector2(88 if texture != null else 0,0)
	profile.size = Vector2(copy_width,profile_height)
	profile.custom_minimum_size.x = copy_width
	profile.add_theme_constant_override("separation",6)
	profile.alignment = BoxContainer.ALIGNMENT_CENTER
	profile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(profile)
	for line in core:
		var label := _copy(profile,str(line.text),str(line.role),int(line.size),str(line.color))
		label.custom_minimum_size = Vector2(copy_width,_text_height(str(line.text),copy_width,str(line.role),int(line.size)))
		label.set_meta("fixed_profile",true)
	var body_top := profile_position.y + profile_height + 8
	var scroll := HeroImageSkin.scroll(panel,Rect2(content.position.x,body_top,content.size.x,content.end.y-body_top),ui_state.scroll,"detail:"+kind+":"+id)
	scroll.name = "GateDetailScroll"
	var detail := VBoxContainer.new()
	detail.name = "GateSelectionDetail"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",7)
	scroll.add_child(detail)
	if not _unlocked(kind,id,draft):
		_copy(detail,_lock_reason(kind,id,draft),"control",14,"danger")
	match kind:
		"character":
			var definition: Dictionary = Content.data.characters[id]
			_copy(detail,str(definition.description),"body",14,"muted")
			_copy(detail,"기본 스탯","heading",17)
			for stat in definition.baseStats:
				_pair(detail,str(STAT_NAMES.get(stat,stat)),_stat_value(stat,float(definition.baseStats[stat])))
		"weapon":
			var definition: Dictionary = Content.data.weapons[id]
			_copy(detail,secondary_traits(definition.capabilities),"control",14,"accent")
			_copy(detail,str(definition.description),"body",14,"muted")
			_copy(detail,"기초 공격 · Lv.1","heading",17)
			var base: Dictionary = definition.base
			_pair(detail,"사거리",_number(float(base.range)))
			_pair(detail,"투사체 / 타격 수",str(int(base.projectileCount)))
			_copy(detail,"적용 스탯","heading",17)
			_copy(detail,applied_stats(definition.capabilities),"body",14,"muted")
		"blessing":
			if id.is_empty():
				_copy(detail,"축복을 해금하면 이 목록에서 선택할 수 있습니다.","body",14,"muted")
			else:
				var definition: Dictionary = Content.data.blessings[id]
				var level := int(Profile.meta.blessings.get(id,{}).get("level",0))
				_copy(detail,str(definition.description),"body",14,"muted")
				if definition.modifiers.size() > 1:
					_copy(detail,"추가 적용 효과" if level > 0 else "해금 시 추가 효과","heading",17)
					for modifier in definition.modifiers.slice(1):
						_copy(detail,_modifier_text(modifier,maxi(1,level)),"body",14)
				if definition.has("structureLimitAtLevel"):
					var threshold := int(definition.structureLimitAtLevel)
					_copy(detail,"Lv.%d부터 설치 한도 +1%s" % [threshold," 적용" if level >= threshold else ""],"body",14,"accent" if level >= threshold else "muted")

static func _profile_core(kind: String, id: String) -> Array:
	match kind:
		"character":
			var definition: Dictionary = Content.data.characters[id]
			return [
				{"text":str(definition.trait.name),"role":"heading","size":17,"color":"accent"},
				{"text":str(definition.trait.description),"role":"control","size":14,"color":"ink"}
			]
		"weapon":
			var definition: Dictionary = Content.data.weapons[id]
			return [
				{"text":primary_family(definition.capabilities)+" · Lv.1","role":"heading","size":17,"color":"accent"},
				{"text":"피해 "+_number(float(definition.base.damage)),"role":"body","size":14,"color":"ink"},
				{"text":"공격 간격 %.2f초" % float(definition.base.cooldown),"role":"body","size":14,"color":"ink"}
			]
		"blessing":
			if id.is_empty(): return [{"text":"축복을 적용하지 않고 출동합니다.","role":"body","size":14,"color":"muted"}]
			var definition: Dictionary = Content.data.blessings[id]
			var level := int(Profile.meta.blessings.get(id,{}).get("level",0))
			var result: Array = [{"text":"보유 레벨 · Lv.%d" % level,"role":"control","size":14,"color":"accent" if level > 0 else "muted"}]
			if level == 0:
				result.append({"text":"해금 시 Lv.1 효과","role":"body","size":14,"color":"muted"})
			if not definition.modifiers.is_empty():
				result.append({"text":_modifier_text(definition.modifiers[0],maxi(1,level)),"role":"body","size":14,"color":"ink"})
			return result
	return []

static func _text_height(caption: String, width: float, role: String, font_size: int) -> float:
	var face: Font = HeroImageSkin.font(role)
	var measured := face.get_multiline_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,width,font_size)
	var line_count := maxi(1,ceili(measured.y/face.get_height(font_size)))
	var spacing := 2 * maxi(0,line_count-1)
	return maxf(ceilf(face.get_height(font_size)*line_count)+spacing+2,ceilf(measured.y)+spacing+2)

static func _formation(root: Control, draft: Dictionary, navigate: Callable, deploy: Callable) -> void:
	HeroImageSkin.material(root,"command/panel",Rect2(28,92,859,249))
	var map: Dictionary = Content.data.maps[draft.map]
	var image := HeroUI.fixed_art(root,_map_texture(draft.map),Rect2(50,110,327,179))
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.clip_contents = true
	HeroImageSkin.text(root,str(map.name),Rect2(50,295,327,28),"heading",20)
	var character: Dictionary = Content.data.characters[draft.character]
	_formation_row(root,Rect2(393,110,470,64),_texture("character",draft.character),str(character.name),str(character.trait.description),func(): navigate.call(2))
	var weapon: Dictionary = Content.data.weapons[draft.weapon]
	_formation_row(root,Rect2(393,182,470,64),_texture("weapon",draft.weapon),str(weapon.name),primary_family(weapon.capabilities)+" · "+secondary_traits(weapon.capabilities),func(): navigate.call(3))
	var blessing_id: String = str(draft.blessing)
	var blessing_name := _name("blessing",blessing_id)
	var blessing_note := "축복을 적용하지 않습니다." if blessing_id.is_empty() else "보유 Lv.%d · 이번 작전에 적용" % int(Profile.meta.blessings[blessing_id].level)
	_formation_row(root,Rect2(393,254,470,64),_texture("blessing",blessing_id),blessing_name,blessing_note,func(): navigate.call(4))
	var weekly: Dictionary = Content.data.weeklyRules.get(draft.weekly,{})
	HeroImageSkin.text(root,str(weekly.get("name",""))+" · "+str(weekly.get("penaltyLabel",""))+" · "+str(weekly.get("benefitLabel","")),Rect2(36,350,670,47),"body",13,"muted",HORIZONTAL_ALIGNMENT_LEFT,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
	HeroImageSkin.image_button(root,"작전 투입",Rect2(727,351,158,45),deploy,"controls/primary",17)

static func _formation_row(root: Control, rect: Rect2, texture: Texture2D, title: String, description: String, action: Callable) -> void:
	HeroImageSkin.material(root,"command/row",rect)
	if texture != null: HeroUI.fixed_art(root,texture,Rect2(rect.position+Vector2(16,8),Vector2(48,48)))
	var title_height := maxf(22,ceilf(HeroImageSkin.font("heading").get_height(16)))
	var title_label := HeroImageSkin.text(root,title,Rect2(rect.position+Vector2(72,8),Vector2(382,title_height)),"heading",16)
	var body_label := HeroImageSkin.text(root,description,Rect2(rect.position+Vector2(72,10+title_height),Vector2(382,46-title_height)),"body",14,"muted",HORIZONTAL_ALIGNMENT_LEFT,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
	for label in [title_label,body_label]:
		label.set_meta("formation_row",rect)
		label.set_meta("formation_content",Rect2(rect.position+Vector2(72,8),Vector2(382,48)))
	HeroImageSkin.image_button(root,"",rect,action,"plain")

static func _details(root: Control, rect: Rect2, role: String, inset: Vector4 = Vector4(18,12,18,12)) -> VBoxContainer:
	var panel := HeroImageSkin.material(root,role,rect)
	var scroll := HeroImageSkin.scroll(panel,Rect2(inset.x,inset.y,rect.size.x-inset.x-inset.z,rect.size.y-inset.y-inset.w))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",7)
	scroll.add_child(column)
	return column

static func _copy(parent: Node, caption: String, role: String = "body", font_size: int = 14, color_role: String = "ink", centered: bool = false) -> Label:
	var label := Label.new()
	label.text = caption
	HeroImageSkin.apply_font(label,role,font_size)
	label.add_theme_color_override("font_color",HeroImageSkin.color(color_role))
	label.add_theme_constant_override("line_spacing",2)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

static func _pair(parent: Node, caption: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	parent.add_child(row)
	var name_label := _copy(row,caption,"body",14,"muted")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := _copy(row,value,"number",16)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 70

static func _weekly(parent: Node, draft: Dictionary) -> void:
	var weekly: Dictionary = Content.data.weeklyRules.get(draft.weekly,{})
	_copy(parent,str(weekly.get("name","")),"heading",17,"accent")
	_copy(parent,str(weekly.get("penaltyLabel","")),"body",14,"danger")
	_copy(parent,str(weekly.get("benefitLabel","")),"body",14,"accent")

static func _ids(kind: String, draft: Dictionary) -> Array:
	if kind == "character": return Content.data.characters.keys()
	if kind == "blessing": return [""]+Content.data.blessings.keys()
	var ids: Array = []
	var order: Array = STARTER_ORDER.duplicate()
	for id in Content.data.weapons:
		if id not in order: order.append(id)
	for id in order:
		var definition: Dictionary = Content.data.weapons.get(id,{})
		if definition.is_empty() or definition.has("structure"): continue
		# Signature-only future equipment belongs to its owner; all seven common starters remain visible.
		if definition.get("signatureOwnerId",draft.character) != draft.character: continue
		ids.append(id)
	return ids

static func _unlocked(kind: String, id: String, draft: Dictionary) -> bool:
	if kind == "blessing" and id.is_empty(): return true
	var collection: Dictionary = Profile.meta[{"character":"characters","weapon":"sharedWeapons","blessing":"blessings"}[kind]]
	if not collection.get(id,{}).get("unlocked",false): return false
	return kind != "weapon" or Content.data.weapons[id].get("signatureOwnerId",draft.character) == draft.character

static func _lock_reason(kind: String, id: String, draft: Dictionary) -> String:
	if kind == "weapon" and Content.data.weapons[id].get("signatureOwnerId",draft.character) != draft.character: return "이 각성자가 사용할 수 없는 시작 무기입니다."
	return "미해금 각성자입니다. 해금 후 선택할 수 있습니다." if kind == "character" else "미해금 무기입니다. 해금 후 선택할 수 있습니다." if kind == "weapon" else "미해금 축복입니다. 영구 성장에서 해금 후 선택할 수 있습니다."

static func _name(kind: String, id: String) -> String:
	if kind == "blessing" and id.is_empty(): return "축복 없음"
	return str(Content.data[{"character":"characters","weapon":"weapons","blessing":"blessings"}[kind]][id].name)

static func _texture(kind: String, id: String) -> Texture2D:
	if kind == "blessing": return null if id.is_empty() else Content.trimmed_texture(Content.data.blessings[id].image)
	if kind == "weapon": return Content.weapon_icon(id)
	return Content.actor_preview("characters",id,Content.data.characters[id].portraitSprite)

static func _map_texture(id: String) -> Texture2D:
	return Content.texture(Content.visuals.maps.get(id,{}).get("texture",Content.data.maps[id].thumbnail))

static func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value,roundf(value)) else "%.1f" % value

static func _stat_value(stat: String, value: float) -> String:
	return _number(value*100.0)+"%" if stat in RATIO_STATS else _number(value)

static func _modifier_text(modifier: Dictionary, level: int) -> String:
	var stat: String = modifier.stat
	var amount := (float(modifier.value)-1.0)*100.0*level if modifier.operation == "multiply" else float(modifier.value)*level
	var percent: bool = modifier.operation == "multiply" or stat in ["criticalChance","criticalDamage","dodge","lifesteal"]
	if modifier.operation == "add" and percent: amount *= 100.0
	return str(STAT_NAMES.get(stat,stat))+" "+("+" if amount >= 0 else "")+_number(amount)+("%" if percent else "")

static func primary_family(caps: Array) -> String:
	if "STRUCTURE" in caps: return "설치물"
	return "근접" if "MELEE" in caps else "원거리" if "RANGED" in caps else "마력"

static func secondary_traits(caps: Array) -> String:
	return capabilities(caps.filter(func(cap): return cap not in ["MELEE","RANGED","STRUCTURE"]))

static func applied_stats(caps: Array) -> String:
	var names: Array = ["공통 피해","공격 속도"]
	var links := {"MELEE":"근접 피해","RANGED":"원거리 피해","AREA":"범위","PROJECTILE":"투사체 속도","DURATION":"지속시간","HAS_RANGE":"사거리","CAN_CRIT":"치명타 확률·피해"}
	for cap in caps:
		if links.has(cap): names.append(links[cap])
	return " · ".join(names)

static func capabilities(caps: Array) -> String:
	var names := {"MELEE":"근접","RANGED":"원거리","PROJECTILE":"투사체","AREA":"범위","ORBIT":"회전","CHAIN":"연쇄","EXPLOSIVE":"폭발","PIERCING":"관통","STRUCTURE":"설치물","TURRET":"포탑","MINE":"지뢰","AURA":"마력장","TRAP":"함정","BEAM":"광선","SUMMON":"소환","DURATION":"지속","HAS_RANGE":"사거리","CAN_CRIT":"치명타"}
	var result: Array = []
	for cap in caps:
		if names.has(cap): result.append(names[cap])
	return " · ".join(result)
