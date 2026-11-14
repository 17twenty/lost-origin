shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Leaf cards: alpha-scissor cluster texture, wind sway weighted by vertex colour R,
// soft backlighting so the canopy glows where light passes through.

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float alpha_cut = 0.45;
uniform float sway = 0.12;
uniform float sway_speed = 1.3;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = w.x * 0.6 + w.z * 0.4;
	VERTEX.x += sin(TIME * sway_speed + ph) * sway * COLOR.r;
	VERTEX.z += cos(TIME * sway_speed * 0.8 + ph * 1.3) * sway * 0.6 * COLOR.r;
}

void fragment() {
	vec4 t = texture(leaf_tex, UV);
	if (t.a < alpha_cut) {
		discard;
	}
	ALBEDO = t.rgb * tint;
	BACKLIGHT = t.rgb * 0.45;
	ROUGHNESS = 0.7;
}
