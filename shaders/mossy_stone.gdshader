shader_type spatial;
// Weathered ruin stone with moss on upward faces (triplanar, world space).

uniform vec3 stone_color : source_color = vec3(0.62, 0.60, 0.54);
uniform vec3 stone_dark : source_color = vec3(0.36, 0.36, 0.33);
uniform vec3 moss_color : source_color = vec3(0.24, 0.48, 0.14);
uniform float moss_amount : hint_range(0.0, 1.0) = 0.55;
uniform float scale = 0.35;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float tri(vec3 p, vec3 nrm, float s) {
	vec3 w = pow(abs(nrm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(noise_tex, p.yz * s).r * w.x + texture(noise_tex, p.xz * s).r * w.y + texture(noise_tex, p.xy * s).r * w.z;
}

void fragment() {
	float n = tri(wpos, wnorm, scale);
	float fine = tri(wpos, wnorm, scale * 6.0);
	vec3 col = mix(stone_dark, stone_color, smoothstep(0.25, 0.75, n * 0.6 + fine * 0.4));
	// Moss: up-facing surfaces, plus creeping streaks down the sides.
	float up = smoothstep(0.35, 0.85, wnorm.y);
	float streak = smoothstep(0.55, 0.75, tri(wpos * vec3(1.0, 0.25, 1.0), wnorm, scale * 2.0)) * 0.6;
	float moss = clamp((up + streak) * moss_amount * 1.6 - (1.0 - n) * 0.6, 0.0, 1.0);
	col = mix(col, moss_color * (0.7 + fine * 0.5), moss);
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.95, moss);
}
