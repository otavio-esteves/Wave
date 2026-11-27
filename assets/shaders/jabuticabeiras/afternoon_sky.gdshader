shader_type sky;
render_mode disable_fog;

#include "street_sky.gdshaderinc"

uniform sampler2D clouds : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D valley : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D nursery_hills : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 horizon : source_color = vec4(0.53, 0.60, 0.73, 1.0);
uniform vec4 zenith : source_color = vec4(0.22, 0.35, 0.56, 1.0);
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);

void sky() {
	float altitude = EYEDIR.y;
	float sunward = max(dot(EYEDIR, sun_direction), 0.0);
	float west = max(0.0, dot(normalize(EYEDIR.xz + vec2(0.0001)), normalize(sun_direction.xz + vec2(0.0001))));
	float clearance = pow(west, 2.3) * (1.0 - smoothstep(-0.04, 0.35, altitude));
	vec3 warmer_air = horizon.rgb + vec3(0.16, 0.105, 0.044) * clearance;
	vec3 air = mix(warmer_air, zenith.rgb, smoothstep(0.0, 0.49, altitude));
	vec3 ground = vec3(0.13, 0.18, 0.22);
	vec3 scatter = vec3(0.26, 0.145, 0.069) * pow(sunward, 10.0);
	if (AT_CUBEMAP_PASS) {
		COLOR = mix(ground, air + scatter, smoothstep(-0.23, 0.15, altitude));
	} else {
		vec3 photo = texture(clouds, street_cloud_uv(EYEDIR)).rgb;
		float mist = 1.0 - smoothstep(-0.01, 0.30, altitude);
		vec3 sky_color = mix(photo * mix(vec3(0.77, 0.87, 0.99), vec3(1.11, 0.96, 0.83), clearance),
			air, 0.18 + mist * 0.29);
		vec3 light = vec3(1.0, 0.75, 0.47) * pow(sunward, 38.0) * 0.34;
		vec3 distant = mix(ground, sky_color + scatter + light, smoothstep(-0.22, -0.015, altitude));

		// Align the far landscape to the two openings at the ends of the road.
		// The nearby slopes and trees in front retain real motion parallax.
		bool nursery = EYEDIR.z > 0.0;
		float longitude = nursery ? atan(-EYEDIR.x, EYEDIR.z) : atan(EYEDIR.x, -EYEDIR.z);
		float elevation = asin(clamp(altitude, -1.0, 1.0));
		float opening = (1.0 - smoothstep(0.72, 1.13, abs(longitude)))
			* (1.0 - smoothstep(0.13, 0.35, elevation)) * smoothstep(-0.31, -0.12, elevation);
		if (opening > 0.001) {
			float horizon_v = nursery ? 0.58 : 0.62;
			vec2 valley_uv = clamp(vec2(0.5 + longitude / 2.31, horizon_v - elevation / 0.53), vec2(0.002), vec2(0.998));
			vec3 ridges = nursery ? texture(nursery_hills, valley_uv).rgb : texture(valley, valley_uv).rgb;
			distant = mix(distant, ridges * vec3(0.69, 0.80, 1.01) + scatter * 0.28, opening);
		}
		COLOR = distant;
	}
}
