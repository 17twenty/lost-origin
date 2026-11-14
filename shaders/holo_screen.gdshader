shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;
// Console / holo display: scanlines, scrolling glyph bars, flicker.

uniform vec3 color : source_color = vec3(0.25, 0.95, 1.0);
uniform float intensity = 1.6;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5); }

void fragment() {
	vec2 uv = UV;
	float scan = 0.75 + 0.25 * sin(uv.y * 220.0 + TIME * 6.0);
	vec2 cell = floor(vec2(uv.x * 14.0, uv.y * 18.0 - TIME * 1.5 + seed * 7.0));
	float glyph = step(0.55, hash(cell + seed)) * step(0.15, fract(uv.x * 14.0)) * step(0.25, fract(uv.y * 18.0 - TIME * 1.5));
	float frame = step(uv.x, 0.03) + step(0.97, uv.x) + step(uv.y, 0.04) + step(0.96, uv.y);
	float v = (glyph * 0.7 + frame + 0.12) * scan;
	v *= 0.92 + 0.08 * sin(TIME * 23.0 + seed);
	ALBEDO = color * v * intensity;
}
