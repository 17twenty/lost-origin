shader_type spatial;
// Island terrain: sand / wet sand / grass / rock blended by height, region and slope.

uniform vec3 sand_color : source_color = vec3(0.95, 0.88, 0.68);
uniform vec3 wet_sand_color : source_color = vec3(0.70, 0.62, 0.45);
uniform vec3 grass_color : source_color = vec3(0.30, 0.60, 0.16);
uniform vec3 grass_dark : source_color = vec3(0.14, 0.40, 0.10);
uniform vec3 rock_color : source_color = vec3(0.50, 0.47, 0.42);
uniform vec3 rock_dark : source_color = vec3(0.30, 0.29, 0.27);
uniform float water_level = -0.35;
uniform float plateau_z = -26.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n = texture(noise_tex, wpos.xz * 0.04).r;
	float n2 = texture(noise_tex, wpos.xz * 0.37).r;
	vec3 sand = mix(sand_color, sand_color * 0.9, n2);
	float wet = 1.0 - smoothstep(water_level + 0.05, water_level + 0.5, wpos.y + (n2 - 0.5) * 0.2);
	vec3 col = mix(sand, wet_sand_color, wet);
	// Grass: high ground anywhere, or the jungle plateau north of the chasm.
	float plateau = 1.0 - smoothstep(plateau_z - 2.0, plateau_z + 2.0, wpos.z + (n - 0.5) * 6.0);
	float high = smoothstep(1.2, 2.4, wpos.y + (n - 0.5) * 2.0);
	float grass = max(high, plateau * step(-2.0, wpos.y));
	col = mix(col, mix(grass_dark, grass_color, n * 0.7 + n2 * 0.3), grass);
	// Rock on steep slopes, triplanar so cliff faces don't stretch.
	vec3 bw = pow(abs(wnorm), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	float rn = texture(noise_tex, wpos.zy * 0.18).r * bw.x + texture(noise_tex, wpos.xz * 0.18).r * bw.y + texture(noise_tex, wpos.xy * 0.18).r * bw.z;
	float rf = texture(noise_tex, wpos.zy * 0.9).r * bw.x + texture(noise_tex, wpos.xz * 0.9).r * bw.y + texture(noise_tex, wpos.xy * 0.9).r * bw.z;
	float steep = 1.0 - smoothstep(0.62, 0.8, wnorm.y + (n2 - 0.5) * 0.1);
	vec3 rock = mix(rock_dark, rock_color, smoothstep(0.3, 0.7, rn * 0.65 + rf * 0.35));
	// Moss ledges on rock.
	rock = mix(rock, grass_dark, smoothstep(0.55, 0.8, rn) * smoothstep(0.3, 0.6, wnorm.y));
	col = mix(col, rock, steep);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.45, wet);
}
