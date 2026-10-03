shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform float core = 0.0;
uniform vec2 region_origin = vec2(0.0);
uniform vec2 region_span = vec2(1.0);
uniform vec4 edge_tint : source_color = vec4(0.15, 0.30, 0.72, 1.0);
uniform float edge_width = 0.045;

void fragment() {
    // The quad already ends at the two impact sockets. This remap only gives
    // the painted plasma a small interior flutter and cannot extend either end.
    vec2 local_uv = (UV - region_origin) / max(region_span, vec2(0.00001));
    vec2 source_local = local_uv;
    source_local.y += sin(local_uv.x * 34.0 + phase) * 0.012 * sin(local_uv.x * 3.14159265);
    vec2 source_uv = region_origin + clamp(source_local, vec2(0.0), vec2(1.0)) * region_span;
    vec4 ink = texture(TEXTURE, source_uv);
    // A narrow blue edge gives pale plasma contrast on the bright plaza. All
    // sampling stays inside this exact-length quad and cannot overshoot a hop.
    float outline = max(texture(TEXTURE, source_uv + vec2(0.0, region_span.y * edge_width)).a,
        texture(TEXTURE, source_uv - vec2(0.0, region_span.y * edge_width)).a);
    float authored_ink = smoothstep(0.06, 0.65, ink.a);
    ink.rgb = mix(edge_tint.rgb, ink.rgb, authored_ink);
    ink.a = max(ink.a, outline * (1.0 - core) * 0.86);
    float reveal = 1.0 - smoothstep(progress - 0.025, progress + 0.005, local_uv.x);
    float ends = smoothstep(0.0, 0.015, local_uv.x) * (1.0 - smoothstep(0.985, 1.0, local_uv.x));
    ink.rgb = mix(ink.rgb, vec3(0.90, 0.97, 1.0), core * 0.65);
    float pulse = 0.91 + 0.09 * sin(phase + local_uv.x * 16.0);
    COLOR = ink * vec4(vec3(pulse), reveal * ends * opacity);
}
