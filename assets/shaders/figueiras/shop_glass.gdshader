shader_type spatial;
render_mode cull_back;

uniform sampler2D interior : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 crop = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 outside_color : source_color = vec4(0.62, 0.70, 0.75, 1.0);
uniform float light_inside = 0.0;
uniform float room_depth = 0.44;

void fragment() {
	// Trace a shallow room behind the glass. At a glancing angle a jamb or
	// ceiling crosses the opening before the back wall, so the plate moves
	// with the camera instead of sliding across the face of the building.
	float face = max(dot(NORMAL, VIEW), 0.045);
	vec2 ray = -vec2(dot(VIEW, TANGENT), dot(VIEW, BINORMAL)) * vec2(0.58, 0.84);
	vec2 reciprocal = 1.0 / max(abs(ray), vec2(0.0005));
	vec2 to_edge = mix(UV, vec2(1.0) - UV, step(vec2(0.0), ray)) * reciprocal;
	float to_back = room_depth / face;
	float depth = min(to_back, min(to_edge.x, to_edge.y));
	vec2 hit = clamp(UV + ray * depth, vec2(0.015), vec2(0.985));
	float recess = clamp(depth / to_back, 0.0, 1.0);
	vec3 image = texture(interior, crop.xy + hit * crop.zw).rgb;
	// A side wall receives the room's light but has no stretched window plate.
	vec3 jamb = vec3(0.27, 0.25, 0.21) * (1.0 - 0.38 * recess);
	vec3 room = mix(jamb, image, smoothstep(0.86, 0.995, recess));
	float fresnel = pow(1.0 - face, 4.0);
	float sill = smoothstep(0.0, 0.17, 1.0 - UV.y);
	float side = smoothstep(0.0, 0.095, min(UV.x, 1.0 - UV.x));
	float trim_shadow = mix(0.58, 0.92, side * sill);
	vec3 reflected = reflect(-VIEW, NORMAL);
	float above = smoothstep(-0.30, 0.40, dot(reflected, VIEW_MATRIX[1].xyz));
	vec3 reflection = outside_color.rgb * mix(0.40, 0.79, above);
	float reflectance = 0.04 + fresnel * 0.86;
	ALBEDO = mix(room * trim_shadow * 0.77, reflection * 0.57, reflectance);
	EMISSION = room * trim_shadow * (0.036 + 0.67 * light_inside) * (1.0 - reflectance)
		+ reflection * reflectance * 0.31;
	ROUGHNESS = 0.33;
	SPECULAR = 0.49;
}
