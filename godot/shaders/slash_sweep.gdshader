shader_type canvas_item;

uniform float arc = 1.0472;
uniform float progress = 0.0;
uniform float sweep_fraction = 0.62;
uniform float tail_fraction = 0.64;
uniform float ribbon_width = 0.042;
uniform float glow_strength = 0.24;
varying vec4 slash_tint;

void vertex() { slash_tint = COLOR; }

void fragment() {
    // This is an evolving curved ribbon, not an image mask rotating as a unit.
    vec2 p = (UV - vec2(0.5)) * 2.12;
    float radius = length(p);
    float angle = atan(p.y, p.x);
    float swing = clamp(progress / sweep_fraction, 0.0, 1.0);
    float head_progress = swing * swing * (3.0 - 2.0 * swing);
    float head_angle = arc * (head_progress - 0.5);
    float tail_length = arc * tail_fraction * smoothstep(0.0, 0.28, swing)
        * (1.0 - smoothstep(0.58, 1.0, progress));
    float tail_angle = max(-arc * 0.5, head_angle - tail_length);
    float along = clamp((angle - tail_angle) / max(0.001, head_angle - tail_angle), 0.0, 1.0);
    float window = smoothstep(tail_angle - 0.006, tail_angle + 0.020, angle)
        * (1.0 - smoothstep(head_angle - 0.004, head_angle + 0.012, angle));
    float shape = sin(3.14159265 * pow(along, 0.78));
    float width = ribbon_width * (0.16 + 0.84 * max(0.0, shape));
    float center = 0.75 + 0.17 * head_progress + 0.075 * along;
    float radial_distance = abs(radius - center);
    float body = 1.0 - smoothstep(width * 0.58, width, radial_distance);
    float glow = exp(-pow(radial_distance / (width + 0.013), 2.0)) * glow_strength;
    float edge = exp(-pow((radius - center - width * 0.35) / 0.0045, 2.0));
    // A second fine filament lags inside the stroke, following the same curve.
    float filament = exp(-pow((radius - center + 0.041) / 0.0038, 2.0))
        * sin(3.14159265 * along) * 0.23;
    vec2 tip = vec2(cos(head_angle),sin(head_angle)) * (0.825 + 0.17 * head_progress);
    float tip_light = exp(-pow(length(p - tip) / 0.018, 2.0));
    float life = smoothstep(0.0, 0.08, progress) * (1.0 - smoothstep(0.72, 1.0, progress));
    float alpha = clamp((body * 0.82 + glow + filament) * window + tip_light * 0.8, 0.0, 1.0) * life;
    vec3 color = mix(vec3(0.15,0.69,1.0),vec3(0.88,0.99,1.0),clamp(edge * 0.84 + tip_light,0.0,1.0));
    COLOR = vec4(color,alpha) * slash_tint;
}
