shader_type canvas_item;

uniform float value_threshold : hint_range(0.0, 1.0) = 0.94;
uniform float saturation_threshold : hint_range(0.0, 1.0) = 0.08;
uniform float edge_softness : hint_range(0.001, 0.2) = 0.03;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float max_channel = max(tex_color.r, max(tex_color.g, tex_color.b));
	float min_channel = min(tex_color.r, min(tex_color.g, tex_color.b));
	float saturation = max_channel - min_channel;
	float whiteness = min_channel;
	float mask = 1.0 - smoothstep(value_threshold - edge_softness, value_threshold + edge_softness, whiteness);
	vec4 color = tex_color;
	if (max_channel >= value_threshold && saturation <= saturation_threshold) {
		color.a *= mask;
	}
	color *= COLOR;
	if (color.a <= 0.01) {
		discard;
	}
	COLOR = color;
}
