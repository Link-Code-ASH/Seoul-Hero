shader_type canvas_item;
uniform float saturation = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
    vec4 sample_color = texture(TEXTURE, UV) * COLOR;
    float value = dot(sample_color.rgb, vec3(0.299, 0.587, 0.114));
    COLOR = vec4(mix(vec3(value), sample_color.rgb, saturation) * tint.rgb, sample_color.a * tint.a);
}
