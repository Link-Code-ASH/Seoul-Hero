shader_type canvas_item;
render_mode unshaded, blend_add;

void fragment() {
	float edge = 1.0 - smoothstep(0.28, 0.5, abs(UV.y - 0.5));
	float core = 1.0 - smoothstep(0.02, 0.19, abs(UV.y - 0.5));
	float tail = 1.0 - smoothstep(0.65, 1.0, UV.x);
	COLOR.rgb = mix(COLOR.rgb, vec3(0.93, 1.0, 1.0), core * 0.55);
	COLOR.a *= edge * tail;
}
