shader_type canvas_item;

uniform vec4 daylight_tint : source_color = vec4(0.86,0.94,0.93,1.0);
uniform float pastel_lift = 0.26;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 original = texture(TEXTURE,UV);
	vec3 lifted = pow(max(original.rgb,vec3(0.0)),vec3(0.72))*1.08;
	lifted = mix(lifted,daylight_tint.rgb,pastel_lift);
	COLOR = vec4(clamp(lifted,vec3(0.0),vec3(1.0)),original.a)*vertex_tint;
}
