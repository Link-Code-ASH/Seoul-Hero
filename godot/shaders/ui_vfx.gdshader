shader_type canvas_item;
// Only the authored PNG alpha is used. This layer never replaces its surface.
uniform float progress = 0.0;
uniform float strength = 0.2;
uniform bool edge_only = false;
uniform float band_width = 0.18;
uniform vec4 accent : source_color = vec4(0.8, 1.0, 0.92, 1.0);
uniform vec4 texture_bounds = vec4(0.0, 0.0, 1.0, 1.0);
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
    vec4 authored = texture(TEXTURE, UV);
    vec2 local_uv = clamp((UV - texture_bounds.xy) / max(texture_bounds.zw, vec2(0.00001)), vec2(0.0), vec2(1.0));
    float band = 1.0 - smoothstep(band_width * 0.32, band_width, abs(local_uv.x + local_uv.y * 0.26 - mix(-0.3, 1.55, progress)));
    float rim = 1.0 - smoothstep(0.025, 0.09, min(min(local_uv.x, 1.0 - local_uv.x), min(local_uv.y, 1.0 - local_uv.y)));
    float mask = edge_only ? rim : 1.0;
    float envelope = sin(clamp(progress, 0.0, 1.0) * 3.14159265);
    COLOR = vec4(accent.rgb, authored.a * strength * (band * 0.82 + envelope * 0.18) * mask) * vertex_tint;
}
