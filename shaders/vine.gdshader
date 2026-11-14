shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Hanging vines / moss strands: pendulum sway weighted by vertex colour R
// (0 at the attachment, 1 at the tip), optional alpha-cut leaf texture.

uniform sampler2D tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec3 tint : source_color = vec3(1.0);
uniform float alpha_cut = 0.0;
uniform float sway = 0.16;

void vertex() {
	float ph = float(INSTANCE_ID) * 2.13;
	float w = COLOR.r * COLOR.r;
	VERTEX.x += sin(TIME * 1.2 + ph) * sway * w;
	VERTEX.z += cos(TIME * 0.9 + ph * 1.7) * sway * 0.6 * w;
}

void fragment() {
	vec4 t = texture(tex, UV);
	if (t.a < alpha_cut) {
		discard;
	}
	ALBEDO = t.rgb * tint;
	BACKLIGHT = ALBEDO * 0.4;
	ROUGHNESS = 0.8;
}
