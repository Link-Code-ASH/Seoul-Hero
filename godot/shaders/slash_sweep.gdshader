shader_type canvas_item;
render_mode unshaded;

uniform float arc = 1.0472;
uniform float elapsed = 0.0;
uniform float sweep_seconds = 0.18;
uniform float duration = 0.30;
uniform float ribbon_width = 0.042;
uniform float tail_fraction = 0.64;
uniform float glow_strength = 0.24;
uniform vec3 stroke_ends = vec3(0.18, 0.20, 0.23);
uniform vec2 secondary_delays = vec2(0.025, 0.055);
uniform vec2 secondary_radii = vec2(0.90, 0.80);
uniform vec2 secondary_brightness = vec2(0.40, 0.23);
uniform vec4 stroke_color : source_color = vec4(0.12, 0.72, 1.0, 1.0);
varying vec4 vertex_tint;

void vertex() { vertex_tint = COLOR; }

vec4 ribbon(vec2 p, float delay, float radius_scale, float brightness, float width_scale, float end_time) {
    float clock = elapsed - delay;
    float life = clamp(clock / max(0.001, end_time - delay), 0.0, 1.0);
    float swing = clamp(clock / max(0.001, (sweep_seconds - delay * 0.35) * 0.82), 0.0, 1.0);
    float head = swing * swing * (3.0 - 2.0 * swing);
    float auxiliary = 1.0 - radius_scale;
    head = clamp(head + auxiliary * 0.45 * (1.0 - head), 0.0, 1.0);
    float head_angle = arc * (head - 0.5) + auxiliary * 0.10 * sin(head * 3.14159265);
    float tail_length = arc * tail_fraction * smoothstep(0.0, 0.24, swing + auxiliary * 0.8);
    tail_length *= 1.0 - smoothstep(0.63, 1.0, life);
    float tail_angle = max(-arc * 0.5, head_angle - tail_length);
    float angle = atan(p.y, p.x);
    float along = clamp((angle - tail_angle) / max(0.001, head_angle - tail_angle), 0.0, 1.0);
    float window = smoothstep(tail_angle - 0.005, tail_angle + 0.018, angle)
        * (1.0 - smoothstep(head_angle - 0.003, head_angle + 0.009, angle));
    float width = ribbon_width * width_scale * (0.15 + 0.85 * sin(3.14159265 * pow(along, 0.78)));
    float center = (0.69 + 0.17 * head + 0.065 * along + auxiliary * 0.22 * sin(along * 3.14159265)) * radius_scale;
    float distance = abs(length(p) - center);
    float body = 1.0 - smoothstep(width * 0.52, width, distance);
    // Saturated two-tone cel fill: a deeper shade of the stroke hue, no dark ink rim.
    float outline = 1.0 - smoothstep(width * 0.95, width * 1.45, distance);
    float white_core = 1.0 - smoothstep(width * 0.06, width * 0.24, distance);
    float glow = exp(-pow(distance / (width + 0.014), 2.0)) * glow_strength;
    float edge = exp(-pow((length(p) - center - width * 0.3) / 0.004, 2.0));
    vec2 tip = vec2(cos(head_angle), sin(head_angle)) * (0.755 + 0.17 * head) * radius_scale;
    float tip_light = exp(-pow(length(p - tip) / (0.018 * width_scale), 2.0));
    float fade = smoothstep(0.0, 0.05, life) * (1.0 - smoothstep(0.61, 1.0, life));
    float alpha = clamp((max(body * 0.89 + glow, outline * 0.82)) * window + tip_light * 0.75, 0.0, 1.0) * fade * brightness;
    vec3 color = mix(stroke_color.rgb * 0.62, stroke_color.rgb, body);
    color = mix(color, vec3(0.95, 1.0, 1.0), clamp(white_core * 0.88 + tip_light, 0.0, 1.0));
    return vec4(color, alpha);
}

void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.12;
    vec4 primary = ribbon(p, 0.0, 1.0, 1.0, 1.0, stroke_ends.x);
    vec4 inner = ribbon(p, secondary_delays.x, secondary_radii.x, secondary_brightness.x, 0.88, stroke_ends.y);
    vec4 last = ribbon(p, secondary_delays.y, secondary_radii.y, secondary_brightness.y, 0.72, stroke_ends.z);
    float angle = atan(p.y, p.x);
    float sector = smoothstep(-arc * 0.5, -arc * 0.5 + 0.02, angle)
        * (1.0 - smoothstep(arc * 0.5 - 0.02, arc * 0.5, angle));
    float ghost = exp(-pow((length(p) - 0.90) / 0.012, 2.0)) * sector;
    ghost *= smoothstep(0.14, 0.19, elapsed) * (1.0 - smoothstep(0.19, duration, elapsed)) * 0.19;
    float alpha = clamp(primary.a + inner.a + last.a + ghost, 0.0, 1.0);
    vec3 weighted = primary.rgb * primary.a + inner.rgb * inner.a + last.rgb * last.a + stroke_color.rgb * ghost;
    vec3 color = weighted / max(0.0001, primary.a + inner.a + last.a + ghost);
    // All strokes share the actual attack sector and stop inside its reach.
    alpha *= sector * (1.0 - smoothstep(0.975, 1.0, length(p)));
    COLOR = vec4(color, alpha) * vertex_tint;
}
