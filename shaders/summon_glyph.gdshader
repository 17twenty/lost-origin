shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Summoning circle glyphs: concentric rings + rotating rune ticks; `power` is
// driven by the summoning intro (flares while the Wicker Man weaves in).

uniform vec3 color : source_color = vec3(1.0, 0.62, 0.22);
uniform float power = 0.6;

float hash(float n) { return fract(sin(n * 17.31) * 4375.85); }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float ring = smoothstep(0.02, 0.0, abs(r - 0.92)) + smoothstep(0.015, 0.0, abs(r - 0.78)) + smoothstep(0.01, 0.0, abs(r - 0.42));
	// Rune band between the outer rings, slowly rotating.
	float seg = floor((a + TIME * 0.15) / (TAU / 36.0));
	float rune = step(0.45, hash(seg)) * step(0.81, r) * step(r, 0.89);
	float sub = fract((a + TIME * 0.15) / (TAU / 36.0));
	rune *= step(0.2, sub) * step(sub, 0.8);
	// Inner sigil: six spokes.
	float spokes = smoothstep(0.03, 0.0, abs(sin(a * 3.0 - TIME * 0.3)) * r) * step(0.42, r) * step(r, 0.78) * 0.6;
	float v = (ring + rune + spokes) * step(r, 1.0);
	float pulse = 0.8 + 0.2 * sin(TIME * 2.0);
	ALBEDO = color * v * power * pulse * 2.0;
}
