shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D gravel_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_color : source_color, filter_linear_mipmap, repeat_enable;

void fragment() {
	float lateral = abs(UV2.x);
	float tracks = smoothstep(0.48, 0.68, lateral) * (1.0 - smoothstep(1.0, 1.32, lateral));
	float macro = 0.94 + 0.06 * sin(UV.x * 0.51 + sin(UV.y * 0.24));
	vec3 gravel = texture(gravel_color, UV).rgb * macro * mix(1.0, 0.78, tracks);
	float shoulder = smoothstep(4.08, 5.18, lateral + 0.12 * sin(UV2.y * 0.77));
	if (shoulder > 0.0) {
		vec3 grass = texture(grass_color, UV * (0.125 / 0.35)).rgb * vec3(0.74, 0.80, 0.71);
		gravel = mix(gravel, grass, shoulder);
	}
	ALBEDO = gravel;
	ROUGHNESS = mix(0.97, 0.87, tracks);
	SPECULAR = 0.25;
	NORMAL_MAP = texture(gravel_normal, UV).rgb;
	NORMAL_MAP_DEPTH = mix(0.75, 0.25, tracks) * (1.0 - shoulder * 0.5);
}
