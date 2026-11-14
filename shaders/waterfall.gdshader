shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, unshaded;
// Falling water sheet: scrolling streaks, soft edges.

uniform vec3 color : source_color = vec3(0.72, 0.93, 1.0);
uniform float speed = 1.2;
uniform float energy = 1.2;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

void fragment() {
	vec2 uv = UV;
	float a = texture(noise_tex, vec2(uv.x * 1.5, uv.y * 0.35 - TIME * speed)).r;
	float b = texture(noise_tex, vec2(uv.x * 3.0 + 0.37, uv.y * 0.6 - TIME * speed * 1.7)).r;
	float s = a * 0.6 + b * 0.4;
	ALBEDO = mix(color * 0.75, vec3(1.0), smoothstep(0.45, 0.75, s)) * energy;
	float edge = smoothstep(0.0, 0.12, uv.x) * (1.0 - smoothstep(0.88, 1.0, uv.x));
	float ends = smoothstep(0.0, 0.05, uv.y) * (1.0 - smoothstep(0.92, 1.0, uv.y));
	ALPHA = clamp((0.4 + s * 0.6) * edge * ends, 0.0, 0.92);
}
