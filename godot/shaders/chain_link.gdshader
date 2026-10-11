shader_type canvas_item;
render_mode unshaded;

uniform float progress = 0.0;
uniform float opacity = 1.0;
uniform float phase = 0.0;
uniform float aspect = 4.0;
uniform float arrival = 0.0;
uniform vec4 edge_tint : source_color = vec4(0.15, 0.30, 0.72, 1.0);
varying vec4 vertex_tint;

void vertex() { vertex_tint = COLOR; }

float jagged(float x, float step_seed) {
    float index = floor(x * 11.0);
    float t = fract(x * 11.0);
    float a = sin(index * 18.37 + step_seed) * 0.5 + sin(index * 7.71 + step_seed * 1.43) * 0.5;
    float b = sin((index + 1.0) * 18.37 + step_seed) * 0.5 + sin((index + 1.0) * 7.71 + step_seed * 1.43) * 0.5;
    return mix(a, b, t);
}

void fragment() {
    float x = UV.x;
    float y = UV.y - 0.5;
    float envelope = sin(x * 3.14159265);
    float seed = floor(phase * 0.23);
    float path = jagged(x, seed) * 0.17 * envelope;
    path += sin(x * 31.0 + phase * 0.23) * 0.025 * envelope;
    float d = abs(y - path);
    // Thicker bolt filled with saturated blue so it reads on the bright daytime plaza.
    float white_core = 1.0 - smoothstep(0.022, 0.050, d);
    float blue_edge = 1.0 - smoothstep(0.075, 0.115, d);
    float glow = exp(-pow(d / 0.12, 2.0)) * 0.20;
    float branch_path = path + jagged(x, seed + 11.0) * 0.12 * envelope;
    float branch = (1.0 - smoothstep(0.005, 0.012, abs(y - branch_path)))
        * smoothstep(0.15, 0.25, x) * (1.0 - smoothstep(0.78, 0.90, x)) * 0.32;
    float reveal = 1.0 - smoothstep(progress - 0.035, progress + 0.003, x);
    float pulse = 0.89 + 0.11 * sin(phase + x * 18.0);
    // Local X remains exactly 0..1. No branch, glow or cap can pass a target.
    float bound = smoothstep(0.0, 0.008, x) * (1.0 - smoothstep(0.992, 1.0, x));
    float discharge = exp(-pow(length(vec2((x - 0.99) * aspect, y)) / 0.15, 2.0)) * arrival;
    float rays = max(0.0, pow(abs(cos(atan(y, (x - 0.99) * aspect) * 4.0)), 18.0));
    discharge += rays * exp(-pow(length(vec2((x - 0.99) * aspect, y)) / 0.24, 2.0)) * arrival * 0.40;
    float alpha = clamp((blue_edge + glow + branch + discharge) * reveal * bound * opacity, 0.0, 1.0);
    vec3 color = mix(edge_tint.rgb, vec3(0.87, 0.99, 1.0), clamp(white_core + discharge * 0.75, 0.0, 1.0));
    COLOR = vec4(color * pulse, alpha) * vertex_tint;
}
