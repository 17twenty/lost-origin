shader_type spatial;
// Forerunner-ish gunmetal panels: triplanar panel grid with grooves and subtle wear.

uniform vec3 base_color : source_color = vec3(0.30, 0.34, 0.40);
uniform vec3 groove_color : source_color = vec3(0.08, 0.10, 0.13);
uniform vec2 panel_size = vec2(2.0, 1.0);
uniform float groove = 0.035;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float panel(vec2 p) {
	vec2 g = abs(fract(p / panel_size) - 0.5) * panel_size;
	vec2 e = panel_size * 0.5 - g;
	return smoothstep(0.0, groove, min(e.x, e.y));
}

void fragment() {
	vec3 w = pow(abs(wnorm), vec3(6.0));
	w /= (w.x + w.y + w.z);
	float p = panel(wpos.zy) * w.x + panel(wpos.xz) * w.y + panel(wpos.xy) * w.z;
	float n = texture(noise_tex, wpos.xz * 0.07 + wpos.yy * 0.05).r;
	vec3 col = mix(groove_color, base_color * (0.85 + n * 0.3), p);
	ALBEDO = col;
	METALLIC = 0.75;
	ROUGHNESS = mix(0.6, 0.35, p * n);
}
