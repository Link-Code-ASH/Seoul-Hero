shader_type canvas_item;

uniform vec2 region_origin = vec2(0.0);
uniform vec2 region_span = vec2(1.0);
uniform float feet_top = 0.88;
uniform float foot_lift = 0.035;
uniform float foot_stride = 0.05;
uniform float leg_split = 0.495;
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

vec4 sample_art(sampler2D art_texture, vec2 point) {
	vec4 art = texture(art_texture,region_origin+clamp(point,0.0,1.0)*region_span);
	if (point.y > 1.0 || point.y < 0.0 || point.x > 1.0 || point.x < 0.0) art.a = 0.0;
	return art;
}

// One leg swings from the crotch: forward (+x is the facing side) while lifted,
// back while planted. Pixels only come from that leg's own half of the art.
vec4 sample_leg(sampler2D art_texture, vec2 point, float bend, float cycle, float side, out float lift) {
	float amount = walk_amount*limb_amount;
	lift = max(0.0,cos(cycle))*foot_lift*amount;
	vec2 source = point-vec2(sin(cycle)*foot_stride*amount,-lift)*bend;
	vec4 art = sample_art(art_texture,source);
	if ((source.x-leg_split)*side < 0.0) art.a = 0.0;
	return art;
}

void fragment() {
	vec2 point = (UV-region_origin)/region_span;
	point = wiggle_hand(point,hand_left,-1.0);
	point = wiggle_hand(point,hand_right,1.0);
	// Bend weight: zero above the crotch so the body never tears, full at the shins.
	float bend = smoothstep(feet_top,feet_top+0.06,point.y);
	bend *= smoothstep(0.24,0.32,point.x)*(1.0-smoothstep(0.72,0.80,point.x));
	vec4 art;
	if (bend <= 0.0) {
		art = sample_art(TEXTURE,point);
	} else {
		float lift_left; float lift_right;
		vec4 left = sample_leg(TEXTURE,point,bend,phase,-1.0,lift_left);
		vec4 right = sample_leg(TEXTURE,point,bend,phase+PI,1.0,lift_right);
		// The swinging (lifted) foot draws over the planted one.
		vec4 front = lift_left >= lift_right ? left : right;
		vec4 back = lift_left >= lift_right ? right : left;
		art.a = front.a+back.a*(1.0-front.a);
		art.rgb = art.a > 0.0 ? (front.rgb*front.a+back.rgb*back.a*(1.0-front.a))/art.a : vec3(0.0);
	}
	art.rgb = mix(art.rgb,vec3(1.0),hit_flash);
	COLOR = art*actor_tint;
}
