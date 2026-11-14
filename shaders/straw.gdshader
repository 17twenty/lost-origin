shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Straw hair/beard cards: alpha-cut strand texture, wind/motion sway by COLOR.r.
uniform sampler2D straw_tex : source_color, filter_linear_mipmap;
uniform float alpha_cut = 0.4;
uniform float sway = 0.015;
uniform float weave_progress : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	VERTEX.x += sin(TIME * 2.2 + VERTEX.y * 30.0) * sway * COLOR.r;
	VERTEX.z += cos(TIME * 1.7 + VERTEX.x * 25.0) * sway * COLOR.r;
}

void fragment() {
	if (UV2.x > weave_progress) {
		discard;
	}
	vec4 t = texture(straw_tex, UV);
	if (t.a < alpha_cut) {
		discard;
	}
	ALBEDO = t.rgb * 1.15;
	BACKLIGHT = t.rgb * 0.9;
	RIM = 0.5;
	RIM_TINT = 0.8;
	EMISSION = t.rgb * 0.08;  // lift the self-shadowed inner cards so the mane never reads black
	ROUGHNESS = 0.85;
}
