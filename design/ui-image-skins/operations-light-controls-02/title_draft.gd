extends RefCounted

# Static title fixtures reuse the live illustration, native logo and type sizes.
# They load no production singleton, profile, audio or continuation callback.
static func build(ui, parent: Control, resume_available: bool = true) -> void:
	ui.image(parent,"titleGate",Rect2(0,0,915,412),false,true)
	ui.material(parent,"ops/info",Rect2(36,50,344,184))
	var seoul: Label = ui.text(parent,"서울",Rect2(60,66,296,55),"brand",46,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	var hero: Label = ui.text(parent,"히어로",Rect2(56,119,304,66),"brand",55,"accent",HORIZONTAL_ALIGNMENT_CENTER)
	for word in [seoul,hero]:
		word.add_theme_constant_override("outline_size",2)
		word.add_theme_color_override("font_outline_color",Color(0.95,0.97,0.98,0.9))
		word.add_theme_constant_override("shadow_offset_y",3)
		word.add_theme_color_override("font_shadow_color",Color(0.05,0.13,0.21,0.28))
	ui.text(parent,"서울 게이트 생존 액션",Rect2(62,192,292,25),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	ui.button(parent,"이어하기" if resume_available else "시작하기",Rect2(44,248,328,52),"light/primary",19)
	if resume_available: ui.button(parent,"새로하기",Rect2(44,312,328,52),"light/secondary",19)
	var music: Label = ui.text(parent,"음악 ON",Rect2(801,14,94,24),"body",14,"scene",HORIZONTAL_ALIGNMENT_CENTER)
	music.add_theme_constant_override("outline_size",1)
	music.add_theme_color_override("font_outline_color",Color(0.05,0.12,0.2,0.9))
	music.add_theme_constant_override("shadow_offset_y",1)
	music.add_theme_color_override("font_shadow_color",Color(0.05,0.12,0.2,0.8))
	ui.controls.append({"caption":"음악 ON","role":"unframed","rect":[801,4,94,44],"minimum44":true,"staticPreview":true})
