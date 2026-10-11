shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 glow_color : source_color = vec4(1.0, 0.86, 0.53, 1.0);

void fragment() {
	float mask = texture(TEXTURE, UV).a;
	COLOR = vec4(glow_color.rgb, mask * COLOR.a);
}
