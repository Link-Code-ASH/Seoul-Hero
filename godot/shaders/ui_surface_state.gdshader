shader_type canvas_item;
uniform float saturation = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool preserve_source_color = false;
varying vec4 canvas_modulate;
void vertex() {
    canvas_modulate = COLOR;
}
void fragment() {
    // Fragment COLOR already includes TEXTURE. New compact art samples once;
    // existing approved surfaces keep their original state rendering.
    vec4 sample_color = texture(TEXTURE, UV) * (preserve_source_color ? canvas_modulate : COLOR);
    float value = dot(sample_color.rgb, vec3(0.299, 0.587, 0.114));
    COLOR = vec4(mix(vec3(value), sample_color.rgb, saturation) * tint.rgb, sample_color.a * tint.a);
}
