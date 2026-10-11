shader_type canvas_item;
render_mode unshaded;

uniform float pulse = 0.0;
uniform float activation = 0.0;
uniform vec2 region_origin = vec2(0.0);
uniform vec2 region_span = vec2(1.0);
varying vec4 installation_tint;
void vertex() { installation_tint = COLOR; }
void fragment() {
    vec4 art = texture(TEXTURE,UV);
    vec2 local = (UV-region_origin)/max(region_span,vec2(0.00001));
    float cyan = smoothstep(0.02,0.20,min(art.g,art.b)-art.r);
    float glint = exp(-pow((local.y-(0.72-activation*0.35))/0.075,2.0));
    // Only status lamps and the crystal react; the solid metal stays grounded.
    art.rgb += vec3(0.02,0.065,0.075)*cyan*(0.35+pulse*0.65);
    art.rgb += vec3(0.10,0.22,0.24)*cyan*glint*activation;
    COLOR = art*installation_tint;
}
