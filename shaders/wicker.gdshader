shader_type spatial;
// Procedural rattan weave for the Wicker Man. UV is in metres (U around the
// limb, V along it) so strands follow the body. Herringbone twill with strand
// albedo variation, dark gaps, a weave-derived normal and a slight sheen.
// weave_progress + UV2.x (0 feet -> 1 crown) drive the weave-in dissolve.

uniform vec3 strand_light : source_color = vec3(0.74, 0.56, 0.32);
uniform vec3 strand_dark : source_color = vec3(0.42, 0.29, 0.15);
uniform vec3 gap_color : source_color = vec3(0.09, 0.06, 0.03);
uniform float density = 42.0;          // strands per metre
uniform float herring = 6.0;           // columns per chevron arm
uniform float weave_progress : hint_range(0.0, 1.0) = 1.0;
uniform vec3 edge_color : source_color = vec3(1.0, 0.62, 0.2);
uniform float edge_width = 0.04;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	float order = UV2.x;
	if (order > weave_progress) {
		discard;
	}
	vec2 p = UV * density;
	float colm = floor(p.x);
	float row = floor(p.y);
	float dir = mod(floor(colm / herring), 2.0) * 2.0 - 1.0;   // chevron flip
	float twill = mod(row + dir * colm, 4.0);
	bool along = twill < 2.0;                                   // strand runs along V (else along U)
	float across = along ? fract(p.x) : fract(p.y);
	float run = along ? fract(p.y) : fract(p.x);
	float profile = sin(across * PI);                           // rounded strand
	float id = along ? colm + floor((p.y + 2.0 * dir * colm) * 0.25) * 17.0 : row * 13.0 + floor(p.x * 0.25);
	float tone = hash(vec2(id, along ? 1.0 : 2.0));
	vec3 strand = mix(strand_dark, strand_light, 0.35 + 0.65 * tone);
	strand *= 0.85 + 0.15 * sin(run * PI);                      // dips where it goes under
	float gap = smoothstep(0.0, 0.22, profile);
	vec3 col = mix(gap_color, strand, gap);
	// Weave normal: tilt across the strand.
	float slope = cos(across * PI) * 0.6;
	vec3 n = along ? vec3(slope, 0.0, 1.0) : vec3(0.0, slope, 1.0);
	NORMAL_MAP = normalize(n) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.55, profile);
	SPECULAR = 0.35;
	AO = mix(0.4, 1.0, gap);
	AO_LIGHT_AFFECT = 0.5;
	float edge = 1.0 - smoothstep(0.0, edge_width, weave_progress - order);
	EMISSION = edge_color * edge * 4.0 * step(weave_progress, 0.999);
}
