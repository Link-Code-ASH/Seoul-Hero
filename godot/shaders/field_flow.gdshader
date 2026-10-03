shader_type canvas_item;
render_mode unshaded;

uniform vec2 region_origin = vec2(0.0);
uniform vec2 region_span = vec2(1.0);
uniform float flow_angle = 0.0;
varying vec4 field_tint;

void vertex() { field_tint = COLOR; }

void fragment() {
	vec2 local = (UV - region_origin) / region_span;
	vec2 p = local - vec2(0.5);
	float c = cos(flow_angle);
	float s = sin(flow_angle);
	vec2 spun = vec2(c * p.x - s * p.y, s * p.x + c * p.y) + vec2(0.5);
	vec4 art = texture(TEXTURE, region_origin + spun * region_span) * field_tint;
	// A quiet ground glow dissolves into the floor rather than showing a cutout
	// edge. Sprite scaling supplies perspective without changing damage radius.
	art.a *= 1.0 - smoothstep(0.39, 0.50, length(p));
	COLOR = art;
}
