shader_type spatial;
render_mode cull_disabled;
// Fish (MultiMesh): body colour from INSTANCE_CUSTOM.rgb x vertex colour
// (lighter belly / stripes), tail wiggle phased by INSTANCE_CUSTOM.a.

uniform float wiggle = 0.05;
uniform float speed = 11.0;
varying vec3 col;

void vertex() {
	float tail = clamp(-VERTEX.z * 5.0, 0.0, 1.0);
	VERTEX.x += sin(TIME * speed + INSTANCE_CUSTOM.a * 40.0 + VERTEX.z * 14.0) * wiggle * (0.25 + tail);
	col = INSTANCE_CUSTOM.rgb * COLOR.rgb;
}

void fragment() {
	ALBEDO = col;
	METALLIC = 0.35;
	ROUGHNESS = 0.35;
	EMISSION = col * 0.15;
}
