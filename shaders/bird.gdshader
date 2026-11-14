shader_type spatial;
render_mode cull_disabled;
// Gull silhouette (MultiMesh): wings flap by INSTANCE_ID phase; tips move most.

uniform vec3 color : source_color = vec3(0.95, 0.96, 1.0);

void vertex() {
	float ph = float(INSTANCE_ID) * 1.9;
	float flap = sin(TIME * 6.0 + ph) * (0.5 + 0.5 * sin(TIME * 0.7 + ph));  // flap, then glide
	VERTEX.y += flap * 0.35 * abs(VERTEX.x);
}

void fragment() {
	ALBEDO = color;
	ROUGHNESS = 0.9;
}
