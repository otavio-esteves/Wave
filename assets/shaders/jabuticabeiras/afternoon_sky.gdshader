shader_type sky;
render_mode disable_fog;

uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 horizon : source_color = vec4(0.77, 0.77, 0.70, 1.0);
uniform vec4 zenith : source_color = vec4(0.33, 0.53, 0.72, 1.0);
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);

void sky() {
	float altitude = EYEDIR.y;
	float sunward = max(dot(EYEDIR, sun_direction), 0.0);
	float low_air = 1.0 - smoothstep(0.0, 0.36, altitude);
	vec3 air = mix(zenith.rgb, horizon.rgb, low_air);
	vec3 scattered = vec3(0.31, 0.15, 0.058) * pow(sunward, 6.0);
	vec3 ground = vec3(0.25, 0.24, 0.19);
	if (AT_CUBEMAP_PASS) {
		COLOR = mix(ground, air + scattered, smoothstep(-0.29, 0.13, altitude));
	} else {
		// Keep the photographic horizon just below the aerial perspective.
		vec2 uv = vec2(fract(SKY_COORDS.x + 0.17), clamp(SKY_COORDS.y + 0.036, 0.003, 0.996));
		vec3 clouds = texture(panorama, uv).rgb;
		float seam = min(uv.x, 1.0 - uv.x);
		if (seam < 0.052) {
			vec3 opposite = texture(panorama, vec2(1.0 - uv.x, uv.y)).rgb;
			clouds = mix((clouds + opposite) * 0.5, clouds, smoothstep(0.0, 0.052, seam));
		}
		float mist = 1.0 - smoothstep(0.003, 0.21, altitude);
		vec3 sky_color = mix(clouds * vec3(1.03, 1.0, 0.93), air, 0.09 + mist * 0.49);
		float disk = smoothstep(0.999954, 0.999984, sunward);
		vec3 sunlight = vec3(1.0, 0.70, 0.35) * (disk * 3.8 + pow(sunward, 58.0) * 0.44);
		COLOR = mix(ground, sky_color + scattered + sunlight, smoothstep(-0.22, 0.02, altitude));
	}
}
