shader_type spatial;
// Hexagonal floor tiles with dark seams and occasional softly glowing cyan seams.

uniform vec3 tile_a : source_color = vec3(0.36, 0.40, 0.46);
uniform vec3 tile_b : source_color = vec3(0.26, 0.30, 0.36);
uniform vec3 seam_color : source_color = vec3(0.05, 0.06, 0.08);
uniform vec3 glow_color : source_color = vec3(0.2, 0.9, 1.0);
uniform float hex_size = 0.9;
uniform float glow_strength = 2.5;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Returns (distance to edge, cell id hash).
vec2 hex(vec2 p) {
	const vec2 s = vec2(1.0, 1.7320508);
	vec4 c = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h = vec4(p - c.xy * s, p - (c.zw + 0.5) * s);
	vec2 d = dot(h.xy, h.xy) < dot(h.zw, h.zw) ? h.xy : h.zw;
	vec2 id = dot(h.xy, h.xy) < dot(h.zw, h.zw) ? c.xy : c.zw + 0.5;
	vec2 a = abs(d);
	float edge = 0.5 - max(dot(a, s * 0.5), a.x);
	return vec2(edge, fract(sin(dot(id, vec2(12.9898, 78.233))) * 43758.5453));
}

void fragment() {
	vec2 h = hex(wpos.xz / hex_size);
	float seam = smoothstep(0.015, 0.04, h.x);
	vec3 tile = mix(tile_b, tile_a, h.y);
	ALBEDO = mix(seam_color, tile, seam);
	float glow = (1.0 - seam) * step(0.86, h.y) * (0.6 + 0.4 * sin(TIME * 1.5 + h.y * 30.0));
	EMISSION = glow_color * glow * glow_strength;
	METALLIC = 0.5;
	ROUGHNESS = mix(0.8, 0.3, seam);
}
