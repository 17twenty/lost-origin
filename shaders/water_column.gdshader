shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, unshaded;
// Glowing glass column of water with rising bubble streaks.

uniform vec3 color : source_color = vec3(0.1, 0.7, 0.95);
uniform float speed = 0.35;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

void fragment() {
	vec2 uv = UV;
	float bubbles = texture(noise_tex, vec2(uv.x * 4.0, uv.y * 1.5 + TIME * speed)).r;
	float fine = texture(noise_tex, vec2(uv.x * 9.0 + 0.3, uv.y * 4.0 + TIME * speed * 2.2)).r;
	float b = smoothstep(0.68, 0.8, bubbles) + smoothstep(0.75, 0.85, fine) * 0.6;
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float base_fade = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.75, UV.y);
	ALBEDO = (color * (0.6 + fres * 1.1) + vec3(0.8, 1.0, 1.0) * b) * mix(0.55, 1.0, base_fade);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ALBEDO *= 0.6;   // LDR path clips the column to white otherwise
#endif
	ALPHA = clamp(0.14 + fres * 0.5 + b * 0.35, 0.0, 0.9);
}
