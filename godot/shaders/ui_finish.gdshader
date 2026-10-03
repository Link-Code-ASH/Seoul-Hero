shader_type canvas_item;

uniform vec2 surface_size = vec2(100.0,44.0);
uniform float shine = 0.0;
uniform float corner_radius = 10.0;

void fragment() {
	vec4 face = texture(TEXTURE,UV);
	float radius = min(corner_radius,min(surface_size.x,surface_size.y)*0.3);
	vec2 q = abs((UV-0.5)*surface_size)-surface_size*0.5+radius;
	float edge = length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-radius;
	float mask = 1.0-smoothstep(-1.0,0.0,edge);
	float rim = 1.0-smoothstep(0.5,3.5,-edge);
	float lower = smoothstep(0.1,0.88,UV.y);
	vec3 bevel = mix(vec3(1.0),vec3(0.12,0.28,0.44),lower);
	float bevel_alpha = rim*mix(0.62,0.4,lower);
	face.rgb = mix(face.rgb,bevel,bevel_alpha/(face.a+bevel_alpha+0.001));
	face.a = face.a+bevel_alpha*(1.0-face.a);
	float gloss = pow(max(0.0,1.0-abs(UV.y-0.16)*3.4),5.0);
	face.rgb = mix(face.rgb,vec3(1.0),gloss*(0.12+shine*0.16));
	face.a = (face.a+shine*gloss*0.1)*mask;
	COLOR = face;
}
