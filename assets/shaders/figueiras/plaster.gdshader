shader_type spatial;

uniform sampler2D color_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaster_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform bool pattern_atlas = false;
uniform int atlas_tile = 0;
uniform vec4 wall_color : source_color = vec4(1.0);
uniform vec2 tiling = vec2(3.0, 2.0);
uniform bool material_detail = false;
uniform bool instance_tint = false;
uniform bool masonry = false;
uniform vec2 masonry_repeat = vec2(1.16, 1.75);
varying vec3 wall_point;
varying float wall_height;
varying float wall_top;
varying float tall_wall;
varying vec2 finish_uv;

void vertex() {
	float height = length(MODEL_MATRIX[1].xyz);
	wall_height = (VERTEX.y + 0.5) * height;
	wall_top = (0.5 - VERTEX.y) * height;
	tall_wall = smoothstep(0.75, 2.0, height);
	wall_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	finish_uv = UV * tiling;
	if (pattern_atlas) {
		float lengthwise = abs(NORMAL.x) > 0.5 ? length(MODEL_MATRIX[2].xyz) : length(MODEL_MATRIX[0].xyz);
		finish_uv = UV * vec2(lengthwise, height) * 0.38 + wall_point.xz * 0.045;
	} else if (masonry) {
		float width = length(MODEL_MATRIX[0].xyz);
		float depth = length(MODEL_MATRIX[2].xyz);
		finish_uv = UV * vec2(abs(NORMAL.x) > 0.5 ? depth : width, abs(NORMAL.y) > 0.5 ? depth : height) * masonry_repeat;
	}
}

void fragment() {
	vec3 base;
	float surface_variation;
	if (pattern_atlas) {
		float tile = instance_tint ? floor(COLOR.a * 4.0) : float(atlas_tile);
		vec2 cell = vec2(mod(tile, 2.0), floor(tile / 2.0));
		vec2 uv = (cell + vec2(0.017) + fract(finish_uv) * 0.966) * 0.5;
		vec3 plaster = textureGrad(plaster_atlas, uv, dFdx(finish_uv) * 0.483, dFdy(finish_uv) * 0.483).rgb;
		float gray = dot(plaster, vec3(0.25, 0.66, 0.09));
		float midpoint = tile < 0.5 ? 0.80 : (tile < 1.5 ? 0.51 : (tile < 2.5 ? 0.53 : 0.67));
		surface_variation = clamp(0.5 + (gray - midpoint) * 1.16, 0.0, 1.0);
		base = vec3(clamp(0.86 + (gray - midpoint) * 0.67, 0.59, 1.0));
	} else {
		base = texture(color_texture, finish_uv).rgb;
		surface_variation = base.r;
	}
	float column = wall_point.x * 0.87 + wall_point.z * 0.62;
	float drainage = sin(column * 0.81 + sin(column * 0.37) * 1.65) * 0.22 + 0.38 + surface_variation * 0.24;
	float rising_damp = tall_wall * (1.0 - smoothstep(0.02, 0.42 + drainage * 0.73, wall_height));
	float runoff = smoothstep(0.46, 0.81, drainage) * (1.0 - smoothstep(0.08, 1.82, wall_top));
	float sheltered = tall_wall * (1.0 - smoothstep(0.0, 0.29, wall_top));
	vec3 paint = instance_tint ? COLOR.rgb : wall_color.rgb;
	vec3 finish = paint * base * (1.0 - rising_damp * 0.22 - sheltered * 0.105 - runoff * 0.13);
	ALBEDO = mix(finish, finish * vec3(0.84, 0.93, 0.81), rising_damp * 0.42 + runoff * 0.24);
	ROUGHNESS = 0.86 + rising_damp * 0.08;
	SPECULAR = 0.22;
	if (material_detail) {
		NORMAL_MAP = texture(normal_texture, finish_uv).rgb;
		NORMAL_MAP_DEPTH = 0.38;
	}
}
