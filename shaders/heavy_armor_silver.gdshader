shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float brightness = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 silver = mix(vec3(0.24, 0.27, 0.31), vec3(0.92, 0.95, 1.0), brightness);
	COLOR = vec4(silver, COLOR.a);
}
