shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Fake volumetric light shaft (open-ended cone): brightest along the view-facing
// core, fades toward the far end and the silhouette, drifting dust motes.
// Works on Compatibility/WebGL2 where real volumetric fog isn't available.

uniform vec3 color : source_color = vec3(1.0, 0.95, 0.8);
uniform float intensity = 0.35;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

void fragment() {
	float facing = pow(abs(dot(NORMAL, VIEW)), 2.0);
	float along = 1.0 - UV.y;          // 1 at the source, 0 at the far end
	float ends = smoothstep(0.0, 0.25, along) * smoothstep(1.0, 0.85, along);
	float dust = 0.75 + 0.5 * texture(noise_tex, vec2(UV.x * 3.0, UV.y * 2.0 - TIME * 0.03)).r;
	float a = intensity * facing * ends * dust;
	ALBEDO = color * a;
}
