shader_type canvas_item;

uniform int layer = 0;
uniform float layer_scale = 1.0;

void vertex() {
	VERTEX *= layer_scale;
	vec3 base = COLOR.rgb;
	float alpha = COLOR.a;
	bool shadow = INSTANCE_CUSTOM.a > 0.5;
	vec4 tint;
	if (layer == 0) {
		tint = vec4(base, 0.20);
	} else if (layer == 1) {
		tint = shadow ? vec4(base * 0.70, 1.0) : vec4(0.04, 0.01, 0.07, 0.98);
	} else if (layer == 2) {
		tint = vec4(base * (shadow ? 0.10 : 0.62), 1.0);
	} else {
		tint = vec4(mix(base, vec3(1.0), shadow ? 0.35 : 0.65), 1.0);
	}
	COLOR = vec4(tint.rgb * INSTANCE_CUSTOM.rgb, tint.a * alpha);
}
