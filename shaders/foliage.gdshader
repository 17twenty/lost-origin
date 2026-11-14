shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Leaf cards: alpha-scissor cluster texture, wind sway weighted by vertex colour R,
// soft backlighting so the canopy glows where light passes through.

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float alpha_cut = 0.45;
uniform float sway = 0.12;
uniform float sway_speed = 1.3;
// Safety net: weight also fades to 0 near the anchor (local y = 0), so a mesh
// that loses its sway-weight colour channel still can't slide at the base.
uniform float anchor_blend = 0.0;   // 0 = off; local units over which sway fades in
uniform bool hanging = false;      // true for strands hanging below their anchor

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = w.x * 0.6 + w.z * 0.4;
	float lock = anchor_blend > 0.0 ? smoothstep(0.0, anchor_blend, hanging ? -VERTEX.y : VERTEX.y) : 1.0;
	float sw = COLOR.r * lock;
	VERTEX.x += sin(TIME * sway_speed + ph) * sway * sw;
	VERTEX.z += cos(TIME * sway_speed * 0.8 + ph * 1.3) * sway * 0.6 * sw;
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
