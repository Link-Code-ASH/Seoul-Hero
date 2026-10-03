class_name HeroArchive
extends RefCounted

const GROUPS := {"characters":"캐릭터","weapons":"무기","enemies":"몬스터","items":"아이템","weeklyRules":"주간 특성","blessings":"단군의 축복"}
const STATS := {"damage":"공통 피해","attackSpeed":"공격 속도","meleeDamage":"근접 피해","rangedDamage":"원거리 피해","criticalChance":"치명타 확률","criticalDamage":"치명타 피해","range":"사거리","area":"범위","duration":"지속시간","projectileSpeed":"투사체 속도","maxHp":"최대 체력","armor":"방어력","dodge":"회피","lifesteal":"흡혈","hpRegeneration":"초당 회복","moveSpeed":"이동 속도","currencyGain":"마력석 획득","pickupRange":"획득 범위","luck":"행운","curse":"저주"}
const MULTIPLIERS := ["damage","attackSpeed","meleeDamage","rangedDamage","range","area","duration","projectileSpeed","currencyGain"]
const PROBABILITIES := ["criticalChance","criticalDamage","dodge","lifesteal"]
const RARITIES := {"COMMON":"일반","UNCOMMON":"고급","RARE":"희귀","LEGENDARY":"전설"}
const BEHAVIORS := {"chase":"추적","charge":"돌진","tank":"중장갑 추적","ranged":"원거리","swarm":"군집 추적","bomber":"자폭","splitter":"분열","support":"지원","summoner":"소환","defender":"방어 지원","ambush":"기습","boss":"보스"}

static func build(view: Dictionary, back: Callable, select: Callable) -> Control:
	var root := HeroImageSkin.root()
	HeroUI.background(root,"metaAssociationOffice")
	var wash := ColorRect.new()
	wash.color = Color(0.91,0.94,0.95,0.94)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(wash)
	HeroImageSkin.button(root,"‹ 이전",Rect2(22,14,90,44),back,"plain",15)
	HeroImageSkin.text(root,"자료집",Rect2(127,12,568,41),"brand",28)
	HeroImageSkin.text(root,"수집물 · 능력치 · 성장과 분기 기록",Rect2(128,54,707,28),"body",14,"muted")
	HeroImageSkin.material(root,"accents/rule_h",Rect2(22,84,871,2))
	var index := 0
	for group in GROUPS:
		HeroImageSkin.image_button(root,GROUPS[group],Rect2(24+index*146,93,138,44),func(): select.call("group",group),"controls/selected" if view.group == group else "controls/secondary",14)
		index += 1
	var ids := entries(view)
	if not ids.is_empty() and view.id not in ids: view.id = ids[0]; view.page = 0; view.growthPage = 0
	HeroImageSkin.text(root,GROUPS[view.group],Rect2(26,143,326,28),"heading",18)
	HeroImageSkin.text(root,str(ids.size()),Rect2(382,143,74,28),"number",19,"muted",HORIZONTAL_ALIGNMENT_RIGHT)
	var list := HeroImageSkin.scroll(root,Rect2(24,174,441,179),view,"scroll")
	list.name = "ArchiveCollection"
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",7)
	grid.add_theme_constant_override("v_separation",8)
	list.add_child(grid)
	for id in ids:
		var card := HeroImageSkin.card(grid,"",illustration(str(view.group),str(id)),Vector2(78,73),id == view.id,false,func(): select.call("id",id))
		card.name = "Archive_"+str(id)
	_map_navigation(root,view,select)
	if ids.is_empty(): return root
	if view.id not in ids: view.id = ids[0]; view.page = 0; view.growthPage = 0
	var definition: Dictionary = Content.data[view.group][view.id]
	var detail_panel := HeroImageSkin.material(root,"codex/panel",Rect2(488,143,404,262))
	detail_panel.name = "ArchiveDetails"
	# The book spine belongs to the art. All copy starts 48 px inside the left edge.
	HeroImageSkin.text(detail_panel,definition.name,Rect2(48,10,332,42),"heading",21,"ink",HORIZONTAL_ALIGNMENT_CENTER,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
	var labels := detail_tabs(str(view.group),definition)
	view.page = clampi(int(view.page),0,labels.size()-1)
	var tab_width := (332.0-(labels.size()-1)*6.0)/labels.size()
	for i in range(labels.size()):
		HeroImageSkin.image_button(detail_panel,labels[i],Rect2(48+i*(tab_width+6),59,tab_width,44),func(): select.call("page",i),"controls/selected" if int(view.page) == i else "controls/secondary",14)
	root.set_meta("archive_body_rect",Rect2(536,254,332,137))
	if view.group == "weapons":
		if int(view.page) == 0: _weapon_overview(root,definition)
		else: _weapon_growth(root,definition,view,select)
	else: _details(root,view,definition)
	return root

static func entries(view: Dictionary) -> Array:
	var source: Dictionary = Content.data[view.group]
	var ids: Array = source.keys()
	var field: String = {"weapons":"weaponIds","enemies":"enemyIds","items":"itemIds"}.get(view.group,"")
	var roster: Dictionary = Content.data.maps.get(view.get("map","seoul"),{}).get("archiveContent",{})
	if roster.has(field): ids = ids.filter(func(id): return id in roster[field])
	if view.group == "items":
		var rarity_order := RARITIES.keys()
		ids.sort_custom(func(a,b): return rarity_order.find(source[a].rarity) < rarity_order.find(source[b].rarity))
	return ids

static func _map_navigation(root: Control, view: Dictionary, select: Callable) -> void:
	var maps: Array = Content.data.maps.keys()
	var current := maxi(0,maps.find(view.get("map","seoul")))
	HeroImageSkin.button(root,"‹",Rect2(24,357,44,44),func(): select.call("map",maps[current-1]),"plain",22).disabled = current == 0
	HeroImageSkin.text(root,Content.data.maps[maps[current]].name,Rect2(79,357,320,44),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
	HeroImageSkin.button(root,"›",Rect2(413,357,44,44),func(): select.call("map",maps[current+1]),"plain",22).disabled = current == maps.size()-1

static func detail_tabs(group: String, definition: Dictionary) -> Array:
	match group:
		"weapons":
			var labels: Array = ["특징","기본 성장"]
			for branch in definition.branches: labels.append("분기 " + branch.id)
			return labels
		"characters": return ["배경","성격","공격","생존·회수"]
		"enemies": return ["특징","능력치","행동","공격 패턴"] if not definition.get("bossPatterns",[]).is_empty() else ["특징","능력치","행동"]
		"items": return ["특징","효과","구매 정보"]
		"weeklyRules": return ["특징","패널티","베네핏"]
		_: return ["특징","성장","운용"]

static func illustration(group: String, id: String) -> Texture2D:
	var definition: Dictionary = Content.data[group][id]
	match group:
		"characters": return Content.actor_preview(group,id,definition.portraitSprite)
		"weapons": return Content.weapon_icon(id)
		"enemies": return Content.actor_preview(group,id,definition.visual.sprite)
		"items": return Content.item_icon(id)
		_: return Content.trimmed_texture(definition.image)

static func _weapon_overview(root: Control, definition: Dictionary) -> void:
	var note: Dictionary = Content.data.premiumUI.weaponNotes.get(definition.id,{})
	var content := _content(root)
	var copy_column := _illustrated(content,Content.weapon_icon(definition.id))
	_copy(copy_column,HeroGateScreen.primary_family(definition.capabilities) + "  전투 장비",16,HeroImageSkin.color("accent"),true)
	var copy := "%s\n\n%s\n\n%s\n\n“%s”" % [definition.description,HeroGateScreen.secondary_traits(definition.capabilities),note.get("note",definition.description),note.get("quote","현장의 기록은 다음 출동을 지킵니다.")]
	_copy(copy_column,copy,14,HeroImageSkin.color("muted"))
	_copy(content,"적용 능력 · " + HeroGateScreen.applied_stats(definition.capabilities),14,HeroImageSkin.color("accent"))

static func _weapon_growth(root: Control, definition: Dictionary, view: Dictionary, select: Callable) -> void:
	var branch: Dictionary = definition.branches[int(view.page)-2] if int(view.page) >= 2 else {}
	var first := int(definition.branchAtLevel) if not branch.is_empty() else 1
	var last := int(definition.maxLevel) if not branch.is_empty() else int(definition.branchAtLevel)-1
	var count := maxi(1,ceili((last-first+1)/3.0))
	var page := clampi(int(view.get("growthPage",0)),0,count-1)
	var content := _content(root,_body_rect(root,345))
	_copy(content,branch.get("name","공통 성장"),16,HeroImageSkin.color("ink"),true)
	_copy(content,branch.get("description","분기 전 기본 강화 · 증감은 직전 레벨 대비"),14,HeroImageSkin.color("muted"))
	var extra_key := "attackAngle" if definition.behavior == "slash" else "blastRadius" if "EXPLOSIVE" in definition.capabilities or "AURA" in definition.capabilities else "projectileCount"
	var extra_title := "공격 각도 °" if extra_key == "attackAngle" else "공격 반경" if extra_key == "blastRadius" else "투사체 개수"
	var keys := ["damage","cooldown","range",extra_key,"repeatCount"]
	var headers := ["피해","공격 주기 · 초","사거리",extra_title,"반복 타격"]
	for row in range(3):
		var level := first+page*3+row
		if level > last: break
		var owned := {"level":level,"branch":branch.get("id","")}
		var stats := HeroStats.resolve_weapon(definition,owned,Content.data.stats,[],Content.data.weaponConfig,{})
		var previous := HeroStats.resolve_weapon(definition,{"level":maxi(1,level-1),"branch":branch.get("id","") if level-1 >= definition.branchAtLevel else ""},Content.data.stats,[],Content.data.weaponConfig,{})
		_copy(content,"Lv. %d" % level,16,HeroImageSkin.color("accent"))
		for i in range(keys.size()):
			var key: String = keys[i]
			var value := float(stats.get(key,0))
			var delta := value-float(previous.get(key,0)) if level > 1 else 0.0
			if key == "attackAngle": value = rad_to_deg(value); delta = rad_to_deg(delta)
			var text := number(value)+("  (%s%s)" % ["+" if delta > 0 else "",number(delta)] if absf(delta)>0.001 else "")
			var pair := HBoxContainer.new()
			pair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pair.add_theme_constant_override("separation",8)
			content.add_child(pair)
			var title := _copy(pair,headers[i],14,HeroImageSkin.color("muted"))
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title.custom_minimum_size.x = 139
			var value_label := _copy(pair,text,14,HeroImageSkin.color("accent") if absf(delta)>0.001 else HeroImageSkin.color("ink"))
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value_label.custom_minimum_size.x = 159
	for i in range(count):
		var start := first+i*3
		var width := (332.0-6*(count-1))/count
		HeroImageSkin.image_button(root,"Lv.%d–%d" % [start,mini(last,start+2)],Rect2(536+i*(width+6),351,width,44),func(): select.call("growthPage",i),"controls/selected" if page == i else "controls/secondary",14)

static func _details(root: Control, view: Dictionary, definition: Dictionary) -> void:
	var group: String = view.group
	var page: int = view.page
	if group == "characters" and page >= 2:
		var keys: Array = STATS.keys().slice(0,10) if page == 2 else STATS.keys().slice(10)
		var pairs: Array = []
		for key in keys: pairs.append([STATS[key],stat_value(key,definition.baseStats[key]),key])
		_pairs(root,pairs,"기본 능력치 · 추가 보정 전")
		return
	if group == "enemies" and page == 1:
		_pairs(root,[["최대 체력",number(definition.maxHp)],["이동 속도",number(definition.moveSpeed)],["접촉 피해",number(definition.contactDamage)],["크기 · 반경",number(definition.radius)],["마력석",number(definition.magicStoneDrop)]],"광화문 · 심도 1 기준")
		return
	if group == "enemies" and page == 3:
		var content := _content(root)
		_copy(content,"보스 공격 패턴",16,HeroImageSkin.color("ink"),true)
		var patterns: Array = definition.get("bossPatterns",[])
		var lines := PackedStringArray()
		for pattern in patterns: lines.append(_pattern(pattern))
		_copy(content,"\n\n".join(lines),14,HeroImageSkin.color("ink"))
		return
	var content := _content(root)
	var copy_column := _illustrated(content,illustration(group,view.id))
	var heading := ""
	var text := ""
	var footer := ""
	match group:
		"characters":
			heading = "배경" if page == 0 else "성격"
			text = definition.get("background",definition.description) if page == 0 else definition.get("personality","")
			footer = "%s · %s" % [definition.trait.name,definition.trait.description]
		"enemies":
			heading = "보스" if "BOSS" in definition.tags else "일반"
			text = definition.get("description",definition.get("archiveRole","")) if page == 0 else BEHAVIORS.get(definition.behavior,definition.behavior)
			if page == 2:
				text += "\n" + definition.get("archiveBehavior",definition.get("description",""))
		"items":
			heading = RARITIES.get(definition.rarity,definition.rarity)
			if page == 0: text = definition.description
			elif page == 1:
				text = definition.description.replace(" · ","\n")
			else:
				text = "가격  %d 마력석\n최대 중첩  %d\n구매 위치  게이트24" % [definition.basePrice,definition.maxStacks]
			footer = "능력치 증가는 기준값에서 합산됩니다."
		"weeklyRules":
			heading = ["주간 게이트 규칙","패널티","베네핏"][page]
			text = definition.description if page == 0 else definition.penaltyLabel if page == 1 else definition.benefitLabel
			footer = "패널티와 베네핏은 함께 자동 적용 · 일요일 05:00 갱신"
		"blessings":
			heading = ["단군의 축복","단계당 효과","출동 전 편성"][page]
			if page == 0: text = definition.description
			elif page == 1:
				for modifier in definition.modifiers: text += _modifier(modifier) + "\n"
				if definition.has("structureLimitAtLevel"): text += "%d단계 설치물 한도 +1" % definition.structureLimitAtLevel
			else:
				var costs: Array = Content.data.growth.blessingCosts
				var steps: Array = costs.slice(1).map(func(cost): return str(int(cost)))
				text = "%d조각으로 해금\n성장 비용  %s\n최대 %d단계\n해금한 축복 1개만 Run에 적용" % [int(costs[0])," / ".join(steps),costs.size()]
			footer = "성장 단계는 보유 조각을 사용해 올립니다."
	_copy(copy_column,heading,16,HeroImageSkin.color("ink"),true)
	_copy(copy_column,text,14,HeroImageSkin.color("muted"))
	if not footer.is_empty(): _copy(content,footer,14,HeroImageSkin.color("accent"))

static func _pairs(root: Control, pairs: Array, heading: String) -> void:
	var content := _content(root)
	_copy(content,heading,15,HeroImageSkin.color("ink"),true)
	for pair in pairs:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 30
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation",8)
		content.add_child(row)
		if pair.size() >= 3: HeroUI.icon(row,str(pair[2]),20,24)
		var name_label := _copy(row,str(pair[0]),14,HeroImageSkin.color("muted"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size.x = 170
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var value := _copy(row,str(pair[1]),16,HeroImageSkin.color("ink"))
		value.custom_minimum_size.x = 92
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		HeroImageSkin.apply_font(value,"number",16)

static func _body_rect(parent: Node, bottom: float = 391) -> Rect2:
	var result: Rect2 = parent.get_meta("archive_body_rect",Rect2(536,254,332,137))
	result.size.y = maxf(44,bottom-result.position.y)
	return result

static func _content(root: Control, rect: Rect2 = Rect2()) -> VBoxContainer:
	if rect.size == Vector2.ZERO: rect = _body_rect(root)
	var panel := root.get_node("ArchiveDetails") as Control
	var scroll := HeroImageSkin.scroll(panel,Rect2(rect.position-panel.position,rect.size))
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	scroll.add_child(content)
	return content

static func _illustrated(parent: Control, texture: Texture2D) -> VBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",12)
	parent.add_child(row)
	var art := HeroUI.image(row,texture,98,116)
	art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var copy_column := VBoxContainer.new()
	copy_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_column.add_theme_constant_override("separation",8)
	row.add_child(copy_column)
	return copy_column

static func _copy(parent: Node, caption: String, font_size: int, color: Color, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = caption
	HeroImageSkin.apply_font(label,"heading" if font_size >= 17 else "body",font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color",color)
	label.add_theme_constant_override("line_spacing",2)
	parent.add_child(label)
	return label

static func stat_value(key: String, value: float) -> String:
	return number(value*100)+"%" if key in MULTIPLIERS or key in PROBABILITIES else number(value)

static func _modifier(modifier: Dictionary) -> String:
	var value := float(modifier.value)
	var percent: bool = modifier.operation == "multiply" or modifier.stat in MULTIPLIERS or modifier.stat in PROBABILITIES
	if modifier.operation == "multiply": value -= 1.0
	if percent: value *= 100
	return "%s  %s%s%s" % [STATS.get(modifier.stat,modifier.stat),"+" if value>0 else "",number(value),"%" if percent else ""]

static func _special_effect(effect: Dictionary) -> String:
	var names := {"structureLimit":"설치물 추가 한도","projectileCount":"투사체 추가","indirectLifesteal":"설치물 흡혈","structureDuration":"설치물 지속시간","structureDamage":"설치물 피해","structureInterval":"설치 주기","chainCount":"연쇄 추가"}
	return "%s  %s" % [names.get(effect.type,effect.type),number(effect.get("value",0))]

static func _pattern(pattern: Dictionary) -> String:
	var name: String = {"charge":"돌진","aoe":"범위 공격","summon":"소환","volley":"일제 사격"}.get(pattern.type,pattern.type)
	return "%s · 예고 %s초 / 주기 %s초" % [name,number(pattern.get("warning",0)),number(pattern.get("cooldown",0))]

static func number(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")

