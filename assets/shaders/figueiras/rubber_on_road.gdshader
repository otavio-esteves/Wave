shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

varying vec2 pavement;

void vertex() {
	pavement = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float shoulder = abs(UV.x * 2.0 - 1.0);
	float edge = 1.0 - smoothstep(0.53, 0.99, shoulder);
	vec2 aggregate = floor(pavement * 73.0);
	float grain = fract(sin(dot(aggregate, vec2(17.24, 67.91))) * 4176.4);
	float pores = mix(0.48, 1.0, grain);
	ALBEDO = vec3(0.106, 0.098, 0.090);
	ALPHA = COLOR.a * edge * pores;
}
