uniform sampler2D sky_panorama : source_color, filter_linear_mipmap, repeat_enable;
instance uniform float reflection_daylight : instance_index(0) = 1.0;

vec3 reflected_sky(vec3 world_ray, float blur) {
	float air = smoothstep(-0.16, 0.11, world_ray.y);
	vec2 uv = vec2(fract(atan(world_ray.x, world_ray.z) / TAU + 0.63),
		clamp(acos(clamp(world_ray.y, -1.0, 1.0)) / PI + 0.038, 0.004, 0.996));
	vec3 clouds = textureLod(sky_panorama, uv, blur).rgb;
	vec3 day = mix(vec3(0.11, 0.12, 0.11), clouds, air);
	vec3 night = mix(vec3(0.008, 0.010, 0.014), vec3(0.038, 0.051, 0.079), air);
	return mix(night, day, reflection_daylight);
}
