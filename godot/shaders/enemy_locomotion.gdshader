shader_type canvas_item;
uniform vec2 region_origin = vec2(0.0);
uniform vec2 region_span = vec2(1.0);
uniform float phase = 0.0;
uniform float walk_amount = 0.0;
uniform float body_wave = 0.0;
uniform float wing_motion = 0.0;
uniform float hit_flash = 0.0;
varying vec4 actor_tint;

void vertex() { actor_tint = COLOR; }

void fragment() {
	vec2 local_uv = (UV-region_origin)/region_span;
	// A continuous body ripple, never alternating feet or detached limbs.
	float lower_body = smoothstep(0.24,0.78,local_uv.y);
	float activity = mix(0.24,1.0,walk_amount);
	local_uv.x += sin(phase*1.2+local_uv.y*7.5)*body_wave*lower_body*activity;
	// Compress only the free outer wings. Their attachment remains fixed while
	// one complete source image supplies both wings and the central body.
	float outward = abs(local_uv.x-0.5);
	float wing_mask = smoothstep(0.16,0.34,outward)*(1.0-smoothstep(0.70,0.98,local_uv.y));
	float side = local_uv.x < 0.5 ? -1.0 : 1.0;
	float root = 0.5+side*0.17;
	float flap = sin(phase*2.8);
	local_uv.x += (local_uv.x-root)*flap*wing_motion*wing_mask;
	local_uv.y += cos(phase*2.8)*wing_motion*0.20*wing_mask;
	if (local_uv.x<0.0 || local_uv.x>1.0 || local_uv.y<0.0 || local_uv.y>1.0) discard;
	vec4 art = texture(TEXTURE,region_origin+local_uv*region_span)*actor_tint;
	art.rgb = mix(art.rgb,vec3(1.0),hit_flash*0.76);
	COLOR = art;
}
