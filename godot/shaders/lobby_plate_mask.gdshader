// Alpha clipping directly on the native watermark Label. No clip group or back-buffer
// sampling: preserve its existing font colour, glyph texture and glyph alpha.
shader_type canvas_item;
render_mode unshaded;

uniform vec2 rect_size = vec2(280.0, 76.0);
uniform float pad = 14.0;
uniform float slant = 14.0;
uniform vec2 label_offset = vec2(14.0, 16.0);

varying vec2 plate_position;

void vertex() {
	plate_position = VERTEX + label_offset;
}

void fragment() {
	vec2 p = plate_position - vec2(pad);
	vec2 s = rect_size - vec2(pad * 2.0);
	float h = s.y;
	float w2 = s.x - slant;
	float u = p.x - slant * (1.0 - p.y / h);
	float mask = smoothstep(-0.6, 0.6, u) * smoothstep(-0.6, 0.6, w2 - u)
		* smoothstep(-0.6, 0.6, p.y) * smoothstep(-0.6, 0.6, h - p.y);
	COLOR.a *= mask;
}
