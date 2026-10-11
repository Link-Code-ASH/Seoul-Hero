// Lobby menu plate: a slanted frosted-glass parallelogram with scanlines, an accent edge strip,
// corner brackets and an optional light sweep / scan beam / hatch. The node rect is the shape's
// bounding box grown by `pad` on every side so the brackets can sit just outside the corners.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 rect_size = vec2(268.0, 64.0);
uniform float pad = 8.0;
uniform float slant = 14.0;
uniform bool dark = false;
uniform vec4 accent : source_color = vec4(0.18, 0.48, 0.96, 1.0);
uniform float hover = 0.0;
uniform float sweep = -1.0;
uniform float hatch = 0.0;
uniform float beam_speed = 0.0;
uniform float edge_width = 5.0;
uniform float blur_lod = 2.5;
// Deploy extras: pulsing outer glow, a light running round the border, a sweep every few
// seconds and moving hatch stripes.
uniform float glow = 0.0;
// Offset outline of a second plate behind this one (layered frame), drawn only outside the plate.
uniform float ghost = 0.0;
uniform float run_light = 0.0;
uniform bool auto_sweep = false;
uniform float hatch_speed = 0.0;

float box(vec2 q, vec2 lo, vec2 hi) {
	return step(lo.x, q.x) * step(q.x, hi.x) * step(lo.y, q.y) * step(q.y, hi.y);
}

float bracket(vec2 q, float o, float arm) {
	return max(box(q, vec2(o), vec2(o + arm, o + 2.0)), box(q, vec2(o), vec2(o + 2.0, o + arm)));
}

void fragment() {
	vec2 p = UV * rect_size - vec2(pad);
	vec2 s = rect_size - vec2(pad * 2.0);
	float h = s.y;
	float w2 = s.x - slant;
	// u runs along the plate with the slant removed: 0 at the left edge, w2 at the right edge.
	float u = p.x - slant * (1.0 - p.y / h);
	float a = smoothstep(-0.6, 0.6, u) * smoothstep(-0.6, 0.6, w2 - u)
		* smoothstep(-0.6, 0.6, p.y) * smoothstep(-0.6, 0.6, h - p.y);
	vec3 back = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	vec3 ink = dark ? vec3(1.0) : vec3(0.06, 0.09, 0.125);
	float t = clamp(u / w2, 0.0, 1.0);
	vec3 col;
	if (dark) {
		vec3 fill = mix(vec3(0.09, 0.13, 0.18), vec3(0.04, 0.06, 0.086), clamp(p.y / h, 0.0, 1.0));
		fill = mix(fill, accent.rgb * 0.45, 0.22);
		col = mix(back, fill, 0.9 + hover * 0.06);
	} else {
		// Pale wash of the accent colour, slightly stronger toward the right end.
		vec3 fill = mix(mix(vec3(1.0), accent.rgb, 0.16), mix(vec3(0.91, 0.933, 0.957), accent.rgb, 0.24), t);
		fill = mix(fill, mix(vec3(1.0), accent.rgb, 0.1), hover * 0.6);
		col = mix(back, fill, mix(mix(0.88, 0.7, t), 0.96, hover));
	}
	if (mod(p.y, 3.0) < 1.0) col = mix(col, ink, 0.05);
	if (hatch > 0.0 && u > w2 - 22.0 - hatch && u < w2 - 22.0 && mod(u + TIME * hatch_speed, 9.0) < 3.0) col = mix(col, vec3(1.0), 0.18);
	if (beam_speed > 0.0) {
		float by = mod(TIME * beam_speed, h + 52.0) - 26.0;
		col = mix(col, vec3(1.0), (1.0 - smoothstep(0.0, 13.0, abs(p.y - by))) * 0.14);
	}
	float sw = sweep;
	if (auto_sweep && sw < -0.5) sw = fract(TIME / 3.2) * 2.4 - 0.6;
	if (sw > -0.5) {
		float d = (u + p.y * 0.4) / w2 - sw;
		col = mix(col, vec3(1.0), (1.0 - smoothstep(0.0, 0.13, abs(d))) * (dark ? 0.3 : 0.9));
	}
	float ew = edge_width + hover * 5.0;
	if (u < ew) col = accent.rgb;
	else if (u < ew + 2.0) col = mix(col, ink, 0.5);
	float d_edge = min(min(u, w2 - u) * 0.96, min(p.y, h - p.y));
	col = mix(col, ink, (1.0 - smoothstep(0.6, 1.4, d_edge)) * (dark ? 0.32 : 0.26 + hover * 0.22));
	if (run_light > 0.0) {
		float ang = atan(p.y - h * 0.5, (u - w2 * 0.5) * h / w2) / 6.2832;
		float phase = fract(ang - TIME * 0.35);
		float lit = smoothstep(0.8, 1.0, phase) * (1.0 - smoothstep(0.0, 2.6, d_edge));
		col = mix(col, mix(accent.rgb, vec3(1.0), 0.45), lit * run_light);
	}
	float o = -4.0 - hover * 4.0;
	float arm = dark ? 12.0 : 9.0;
	vec2 q = vec2(u, p.y);
	float br = max(bracket(q, o, arm), bracket(vec2(w2, h) - q, o, arm));
	vec4 outside = vec4(accent.rgb, 0.0);
	if (ghost > 0.0) {
		vec2 g = p - vec2(ghost, -ghost);
		float gu = g.x - slant * (1.0 - g.y / h);
		float gd = min(min(gu, w2 - gu) * 0.96, min(g.y, h - g.y));
		float line = step(0.0, gd) * (1.0 - smoothstep(0.6, 1.3, gd));
		outside.a = max(outside.a, line * 0.6);
	}
	if (glow > 0.0) {
		float du = max(-u, u - w2) * 0.96;
		float dv = max(-p.y, p.y - h);
		float dist = length(max(vec2(du, dv), vec2(0.0)));
		float pulse = 0.65 + 0.35 * sin(TIME * 3.0);
		outside.a = min(1.0, outside.a + glow * pulse * 0.55 * pow(1.0 - smoothstep(0.0, pad, dist), 1.6));
	}
	COLOR = mix(mix(outside, vec4(col, 1.0), a), vec4(accent.rgb, 1.0), br);
}
