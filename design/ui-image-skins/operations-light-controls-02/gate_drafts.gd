extends RefCounted
# Approval drafts only. Content is a frozen Dictionary supplied by Common.
# No production screen classes, profile, audio, combat or save adapters are loaded.
const STARTERS := ["manaSword", "guardianDaggers", "manaBolt", "piercingShot", "chainLightning", "manaBombard", "manaShotgun"]
const BLESSINGS := ["", "cheonbuOath", "unyieldingJangseung", "samjogoWing", "whiteTigerEye", "goblinForge", "harvestKnot", "reverseScale"]
const FIXTURE := {"character":"awakener", "weapon":"manaBolt", "blessing":"cheonbuOath", "archive":"vaultLedger"}
const BLESSING_LEVELS := {"cheonbuOath":1, "harvestKnot":2}
# Reviewed production SD regions, independent of legacy portrait manifest entries.
const SD_PORTRAITS := {
	"awakener":{"file":"res://assets/characters-sd/song_sd_01.png", "region":Rect2(246, 72, 757, 1149)},
	"kangTaehoon":{"file":"res://assets/characters-sd/kang_sd_01.png", "region":Rect2(241, 61, 765, 1168)},
	"parkDojun":{"file":"res://assets/characters-sd/park_sd_01.png", "region":Rect2(278, 106, 727, 1128)},
	"yoonHarin":{"file":"res://assets/characters-sd/yoon_sd_01.png", "region":Rect2(237, 93, 798, 1118)}
}
const GROUPS := {"characters":"각성자", "weapons":"무기", "enemies":"몬스터", "items":"아이템", "weeklyRules":"주간 규칙", "blessings":"단군의 축복"}
const STATS := {"damage":"공통 피해", "attackSpeed":"공격 속도", "meleeDamage":"근접 피해", "rangedDamage":"원거리 피해", "criticalChance":"치명타 확률", "criticalDamage":"치명타 피해", "range":"사거리", "area":"범위", "duration":"지속시간", "projectileSpeed":"투사체 속도", "maxHp":"최대 체력", "armor":"방어력", "dodge":"회피", "lifesteal":"흡혈", "hpRegeneration":"체력 재생", "moveSpeed":"이동 속도", "currencyGain":"마력석 획득", "pickupRange":"획득 범위", "luck":"행운", "curse":"저주"}
const RATIOS := ["damage", "attackSpeed", "meleeDamage", "rangedDamage", "criticalChance", "criticalDamage", "range", "area", "duration", "projectileSpeed", "dodge", "lifesteal", "currencyGain"]
const RARITIES := {"COMMON":"일반", "UNCOMMON":"고급", "RARE":"희귀", "LEGENDARY":"전설"}
const CAPABILITIES := {"MELEE":"근접", "RANGED":"원거리", "PROJECTILE":"투사체", "AREA":"범위", "ORBIT":"회전", "CHAIN":"연쇄", "EXPLOSIVE":"폭발", "PIERCING":"관통", "STRUCTURE":"설치물", "TURRET":"포탑", "MINE":"지뢰", "AURA":"마력장", "TRAP":"함정", "BEAM":"광선", "SUMMON":"소환", "DURATION":"지속", "HAS_RANGE":"사거리", "CAN_CRIT":"치명타"}

static func build(ui, parent: Control, kind: String) -> void:
	if kind == "archive":
		_archive(ui, parent)
	else:
		_selection(ui, parent, kind)

static func _selection(ui, parent: Control, kind: String) -> void:
	var titles := {"character":"각성자 선택", "weapon":"시작 무기 선택", "blessing":"단군의 축복 선택"}
	var subtitles := {"character":"함께 서울의 게이트로 들어갈 각성자를 고르세요.", "weapon":"선택한 무기 1종으로 시작합니다. 전투 보유 한도는 6종입니다.", "blessing":"이번 작전에 적용할 축복을 하나 고르세요."}
	var steps := {"character":"03 / 06", "weapon":"04 / 06", "blessing":"05 / 06"}
	ui.header(parent, str(titles[kind]), "", str(steps[kind]), {"back_caption":"이전"})
	ui.text(parent, str(subtitles[kind]), Rect2(28, 72, 572, 24), "body", 13, "muted")
	var ids: Array = ui.content.characters.keys() if kind == "character" else STARTERS.duplicate() if kind == "weapon" else BLESSINGS.duplicate()
	var selected: String = str(FIXTURE[kind])
	var scroll := _scroll(parent, Rect2(28, 102, 572, 240), "SelectionList_" + kind)
	var surface := Control.new()
	surface.custom_minimum_size = Vector2(552, maxf(248, ceili(ids.size() / 4.0) * 128 - 8))
	scroll.add_child(surface)
	for i in range(ids.size()):
		var id: String = str(ids[i])
		var locked := kind == "blessing" and not id.is_empty() and not BLESSING_LEVELS.has(id)
		var caption := _name(ui, kind, id)
		if kind == "blessing" and not id.is_empty():
			caption += "\n미해금" if locked else "\nLv.%d" % int(BLESSING_LEVELS[id])
		var rect := Rect2(float(i % 4) * 140, floorf(i / 4.0) * 128, 132, 120)
		var card = ui.card(surface, caption, _art(ui, kind, id), rect, id == selected, locked, {"image_height":76, "caption_size":16, "content_id":id})
		if card != null:
			card.name = "DraftChoice_" + ("none" if id.is_empty() else id)
			card.set_meta("content_id", id)
			card.set_meta("choice_kind", kind)
	_selection_detail(ui, parent, Rect2(618, 102, 266, 240), kind, selected)
	var next_labels := {"character":"시작 무기 선택", "weapon":"단군의 축복 선택", "blessing":"편성 확인"}
	ui.text(parent, "현재 선택 · " + _name(ui, kind, selected), Rect2(36, 351, 664, 45), "body", 14)
	ui.button(parent, str(next_labels[kind]), Rect2(711, 351, 174, 45), "ops/primary", 16)

static func _selection_detail(ui, parent: Control, rect: Rect2, kind: String, id: String) -> void:
	ui.material(parent, "ops/info", rect)
	var content := Rect2(rect.position + Vector2(20, 12), rect.size - Vector2(40, 24))
	var title := _name(ui, kind, id)
	var title_height := _text_height(ui, title, content.size.x, "heading", 18)
	ui.text(parent, title, Rect2(content.position, Vector2(content.size.x, title_height)), "heading", 18, "ink", HORIZONTAL_ALIGNMENT_CENTER, true)
	var source = _art(ui, kind, id)
	var has_art: bool = source != null and not (source is String and source.is_empty())
	var core := _profile_core(ui, kind, id)
	var copy_width := content.size.x - 88 if has_art else content.size.x
	var copy_height := 0.0
	for line in core:
		copy_height += _text_height(ui, str(line.text), copy_width, str(line.role), int(line.size))
	copy_height += 6 * maxi(0, core.size() - 1)
	var profile_height := maxf(90 if has_art else 0, copy_height)
	var profile_pos := content.position + Vector2(0, title_height + 7)
	if has_art:
		ui.art(parent, source, Rect2(profile_pos, Vector2(76, profile_height)), true)
	var profile := VBoxContainer.new()
	profile.name = "SelectionProfile_" + kind
	profile.position = profile_pos + Vector2(88 if has_art else 0, 0)
	profile.size = Vector2(copy_width, profile_height)
	profile.custom_minimum_size.x = copy_width
	profile.add_theme_constant_override("separation", 6)
	profile.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(profile)
	for line in core:
		var label := _flow(ui, profile, str(line.text), str(line.role), int(line.size), str(line.color))
		label.set_meta("scroll_copy", false)
	var body_top := profile_pos.y + profile_height + 8
	var column := _flow_region(parent, Rect2(content.position.x, body_top, content.size.x, content.end.y - body_top), "SelectionDetails")
	match kind:
		"character":
			var definition: Dictionary = ui.content.characters[id]
			_flow(ui, column, str(definition.description), "body", 14, "muted")
			_flow(ui, column, "기본 스탯", "heading", 18)
			for stat in definition.baseStats:
				_pair(ui, column, str(STATS.get(stat, stat)), _stat_value(str(stat), float(definition.baseStats[stat])))
		"weapon":
			var definition: Dictionary = ui.content.weapons[id]
			_flow(ui, column, _traits(definition.capabilities), "body", 13, "accent")
			_flow(ui, column, str(definition.description), "body", 14, "muted")
			_flow(ui, column, "기초 공격 · Lv.1", "heading", 18)
			_pair(ui, column, "사거리", _number(float(definition.base.range)))
			_pair(ui, column, "투사체 / 타격 수", str(int(definition.base.projectileCount)))
			_flow(ui, column, "적용 스탯", "heading", 18)
			_flow(ui, column, _applied_stats(definition.capabilities), "body", 14, "muted")
		"blessing":
			if id.is_empty():
				_flow(ui, column, "축복을 해금하면 이 목록에서 선택할 수 있습니다.", "body", 14, "muted")
			else:
				var definition: Dictionary = ui.content.blessings[id]
				var level := int(BLESSING_LEVELS.get(id, 0))
				_flow(ui, column, str(definition.description), "body", 14, "muted")
				if definition.modifiers.size() > 1:
					_flow(ui, column, "추가 적용 효과" if level > 0 else "해금 시 추가 효과", "heading", 18)
					for modifier in definition.modifiers.slice(1):
						_flow(ui, column, _modifier(modifier, maxi(1, level)), "body", 14)
				if definition.has("structureLimitAtLevel"):
					_flow(ui, column, "Lv.%d부터 설치 한도 +1" % int(definition.structureLimitAtLevel), "body", 14, "muted")

static func _profile_core(ui, kind: String, id: String) -> Array:
	match kind:
		"character":
			var definition: Dictionary = ui.content.characters[id]
			return [
				{"text":str(definition.trait.name), "role":"heading", "size":18, "color":"accent"},
				{"text":str(definition.trait.description), "role":"body", "size":14, "color":"ink"}
			]
		"weapon":
			var definition: Dictionary = ui.content.weapons[id]
			return [
				{"text":_family(definition.capabilities) + " · Lv.1", "role":"heading", "size":18, "color":"accent"},
				{"text":"피해 " + _number(float(definition.base.damage)), "role":"body", "size":14, "color":"ink"},
				{"text":"공격 간격 %.2f초" % float(definition.base.cooldown), "role":"body", "size":14, "color":"ink"}
			]
		"blessing":
			if id.is_empty(): return [{"text":"축복을 적용하지 않고 출동합니다.", "role":"body", "size":14, "color":"muted"}]
			var definition: Dictionary = ui.content.blessings[id]
			var level := int(BLESSING_LEVELS.get(id, 0))
			var result: Array = [{"text":"보유 레벨 · Lv.%d" % level if level > 0 else "미해금 · Lv.1 효과", "role":"body", "size":13, "color":"accent" if level > 0 else "muted"}]
			if not definition.modifiers.is_empty():
				result.append({"text":_modifier(definition.modifiers[0], maxi(1, level)), "role":"body", "size":14, "color":"ink"})
			return result
	return []

static func _archive(ui, parent: Control) -> void:
	ui.header(parent, "자료집")
	var group_index := 0
	for group in GROUPS:
		ui.button(parent, str(GROUPS[group]), Rect2(24 + group_index * 146, 76, 138, 44), "ops/tab_selected" if group == "items" else "ops/tab", 16)
		group_index += 1
	var ids: Array = ui.content.items.keys()
	ids.sort_custom(func(a, b): return RARITIES.keys().find(ui.content.items[a].rarity) < RARITIES.keys().find(ui.content.items[b].rarity))
	ui.text(parent, "아이템", Rect2(26, 132, 326, 28), "heading", 18)
	ui.text(parent, str(ids.size()), Rect2(382, 132, 74, 28), "number", 18, "muted", HORIZONTAL_ALIGNMENT_RIGHT)
	var scroll := _scroll(parent, Rect2(24, 164, 441, 189), "ArchiveCollection")
	var grid := Control.new()
	grid.custom_minimum_size = Vector2(418, ceili(ids.size() / 5.0) * 81 - 8)
	scroll.add_child(grid)
	for i in range(ids.size()):
		var id: String = str(ids[i])
		var rect := Rect2(float(i % 5) * 85, floorf(i / 5.0) * 81, 78, 73)
		var card = ui.card(grid, "", ui.item_texture(id), rect, id == str(FIXTURE.archive), false, {"image_height":57, "content_id":id, "compact":true})
		if card != null: card.name = "Archive_" + id
	# Keep the selected rare item visible while preserving the actual rarity order.
	var selected_row := floori(ids.find(str(FIXTURE.archive)) / 5.0)
	scroll.set_deferred("scroll_vertical", maxi(0, selected_row * 81 - 81))
	ui.text(parent, "‹", Rect2(24, 357, 44, 44), "number", 22, "muted", HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(parent, str(ui.content.maps.seoul.name), Rect2(79, 357, 320, 44), "body", 14, "muted", HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(parent, "›", Rect2(413, 357, 44, 44), "number", 22, "muted", HORIZONTAL_ALIGNMENT_CENTER)
	ui.controls.append({"caption":"지역 이전", "role":"unframed", "rect":[24,357,44,44], "minimum44":true})
	ui.controls.append({"caption":"지역 다음", "role":"unframed", "rect":[413,357,44,44], "minimum44":true})
	var definition: Dictionary = ui.content.items[str(FIXTURE.archive)]
	ui.material(parent, "codex/panel", Rect2(488, 132, 404, 273))
	# The authored book spine is preserved. Copy has a shared 48 px left inset.
	ui.text(parent, str(definition.name), Rect2(536, 148, 332, 33), "heading", 18, "ink", HORIZONTAL_ALIGNMENT_CENTER)
	var tabs := ["특징", "효과", "구매 정보"]
	for i in range(tabs.size()):
		ui.button(parent, str(tabs[i]), Rect2(536 + i * 112, 186, 108, 44), "ops/tab_selected" if i == 1 else "ops/tab", 16)
	var column := _flow_region(parent, Rect2(536, 242, 332, 149), "ArchiveBody")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var art = ui.art(row, ui.item_texture(str(definition.id)), Rect2(0, 0, 98, 116), true)
	art.custom_minimum_size = Vector2(98, 116)
	art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var copy := VBoxContainer.new()
	copy.custom_minimum_size.x = 198
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 7)
	row.add_child(copy)
	_flow(ui, copy, str(RARITIES.get(definition.rarity, definition.rarity)) + " · 게이트24", "heading", 18, "reward")
	for effect in definition.shopText.effects:
		_flow(ui, copy, str(effect), "body", 14)
	for penalty in definition.shopText.penalties:
		_flow(ui, copy, "패널티 · " + str(penalty), "body", 14, "danger")
	_flow(ui, column, str(definition.description), "body", 14, "muted")
	_pair(ui, column, "정확한 가격 · 마력석", str(int(definition.basePrice)))
	_pair(ui, column, "보유 상한", str(int(definition.maxStacks)))

static func _scroll(parent: Control, rect: Rect2, node_name: String) -> ScrollContainer:
	var result := ScrollContainer.new()
	result.name = node_name
	result.position = rect.position
	result.size = rect.size
	result.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	result.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	result.clip_contents = true
	result.follow_focus = true
	parent.add_child(result)
	return result

static func _flow_region(parent: Control, rect: Rect2, node_name: String) -> VBoxContainer:
	var scroll := _scroll(parent, rect, node_name)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = rect.size.x - 16
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	scroll.add_child(column)
	return column

static func _text_height(ui, caption: String, width: float, role: String, size: int) -> float:
	var face: Font = ui.font(role)
	var measured := face.get_multiline_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, width, size)
	var line_count := maxi(1, ceili(measured.y / face.get_height(size)))
	var spacing := 2 * maxi(0, line_count - 1)
	return maxf(ceilf(face.get_height(size) * line_count) + spacing + 2, ceilf(measured.y) + spacing + 2)

static func _flow(ui, parent: Control, caption: String, role: String = "body", size: int = 14, color_role: String = "ink", centered: bool = false) -> Label:
	var width := maxf(120, parent.custom_minimum_size.x)
	if width <= 120: width = 218
	var height := _text_height(ui, caption, width, role, size)
	var result = ui.text(parent, caption, Rect2(0, 0, width, height), role, size, color_role, HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT, true)
	result.custom_minimum_size.y = height
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.set_meta("scroll_copy", true)
	return result

static func _pair(ui, parent: Control, caption: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 28
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var title = ui.text(row, caption, Rect2(0, 0, 130, 28), "body", 14, "muted")
	title.custom_minimum_size = Vector2(130, 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.set_meta("scroll_copy", true)
	var amount = ui.text(row, value, Rect2(0, 0, 74, 28), "number", 18, "ink", HORIZONTAL_ALIGNMENT_RIGHT)
	amount.custom_minimum_size = Vector2(74, 28)
	amount.set_meta("scroll_copy", true)

static func _name(ui, kind: String, id: String) -> String:
	if kind == "blessing" and id.is_empty(): return "축복 없음"
	return str(ui.content[{"character":"characters", "weapon":"weapons", "blessing":"blessings"}[kind]][id].name)

static func _art(ui, kind: String, id: String) -> Variant:
	if kind == "blessing": return null if id.is_empty() else str(ui.content.blessings[id].image)
	if kind == "weapon": return str(ui.content.weaponArt[id])
	var definition: Dictionary = SD_PORTRAITS[id]
	var atlas := AtlasTexture.new()
	atlas.atlas = ui.texture(str(definition.file), false)
	atlas.region = definition.region
	atlas.filter_clip = true
	return atlas

static func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")

static func _stat_value(key: String, value: float) -> String:
	return _number(value * 100) + "%" if key in RATIOS else _number(value)

static func _modifier(definition: Dictionary, level: int) -> String:
	var key: String = definition.stat
	var percent: bool = definition.operation == "multiply" or key in ["criticalChance", "criticalDamage", "dodge", "lifesteal"]
	var amount := (float(definition.value) - 1) * 100 * level if definition.operation == "multiply" else float(definition.value) * level
	if definition.operation == "add" and percent: amount *= 100
	return str(STATS.get(key, key)) + " " + ("+" if amount >= 0 else "") + _number(amount) + ("%" if percent else "")

static func _family(caps: Array) -> String:
	if "STRUCTURE" in caps: return "설치물"
	return "근접" if "MELEE" in caps else "원거리" if "RANGED" in caps else "마력"

static func _traits(caps: Array) -> String:
	var names: Array = []
	for cap in caps:
		if cap not in ["MELEE", "RANGED", "STRUCTURE"] and CAPABILITIES.has(cap): names.append(CAPABILITIES[cap])
	return " · ".join(names)

static func _applied_stats(caps: Array) -> String:
	var names: Array = ["공통 피해", "공격 속도"]
	var links := {"MELEE":"근접 피해", "RANGED":"원거리 피해", "AREA":"범위", "PROJECTILE":"투사체 속도", "DURATION":"지속시간", "HAS_RANGE":"사거리", "CAN_CRIT":"치명타 확률·피해"}
	for cap in caps:
		if links.has(cap): names.append(links[cap])
	return " · ".join(names)
