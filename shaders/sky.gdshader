shader_type sky;
// Bright tropical sky: saturated zenith, pale horizon, sun disc + halo, drifting cumulus.

uniform vec3 top_color : source_color = vec3(0.02, 0.20, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.40, 0.70, 1.0);
uniform vec3 ground_color : source_color = vec3(0.22, 0.48, 0.66);
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;
uniform float cloud_coverage = 0.5;
uniform float cloud_speed = 0.003;

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.35));
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}
	float sd = dot(d, LIGHT0_DIRECTION);
	col += LIGHT0_COLOR * (smoothstep(0.9993, 0.9996, sd) * 6.0 + pow(max(sd, 0.0), 80.0) * 0.5 + pow(max(sd, 0.0), 8.0) * 0.08);
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 0.25 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float n = texture(cloud_noise, uv).r * 0.65 + texture(cloud_noise, uv * 2.9 + 0.37).r * 0.35;
		float c = smoothstep(cloud_coverage, cloud_coverage + 0.22, n) * smoothstep(0.0, 0.2, h);
		float lit = smoothstep(cloud_coverage, cloud_coverage + 0.45, n);
		vec3 cloud = mix(vec3(0.78, 0.85, 0.94), vec3(1.05), lit);
		col = mix(col, cloud, c * 0.92);
	}
	COLOR = col;
}
