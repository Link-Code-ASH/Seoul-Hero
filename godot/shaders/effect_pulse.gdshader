shader_type canvas_item;
render_mode unshaded;

uniform float progress = 0.0;
uniform float phase = 0.0;
uniform int mode = 0;
uniform float ring_width = 0.024;
uniform float spokes = 8.0;
uniform float opacity = 1.0;
uniform vec4 effect_color : source_color = vec4(0.35, 0.80, 1.0, 1.0);
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }

float chevron(vec2 p, float center, float width) {
    vec2 q = p - vec2(center, 0.0);
    float distance = abs(abs(q.y) + q.x * 0.75);
    float window = smoothstep(-0.26, -0.22, q.x) * (1.0 - smoothstep(-0.01, 0.025, q.x));
    return (1.0 - smoothstep(width * 0.45, width, distance)) * window;
}

void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.12;
    float r = length(p);
    float a = atan(p.y, p.x);
    float t = clamp(progress, 0.0, 1.0);
    float burst = 1.0 - pow(1.0 - t, 3.0);
    float ring_r = mix(0.13, 0.91, burst);
    float ring = exp(-pow((r - ring_r) / max(0.008, ring_width * (1.0 - t * 0.65)), 2.0));
    float center = exp(-pow(r / mix(0.13, 0.31, t), 2.0)) * (1.0 - smoothstep(0.10, 0.50, t));
    float rays = pow(abs(cos(a * spokes * 0.5)), 18.0);
    rays *= exp(-pow((r - mix(0.09, 0.42, burst)) / 0.19, 2.0));
    float alpha = ring * 0.56 + center * 0.77 + rays * (1.0 - t) * 0.34;
    float life = smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.38, 1.0, t));
    if (mode == 1) { // shockwave: clean expanding floor rim
        alpha = ring * 0.85; life = 1.0 - smoothstep(0.20, 1.0, t);
    } else if (mode == 2) { // actual warning, subdued interior and closing rim
        float blink = 0.72 + 0.28 * sin(phase * 6.0);
        float outside = exp(-pow((r - 0.90) / ring_width, 2.0));
        float closing = exp(-pow((r - mix(0.85, 0.14, t)) / (ring_width * 0.60), 2.0));
        float segments = smoothstep(0.05, 0.18, abs(sin(a * 6.0 + phase * 0.2)));
        alpha = outside * segments * blink * 0.66 + closing * 0.28 + (1.0 - smoothstep(0.05, 0.90, r)) * 0.055;
        life = smoothstep(0.0, 0.025, t) * (1.0 - smoothstep(0.95, 1.0, t));
    } else if (mode == 3) { // support: soft petals around a quiet inner glow
        float petals = 0.53 + 0.09 * sin(a * 5.0 - phase * 2.0);
        alpha = exp(-pow((r - petals * (0.65 + burst * 0.35)) / 0.035, 2.0)) * 0.52 + ring * 0.37 + center * 0.55;
    } else if (mode == 4) { // pickup: tiny four-point crystalline shimmer
        float diamond = abs(p.x) + abs(p.y);
        alpha = exp(-pow((diamond - mix(0.12, 0.39, burst)) / 0.024, 2.0)) * 0.56 + rays * 0.58 + center;
    } else if (mode == 5) { // installation: segmented alignment marks and contact ripple
        float marks = pow(abs(sin(a * 4.0)), 22.0);
        alpha = ring * 0.50 + exp(-pow((r - 0.65) / 0.05, 2.0)) * marks * 0.58;
    } else if (mode == 6) { // charge windup: short direction marks, never a new area/path
        float pulse = 0.72 + 0.28 * sin(phase * 7.0);
        alpha = chevron(p, 0.02, ring_width) * 0.42
            + chevron(p, 0.34, ring_width) * 0.68
            + chevron(p, 0.66, ring_width) * 0.92;
        alpha *= pulse;
        life = smoothstep(0.0, 0.025, t) * (1.0 - smoothstep(0.95, 1.0, t));
    }
    alpha = clamp(alpha * life * opacity, 0.0, 1.0);
    alpha *= 1.0 - smoothstep(0.96, 1.0, r);
    vec3 color = mix(effect_color.rgb, vec3(0.96, 1.0, 1.0), clamp(center * 0.65 + rays * 0.30, 0.0, 0.83));
    COLOR = vec4(color, alpha) * vertex_tint;
}
