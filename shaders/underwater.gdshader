shader_type spatial;
render_mode unshaded, cull_front;
// Inside of the "ocean" box seen through aquarium windows: depth gradient,
// animated caustics and slanting light shafts.

uniform vec3 deep_color : source_color = vec3(0.01, 0.10, 0.24);
uniform vec3 shallow_color : source_color = vec3(0.10, 0.55, 0.75);
uniform float top_y = 4.0;
uniform float bottom_y = -12.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float caustic(vec2 p) {
	float a = texture(noise_tex, p * 0.15 + vec2(TIME * 0.03, TIME * 0.02)).r;
	float b = texture(noise_tex, p * 0.21 - vec2(TIME * 0.025, -TIME * 0.035)).r;
	return pow(1.0 - abs(a - b), 8.0);
}

void fragment() {
	float t = clamp((wpos.y - bottom_y) / (top_y - bottom_y), 0.0, 1.0);
	vec3 col = mix(deep_color, shallow_color, t * t);
	col += vec3(0.4, 0.9, 1.0) * caustic(wpos.xz + wpos.y * 0.3) * (0.08 + t * 0.22);
	float shafts = texture(noise_tex, vec2(wpos.x * 0.05 + wpos.y * 0.03 + TIME * 0.01, 0.5)).r;
	col += vec3(0.3, 0.7, 0.9) * smoothstep(0.55, 0.8, shafts) * t * 0.35;
	ALBEDO = col;
}
