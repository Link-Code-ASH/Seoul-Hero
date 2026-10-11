shader_type canvas_item;
// Art-library monsters are translucent pastel paintings without ink lines. This
// gives them the in-game SD read at combat size: an opaque body, a dark outline
// of constant on-screen thickness around the silhouette, and stronger colour.
// The motion uniforms mirror enemy_locomotion so one material can replace it.
uniform vec2 region_origin = vec2(0.0);
uniform vec2 region_span = vec2(1.0);
uniform float phase = 0.0;
uniform float walk_amount = 0.0;
uniform float body_wave = 0.0;
uniform float wing_motion = 0.0;
uniform float hit_flash = 0.0;
// Thickness in 915x412 design pixels; pixel_scale is window pixels per design pixel.
uniform float outline_px = 2.5;
uniform float pixel_scale = 1.0;
uniform vec4 outline_color : source_color = vec4(0.10,0.08,0.13,1.0);
// 0 keeps the fixed ink colour, 1 uses a darkened copy of the neighbouring art.
uniform float outline_tint : hint_range(0.0,1.0) = 0.5;
// Source alpha at or below alpha_floor is empty; alpha_floor+alpha_ramp and above is solid.
uniform float alpha_floor : hint_range(0.0,1.0) = 0.15;
uniform float alpha_ramp : hint_range(0.01,1.0) = 0.08;
uniform float saturation = 1.35;
uniform float contrast = 1.1;
// The quad grows by this fraction of the region on every side to hold the outline.
uniform float quad_pad = 0.2;
varying vec4 actor_tint;
varying vec2 wide_uv;

const int RING_SAMPLES = 16;

void vertex() {
	actor_tint = COLOR;
	vec2 local = (UV-region_origin)/region_span;
	vec2 grow = (step(vec2(0.5),local)*2.0-1.0)*quad_pad;
	VERTEX += grow*region_span/TEXTURE_PIXEL_SIZE;
	// A separate varying: the built-in UV may be clamped to the atlas region.
	wide_uv = local+grow;
}

vec2 moved(vec2 local_uv) {
	float lower_body = smoothstep(0.24,0.78,local_uv.y);
	float activity = mix(0.24,1.0,walk_amount);
	local_uv.x += sin(phase*1.2+local_uv.y*7.5)*body_wave*lower_body*activity;
	float outward = abs(local_uv.x-0.5);
	float wing_mask = smoothstep(0.16,0.34,outward)*(1.0-smoothstep(0.70,0.98,local_uv.y));
	float side = local_uv.x < 0.5 ? -1.0 : 1.0;
	float root = 0.5+side*0.17;
	local_uv.x += (local_uv.x-root)*sin(phase*2.8)*wing_motion*wing_mask;
	local_uv.y += cos(phase*2.8)*wing_motion*0.20*wing_mask;
	return local_uv;
}

float inside(vec2 local_uv) {
	vec2 edge = step(vec2(0.0),local_uv)*step(local_uv,vec2(1.0));
	return edge.x*edge.y;
}

void fragment() {
	// Local UV travelled per window pixel along each sprite axis.
	vec2 per_pixel = vec2(length(vec2(dFdx(wide_uv.x),dFdy(wide_uv.x))),length(vec2(dFdx(wide_uv.y),dFdy(wide_uv.y))));
	vec2 reach = per_pixel*outline_px*pixel_scale;
	vec2 centre = moved(wide_uv);
	vec4 art = texture(TEXTURE,region_origin+centre*region_span)*inside(centre);
	float body = smoothstep(alpha_floor,alpha_floor+alpha_ramp,art.a);
	float ring = 0.0;
	vec4 nearby = vec4(0.0);
	for (int i = 0; i < RING_SAMPLES; i++) {
		float angle = TAU*float(i)/float(RING_SAMPLES);
		vec2 direction = vec2(cos(angle),sin(angle));
		// Full radius draws the edge; the half radius closes thin gaps and tips.
		for (int step_index = 1; step_index <= 2; step_index++) {
			vec2 point = moved(wide_uv+direction*reach*float(step_index)*0.5);
			vec4 found = texture(TEXTURE,region_origin+point*region_span)*inside(point);
			float solid = smoothstep(alpha_floor,alpha_floor+alpha_ramp,found.a);
			ring = max(ring,solid);
			nearby += vec4(found.rgb,1.0)*solid;
		}
	}
	vec3 colour = art.rgb;
	colour = mix(vec3(dot(colour,vec3(0.299,0.587,0.114))),colour,saturation);
	colour = clamp((colour-0.5)*contrast+0.5,0.0,1.0);
	vec3 neighbour = nearby.rgb/max(nearby.a,0.001);
	neighbour = mix(vec3(dot(neighbour,vec3(0.299,0.587,0.114))),neighbour,1.6);
	vec3 ink = mix(outline_color.rgb,clamp(neighbour,0.0,1.0)*0.24,outline_tint);
	vec4 result = vec4(mix(ink,colour,body),max(body,ring*outline_color.a));
	result.rgb = mix(result.rgb,vec3(1.0),hit_flash*0.76);
	COLOR = result*actor_tint;
}
