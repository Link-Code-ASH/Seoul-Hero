shader_type canvas_item;
render_mode unshaded;

uniform float pulse : hint_range(0.0, 1.0) = 0.0;
varying vec4 installation_tint;

void vertex() { installation_tint = COLOR; }

void fragment() {
	vec4 art = texture(TEXTURE, UV) * installation_tint;
	// Only the cyan status lamps / crystal catch this subtle common pulse.
	// The metal body and its painted shadow remain still and solid.
	float cyan = smoothstep(0.02, 0.20, min(art.g, art.b) - art.r);
	art.rgb += vec3(0.02, 0.065, 0.075) * cyan * (0.35 + pulse * 0.65);
	COLOR = art;
}
