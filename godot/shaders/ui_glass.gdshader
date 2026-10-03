shader_type canvas_item;

uniform sampler2D scene_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float surface_opacity = 0.28;

void fragment() {
	vec4 authored = texture(TEXTURE, UV);
	vec3 behind = textureLod(scene_texture, SCREEN_UV, 2.0).rgb;
	COLOR = vec4(mix(authored.rgb, behind, 0.28), authored.a * surface_opacity) * COLOR;
}
