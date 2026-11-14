shader_type spatial;
render_mode cull_disabled;
// Kelp ribbons (MultiMesh): sway grows with height (UV.y), olive -> lime
// gradient, translucent backlight so it glows against the sea.

uniform vec3 base_color : source_color = vec3(0.12, 0.22, 0.06);
uniform vec3 tip_color : source_color = vec3(0.45, 0.68, 0.16);
uniform float sway = 0.45;

void vertex() {
	float ph = float(INSTANCE_ID) * 1.37;
	float k = pow(UV.y, 1.5);
	VERTEX.x += sin(TIME * 1.1 + ph + UV.y * 3.0) * sway * k;
	VERTEX.z += cos(TIME * 0.8 + ph * 1.3 + UV.y * 2.2) * sway * 0.6 * k;
}

void fragment() {
	float edge = abs(UV.x - 0.5) * 2.0;
	vec3 c = mix(base_color, tip_color, UV.y) * (1.0 - edge * 0.35);
	ALBEDO = c;
	BACKLIGHT = c * 0.6;
	ROUGHNESS = 0.6;
}
