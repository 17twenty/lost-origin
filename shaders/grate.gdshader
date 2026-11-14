shader_type spatial;
// Floor grate: dark metal grid bars over a dim glowing void (video control room).

uniform vec3 bar_color : source_color = vec3(0.42, 0.48, 0.56);
uniform vec3 void_color : source_color = vec3(0.02, 0.05, 0.09);
uniform vec3 glow_color : source_color = vec3(0.1, 0.55, 0.9);
uniform vec2 cells = vec2(14.0, 28.0);
uniform float bar = 0.18;

void fragment() {
	vec2 g = fract(UV * cells);
	float b = max(step(g.x, bar), step(g.y, bar));
	float frame = max(step(UV.x, 0.03) + step(0.97, UV.x), step(UV.y, 0.015) + step(0.985, UV.y));
	float m = max(b, frame);
	ALBEDO = mix(void_color, bar_color, m);
	EMISSION = glow_color * (1.0 - m) * 0.35;
	METALLIC = mix(0.0, 0.8, m);
	ROUGHNESS = mix(0.9, 0.35, m);
}
