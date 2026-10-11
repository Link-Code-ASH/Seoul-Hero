// Raster glass supplies the finish and static refraction. This material supplies only the
// unchanged parallelogram mask, blurred background, and moving / interaction reflections.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D surface_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 rect_size = vec2(280.0, 76.0);
uniform float pad = 14.0;
uniform float slant = 14.0;
uniform bool dark = false;
uniform vec4 accent : source_color = vec4(0.18, 0.48, 0.96, 1.0);
uniform float hover = 0.0;
uniform float pressed = 0.0;
uniform float sweep = -1.0;
uniform float beam_speed = 0.0;
uniform float blur_lod = 2.5;
uniform float run_light = 0.0;
uniform bool auto_sweep = false;
// A node-owned clock freezes when the lobby is hidden or the application loses focus.
uniform float motion_time = 0.0;
// Only the isolated UI capture tool sets these; the production clock remains authoritative.
uniform float phase_override = -1.0;
uniform float capture_time = 0.0;

void fragment() {
	vec2 p = UV * rect_size - vec2(pad);
	vec2 s = rect_size - vec2(pad * 2.0);
	float h = s.y;
	float w2 = s.x - slant;
	float u = p.x - slant * (1.0 - p.y / h);
	float mask = smoothstep(-0.6, 0.6, u) * smoothstep(-0.6, 0.6, w2 - u)
		* smoothstep(-0.6, 0.6, p.y) * smoothstep(-0.6, 0.6, h - p.y);
	float along = clamp(u / w2, 0.0, 1.0);
	float time = phase_override >= 0.0 ? capture_time : motion_time;
	vec4 surface = texture(surface_texture, UV);
	vec3 backdrop = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	// The opaque portions of the painted source still transmit the photographed office.
	float density = dark ? 0.90 + hover * 0.06 : mix(mix(0.88, 0.72, along), 0.96, hover);
	vec3 col = mix(backdrop, surface.rgb, surface.a * density);
	col = mix(col, vec3(1.0), hover * (dark ? 0.035 : 0.065));
	col *= 1.0 - pressed * 0.07;
	float reflection_strength = 1.0 - pressed * 0.5;
	if (beam_speed > 0.0) {
		float by = mod(time * beam_speed, h + 52.0) - 26.0;
		float beam = (1.0 - smoothstep(0.0, 13.0, abs(p.y - by))) * 0.085;
		col = mix(col, vec3(1.0), beam * reflection_strength);
	}
	float sw = sweep;
	if (auto_sweep && sw < -0.5) sw = fract(time / 2.8) * 2.4 - 0.6;
	if (sw > -0.5) {
		float distance = (u + p.y * 0.4) / w2 - sw;
		float reflection = (1.0 - smoothstep(0.0, 0.13, abs(distance))) * (dark ? 0.22 : 0.42);
		col = mix(col, vec3(1.0), reflection * reflection_strength);
	}
	if (run_light > 0.0) {
		float edge = min(min(u, w2 - u) * 0.96, min(p.y, h - p.y));
		float angle = atan(p.y - h * 0.5, (u - w2 * 0.5) * h / w2) / 6.283185;
		float phase = fract(angle - time / 2.8);
		float light = smoothstep(0.8, 1.0, phase) * (1.0 - smoothstep(0.0, 2.6, edge));
		col = mix(col, mix(accent.rgb, vec3(1.0), 0.45), light * run_light * 0.55 * reflection_strength);
	}
	// Opaque compositing inside the mask also keeps native watermark clipping exact.
	COLOR = vec4(col, mask);
}
