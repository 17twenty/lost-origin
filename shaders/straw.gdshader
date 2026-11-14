shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Straw hair/beard cards: alpha-cut strand texture, wind/motion sway by COLOR.r.
uniform sampler2D straw_tex : source_color, filter_linear_mipmap;
uniform float alpha_cut = 0.4;
uniform float sway = 0.015;
uniform float weave_progress : hint_range(0.0, 1.0) = 1.0;
// Solid mode (round 3 "Spike" material): opaque tapered quills, UV.y = 0 root -> 1 tip,
// COLOR.g = per-quill tone. Fibre streaks run along each quill; tips are lighter.
uniform bool solid = false;
uniform vec3 spike_root : source_color = vec3(0.36, 0.27, 0.15);
uniform vec3 spike_tip : source_color = vec3(0.88, 0.76, 0.52);

void vertex() {
	VERTEX.x += sin(TIME * 2.2 + VERTEX.y * 30.0) * sway * COLOR.r;
	VERTEX.z += cos(TIME * 1.7 + VERTEX.x * 25.0) * sway * COLOR.r;
}

void fragment() {
	if (UV2.x > weave_progress) {
		discard;
	}
	if (solid) {
		float fib = 0.82 + 0.18 * sin(UV.x * TAU * 3.0 + COLOR.g * 40.0 + UV.y * 4.0);
		vec3 c = mix(spike_root, spike_tip, smoothstep(0.0, 1.0, UV.y)) * fib * (0.8 + 0.4 * COLOR.g);
		ALBEDO = c;
		BACKLIGHT = c * 0.7;
		RIM = 0.4;
		RIM_TINT = 0.8;
		EMISSION = c * 0.06;
		ROUGHNESS = 0.7;
		SPECULAR = 0.3;
	} else {
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
}
