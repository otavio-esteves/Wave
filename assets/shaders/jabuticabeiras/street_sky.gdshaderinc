vec2 street_cloud_uv(vec3 ray) {
	// The warm opening in the photograph sits above the western ridge.
	float longitude = atan(ray.x, -ray.z);
	float elevation = asin(clamp(ray.y, -1.0, 1.0));
	float hem = fract((longitude + 0.12) / TAU + 0.25);
	float unfolded = 1.0 - abs(1.0 - 2.0 * hem);
	return vec2(0.08 + unfolded * 0.84,
		clamp(0.86 - 1.24 * elevation, 0.005, 0.995));
}
