shader_type canvas_item;
render_mode unshaded;

uniform vec2 region_origin = vec2(0.0);
uniform vec2 region_span = vec2(1.0);
uniform float flow_angle = 0.0;
uniform float phase = 0.0;
varying vec4 field_tint;
void vertex() { field_tint = COLOR; }

void fragment() {
    vec2 local = (UV - region_origin) / max(region_span,vec2(0.00001));
    vec2 p = local - vec2(0.5);
    float c = cos(flow_angle); float s = sin(flow_angle);
    vec2 spun = vec2(c*p.x-s*p.y,s*p.x+c*p.y)+vec2(0.5);
    vec4 art = texture(TEXTURE,region_origin+clamp(spun,vec2(0.0),vec2(1.0))*region_span);
    float r = length(p);
    float edge = 1.0-smoothstep(0.39,0.50,r);
    float rim = exp(-pow((r-0.395)/0.012,2.0)) * 0.075;
    float flow = 0.92+0.08*sin(r*18.0-phase*0.8);
    // A quiet rim and moving interior replace a rapidly spinning flat disc.
    art.rgb = mix(art.rgb,vec3(0.65,0.89,0.96),rim*1.8);
    art.a = (art.a*flow+rim)*edge;
    COLOR = art*field_tint;
}
