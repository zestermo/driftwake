shader_type spatial;
// SkyBirds' MultiMesh of the birds the CPU flies: every bird is the same little mesh (sky_bird.gdshaderinc) whose
// wings hinge at the shoulders. Per instance (INSTANCE_CUSTOM): x the wing angle now (radians, up +), y folded
// (1 = wings tucked along the back), z the kind (0 gull, 1 dark far bird, 2-5 a parrot's colour, 6 a vulture).
render_mode cull_disabled, shadows_disabled, specular_disabled;

#include "res://shaders/sky_bird.gdshaderinc"

varying vec3 tint;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	VERTEX = bird_wings(VERTEX, c.x, c.y);
	tint = bird_tint(c.z, COLOR.rgb, COLOR.a);
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 1.0;
}
