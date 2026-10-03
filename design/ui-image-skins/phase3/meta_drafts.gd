extends RefCounted
# Isolated proposals only. No runtime autoloads, callbacks, audio or save adapters.

static func build(ui, parent: Control, screen: String) -> void:
	if "archive" in screen:
		_archive(ui, parent, "phoenixMatch" if "phoenix" in screen else "vaultLedger")
	elif "settings" in screen:
		_settings(ui, parent)
	elif "growth" in screen:
		_growth(ui, parent)

static func _growth(ui, parent: Control) -> void:
	ui.header(parent, "전략지원 · 성장", "축복 조각으로 영구 성장")
	_tabs(ui, parent, ["각성자", "공용 무기", "단군의 축복"], 2, 24, 93, 134)
	var content: Dictionary = ui.content
	var blessing: Dictionary = content.blessings.harvestKnot
	var costs: Array = content.growth.blessingCosts
	var ids: Array = content.blessings.keys()
	ui.text(parent, "단군의 축복", Rect2(26, 143, 226, 26), "heading", 18)
	for i in range(ids.size()):
		var definition: Dictionary = content.blessings[ids[i]]
		var col: int = i % 2
		var row: int = floori(i / 2.0)
		var x: float = 24 + col * 117
		var y: float = 174 + row * 54
		if str(ids[i]) == "harvestKnot":
			ui.material(parent, "arcane/selection", Rect2(x - 3, y - 4, 113, 58))
		ui.image(parent, definition.image, Rect2(x + 36, y, 39, 32))
		ui.text(parent, definition.name, Rect2(x, y + 32, 108, 25), "control", 14, "accent" if str(ids[i]) == "harvestKnot" else "ink", HORIZONTAL_ALIGNMENT_CENTER)
	ui.line(parent, Rect2(269, 148, 1, 248), "rule")
	ui.material(parent, "arcane/plinth", Rect2(290, 226, 244, 112))
	ui.image(parent, blessing.image, Rect2(306, 149, 212, 185))
	ui.text(parent, blessing.name, Rect2(289, 345, 246, 28), "heading", 22, "ink", HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(parent, "미해금 · 0 / 5 단계", Rect2(289, 378, 246, 24), "body", 14, "muted", HORIZONTAL_ALIGNMENT_CENTER)
	ui.material(parent, "arcane/panel", Rect2(557, 144, 334, 264))
	ui.text(parent, "보유 조각", Rect2(575, 155, 130, 24), "body", 14, "muted")
	ui.text(parent, "0", Rect2(794, 152, 75, 30), "number", 23, "ink", HORIZONTAL_ALIGNMENT_RIGHT)
	ui.text(parent, blessing.description, Rect2(575, 187, 292, 43), "body", 14, "ink", HORIZONTAL_ALIGNMENT_LEFT, true)
	ui.icon(parent, "currencyGain", Rect2(575, 234, 20, 20))
	ui.text(parent, "단계당 마력석 획득", Rect2(604, 231, 193, 26), "body", 14)
	ui.text(parent, "+%s%%" % str(snappedf((float(blessing.modifiers[0].value) - 1.0) * 100.0, 0.1)), Rect2(798, 231, 70, 27), "number", 20, "accent", HORIZONTAL_ALIGNMENT_RIGHT)
	ui.icon(parent, "pickupRange", Rect2(575, 263, 20, 20))
	ui.text(parent, "단계당 획득 범위", Rect2(604, 260, 193, 26), "body", 14)
	ui.text(parent, "+%s%%" % str(snappedf((float(blessing.modifiers[1].value) - 1.0) * 100.0, 0.1)), Rect2(798, 260, 70, 27), "number", 20, "accent", HORIZONTAL_ALIGNMENT_RIGHT)
	ui.text(parent, "해금 → 성장 비용", Rect2(575, 295, 290, 24), "body", 14, "muted")
	for i in range(costs.size()):
		var x: float = 575 + i * 59
		ui.material(parent, "arcane/selection", Rect2(x, 324, 51, 27))
		ui.text(parent, str(int(costs[i])), Rect2(x, 323, 51, 29), "number", 20, "reward", HORIZONTAL_ALIGNMENT_CENTER)
	ui.button(parent, "해금 · %d 조각 필요" % int(costs[0]), Rect2(575, 360, 293, 44), "controls/disabled", 16)

static func _archive(ui, parent: Control, selected_id: String) -> void:
	var content: Dictionary = ui.content
	var selected: Dictionary = content.items[selected_id]
	ui.header(parent, "자료집", "아이템 %d종 · 조건과 패널티를 함께 확인" % content.items.size())
	_tabs(ui, parent, ["각성자", "무기", "몬스터", "아이템", "단군의 축복"], 3, 24, 93, 123)
	ui.text(parent, "수집물 진열", Rect2(26, 145, 281, 26), "heading", 18)
	ui.text(parent, "‹", Rect2(338, 137, 44, 44), "number", 27, "muted", HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(parent, "01 / 03", Rect2(388, 143, 75, 28), "number", 19, "muted", HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(parent, "›", Rect2(473, 137, 44, 44), "number", 27, "accent", HORIZONTAL_ALIGNMENT_CENTER)
	ui.controls.append({"caption":"자료집 이전 페이지","role":"unframed_page","rect":[338,137,44,44],"minimum44":true})
	ui.controls.append({"caption":"자료집 다음 페이지","role":"unframed_page","rect":[473,137,44,44],"minimum44":true})
	var ids: Array = [selected_id]
	for id in content.items:
		var definition: Dictionary = content.items[id]
		if id != selected_id and content.images.has(str(definition.icon)):
			ids.append(id)
	for i in range(mini(20, ids.size())):
		var definition: Dictionary = content.items[ids[i]]
		var col: int = i % 5
		var row: int = floori(i / 5.0)
		var x: float = 24 + col * 94
		var y: float = 181 + row * 51
		ui.material(parent, "codex/tile", Rect2(x + 9, y + 38, 64, 15))
		if i == 0:
			ui.material(parent, "codex/selection", Rect2(x + 5, y - 3, 74, 55))
		var thumb = ui.image(parent, definition.icon, Rect2(x + 17, y, 48, 46))
		thumb.tooltip_text = str(definition.name)
	ui.text(parent, "선택한 수집물의 전체 효과", Rect2(26, 386, 418, 24), "body", 13, "muted")
	ui.material(parent, "codex/panel", Rect2(519, 143, 374, 265))
	ui.text(parent, selected.name, Rect2(542, 153, 192, 33), "heading", 23)
	ui.text(parent, "희귀 · 게이트24" if selected.rarity == "RARE" else "전설 · 게이트24", Rect2(542, 191, 191, 27), "body", 14, "reward")
	ui.image(parent, selected.icon, Rect2(759, 148, 110, 90))
	ui.line(parent, Rect2(542, 241, 328, 1), "rule")
	ui.text(parent, "발동 조건 · 결과", Rect2(542, 249, 327, 25), "control", 14, "muted")
	var effect_text := "보유 마력석 20마다 피해 +2%\n최대 +30% · 소비 시 즉시 감소" if selected_id == "vaultLedger" else "한 판 1회 · 치명적 피해 시 HP 1로 생존\n생존 직후 2.5초 무적"
	ui.text(parent, effect_text, Rect2(542, 279, 329, 45), "body", 14, "ink", HORIZONTAL_ALIGNMENT_LEFT, true)
	var penalty := "획득 범위 -10" if selected_id == "vaultLedger" else "최대 체력 -10"
	ui.text(parent, "패널티   " + penalty, Rect2(542, 330, 328, 28), "body", 14, "danger")
	ui.image(parent, "magicStone", Rect2(542, 371, 23, 26))
	ui.text(parent, str(int(selected.basePrice)), Rect2(575, 365, 53, 35), "number", 24)
	ui.text(parent, "보유 상한", Rect2(718, 372, 85, 27), "body", 14, "muted")
	ui.text(parent, str(int(selected.maxStacks)), Rect2(821, 365, 47, 35), "number", 24, "ink", HORIZONTAL_ALIGNMENT_RIGHT)

static func _settings(ui, parent: Control) -> void:
	ui.header(parent, "설정", "음향 · 데이터 관리")
	ui.material(parent, "console/title", Rect2(24, 100, 498, 41))
	ui.text(parent, "음향", Rect2(42, 104, 307, 31), "heading", 20)
	var defaults: Dictionary = ui.content.defaultMeta.settings
	var pairs := [["masterVolume", "전체 음량"], ["musicVolume", "배경음악"], ["combatVolume", "전투 효과음"], ["uiVolume", "UI 효과음"]]
	for i in range(pairs.size()):
		var y: float = 154 + i * 53
		var value: float = float(defaults[pairs[i][0]])
		ui.text(parent, pairs[i][1], Rect2(36, y + 2, 125, 29), "control", 14)
		ui.material(parent, "console/row", Rect2(175, y + 14, 269, 11))
		ui.material(parent, "console/selection", Rect2(167 + 269 * value, y + 4, 25, 31))
		ui.text(parent, str(int(roundf(value * 100))), Rect2(458, y, 51, 34), "number", 23, "ink", HORIZONTAL_ALIGNMENT_RIGHT)
		ui.controls.append({"caption":pairs[i][1],"role":"png_slider","rect":[175,y - 4,269,44],"minimum44":true})
	ui.text(parent, "전투 BGM은 낮게 · 효과음은 선명하게", Rect2(36, 361, 475, 30), "body", 14, "muted")
	ui.line(parent, Rect2(541, 103, 1, 306), "rule")
	ui.material(parent, "console/title", Rect2(561, 100, 331, 41))
	ui.text(parent, "데이터", Rect2(580, 104, 281, 31), "heading", 20)
	ui.text(parent, "저장 파일 관리", Rect2(578, 159, 291, 27), "control", 15)
	ui.button(parent, "저장 폴더", Rect2(574, 200, 303, 44), "controls/secondary", 16)
	ui.button(parent, "JSON 백업", Rect2(574, 256, 146, 44), "controls/secondary", 15)
	ui.button(parent, "백업 가져오기", Rect2(731, 256, 146, 44), "controls/secondary", 15)
	ui.text(parent, "개발자 모드", Rect2(578, 321, 203, 27), "body", 14)
	ui.material(parent, "console/row", Rect2(810, 314, 66, 39))
	ui.text(parent, "OFF", Rect2(811, 315, 63, 36), "number", 16, "muted", HORIZONTAL_ALIGNMENT_CENTER)
	ui.text(parent, "기본 설정값 시안 · 저장/오디오 연결 없음", Rect2(578, 365, 299, 44), "body", 13, "muted", HORIZONTAL_ALIGNMENT_LEFT, true)

static func _tabs(ui, parent: Control, entries: Array, selected: int, x: float, y: float, width: float) -> void:
	for i in range(entries.size()):
		var bounds := Rect2(x + i * width, y, width - 8, 44)
		if i == selected:
			ui.material(parent, "controls/selected", bounds)
		ui.text(parent, str(entries[i]), bounds, "control", 15, "accent" if i == selected else "muted", HORIZONTAL_ALIGNMENT_CENTER)
