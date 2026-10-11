shader_type canvas_item;

// NIKKE-style smoked glass: blurs whatever is drawn behind, tints it, and adds a soft
// top sheen plus an optional mint wash toward the right edge.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.07,0.12,0.2,0.47);
uniform float blur_px = 8.0;
uniform float sheen = 0.14;
uniform vec2 plate_size = vec2(226.0,50.0);
uniform vec4 accent : source_color = vec4(0.24,0.84,0.71,1.0);
uniform float accent_amount = 0.0;
uniform float glow = 0.0;
varying vec2 local;

void vertex() { local = VERTEX; }

void fragment() {
	// Two rings of taps: works on every renderer, no screen mipmaps needed.
	vec3 behind = texture(screen_tex,SCREEN_UV).rgb*0.2;
	for (int i = 0; i < 8; i++) {
		float angle = float(i)*0.7853982;
		vec2 dir = vec2(cos(angle),sin(angle))*SCREEN_PIXEL_SIZE*blur_px;
		behind += texture(screen_tex,SCREEN_UV+dir*0.5).rgb*0.05;
		behind += texture(screen_tex,SCREEN_UV+dir).rgb*0.05;
	}
	vec3 color = mix(behind,tint.rgb,tint.a);
	float down = clamp(local.y/plate_size.y,0.0,1.0);
	color += vec3(sheen*(1.0-down)*(1.0-down));
	float across = clamp((local.x/plate_size.x-0.34)/0.66,0.0,1.0);
	color = mix(color,accent.rgb,accent_amount*pow(across,1.6));
	color += vec3(glow);
	COLOR = vec4(color,COLOR.a);
}
