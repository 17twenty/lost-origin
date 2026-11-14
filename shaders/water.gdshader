shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;
// Lagoon water: depth-tinted turquoise -> deep blue, shoreline foam, scrolling normals.

uniform vec3 shallow_color : source_color = vec3(0.12, 0.88, 0.82);
uniform vec3 deep_color : source_color = vec3(0.02, 0.22, 0.55);
uniform float depth_scale = 3.5;
uniform float foam_distance = 0.35;
uniform float wave_height = 0.05;
uniform float sparkle = 1.0;      // sun glints (twinkling emission spikes)
uniform float caustics = 1.0;     // caustic shimmer in the shallows
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D normal_a : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_b : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(wpos.x * 0.35 + TIME * 1.1) + cos(wpos.z * 0.27 + TIME * 0.9)) * wave_height;
}

void fragment() {
	float depth_raw = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth_raw) * 2.0 - 1.0;   // OpenGL depth range -1..1
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float scene_dist = -view.z / view.w;
	float water_depth = max(scene_dist - (-VERTEX.z), 0.0);
	float t = clamp(water_depth / depth_scale, 0.0, 1.0);
	float n = texture(noise_tex, wpos.xz * 0.15 + vec2(TIME * 0.03, TIME * 0.02)).r;
	float foam = (1.0 - smoothstep(0.0, foam_distance * (0.6 + n), water_depth)) * step(0.001, water_depth);
	vec3 col = mix(shallow_color, deep_color, sqrt(t));
	// Caustic shimmer: two drifting noise layers, bright where they cross; shallows only.
	float ca = texture(noise_tex, wpos.xz * 0.22 + vec2(TIME * 0.05, TIME * 0.03)).r;
	float cb = texture(noise_tex, wpos.xz * 0.29 - vec2(TIME * 0.04, -TIME * 0.05)).r;
	float caustic = pow(1.0 - abs(ca - cb), 10.0) * (1.0 - smoothstep(0.0, 0.45, t)) * caustics;
	col += vec3(0.75, 1.0, 1.0) * caustic * 0.55;
	ALBEDO = mix(col, vec3(0.95, 1.0, 1.0), foam * 0.85);
	// Sun glints: sparse high-frequency twinkles, stronger at grazing angles / distance.
	float g1 = texture(noise_tex, wpos.xz * 1.7 + vec2(TIME * 0.11, -TIME * 0.07)).r;
	float g2 = texture(noise_tex, wpos.xz * 2.3 - vec2(TIME * 0.09, TIME * 0.12)).r;
	float glint = smoothstep(0.55, 0.66, g1 * g2 * 1.6);
	float grazing = 0.35 + 0.65 * (1.0 - abs(dot(NORMAL, VIEW)));
	EMISSION = vec3(1.0, 0.98, 0.9) * glint * grazing * sparkle * 5.0 + vec3(0.6, 1.0, 1.0) * caustic * 0.35;
	ALPHA = clamp(0.45 + sqrt(t) * 0.5 + foam, 0.0, 0.96);
	vec3 na = texture(normal_a, wpos.xz * 0.06 + vec2(TIME * 0.02, TIME * 0.01)).rgb;
	vec3 nb = texture(normal_b, wpos.xz * 0.11 - vec2(TIME * 0.015, -TIME * 0.02)).rgb;
	NORMAL_MAP = normalize(mix(na, nb, 0.5));
	NORMAL_MAP_DEPTH = 0.6;
	ROUGHNESS = 0.04;
	SPECULAR = 0.6;
}
