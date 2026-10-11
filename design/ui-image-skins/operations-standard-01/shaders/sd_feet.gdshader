shader_type canvas_item;

uniform vec2 region_origin = vec2(0.0);
uniform vec2 region_span = vec2(1.0);
uniform float feet_top = 0.83;
uniform float foot_lift = 0.03;
uniform vec4 hand_left = vec4(0.16,0.69,0.24,0.22);
uniform vec4 hand_right = vec4(0.64,0.70,0.24,0.21);
uniform float hand_motion = 0.016;
uniform float phase = 0.0;
uniform float idle_phase = 0.0;
uniform float walk_amount = 0.0;
uniform float limb_amount = 1.0;
uniform float hit_flash = 0.0;
varying vec4 actor_tint;

void vertex() { actor_tint = COLOR; }

vec2 wiggle_hand(vec2 point, vec4 region, float side) {
	vec2 local = (point-region.xy)/region.zw;
	// Anchor the upper cuff and fade in transparent space around the hand.
	float mask = smoothstep(0.0,0.20,local.x)*(1.0-smoothstep(0.80,1.0,local.x));
	mask *= smoothstep(0.0,0.50,local.y)*(1.0-smoothstep(0.87,1.0,local.y));
	float rhythm = sin(phase+side*1.5708)*walk_amount;
	rhythm += sin(idle_phase+side*0.8)*0.22*(1.0-walk_amount);
	return point+vec2(side*rhythm,rhythm*0.60)*hand_motion*mask*limb_amount;
}

void fragment() {
	vec2 point = (UV-region_origin)/region_span;
	// Continuous deformation of the tiny lower silhouette keeps ankle joins intact.
	float side = point.x < 0.5 ? 1.0 : -1.0;
	float step_lift = max(0.0,sin(phase)*side);
	step_lift = step_lift*walk_amount+max(0.0,sin(idle_phase)*side)*0.13*(1.0-walk_amount);
	float lower = smoothstep(feet_top,0.97,point.y);
	point.y += step_lift*foot_lift*lower*limb_amount;
	point = wiggle_hand(point,hand_left,-1.0);
	point = wiggle_hand(point,hand_right,1.0);
	vec4 art = texture(TEXTURE,region_origin+point*region_span);
	if (point.y > 1.0 || point.y < 0.0) art.a = 0.0;
	art.rgb = mix(art.rgb,vec3(1.0),hit_flash);
	COLOR = art*actor_tint;
}
