shader_type spatial;
// SkyBirds' MultiMesh: every bird is the same little mesh (span along x,
// facing -z) whose wings hinge at the shoulders. Per instance (INSTANCE_CUSTOM):
// x the wing angle now (radians, up +), y folded (1 = wings tucked along the
// back), z the kind (0 gull, 1 dark far bird, 2+ a parrot's colour).
// Vertex colour: the gull's plumage; alpha marks body 1, inner wing 0.6, tip 0.3.
render_mode cull_disabled, shadows_disabled, specular_disabled;

const float SHOULDER = 0.07;

varying vec3 tint;

vec3 parrot(float k, float part) {
	vec3 c = vec3(0.86, 0.14, 0.1);
	if (k > 2.5) c = vec3(0.12, 0.38, 0.9);
	if (k > 3.5) c = vec3(0.95, 0.78, 0.12);
	if (k > 4.5) c = vec3(0.16, 0.66, 0.24);
	return part < 0.45 ? c * 0.35 + vec3(0.05, 0.1, 0.4) * 0.5 : (part < 0.8 ? c * 0.8 : c);
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	vec3 v = VERTEX;
	float d = abs(v.x) - SHOULDER;
	if (d > 0.0) {
		float s = sign(v.x);
		d *= 1.0 - 0.72 * c.y;
		v.x = s * (SHOULDER + d * cos(c.x));
		v.y += d * sin(c.x);
		v.z += c.y * d * 0.45;
	}
	VERTEX = v;
	float part = COLOR.a;
	if (c.z < 0.5) {
		tint = COLOR.rgb;
	} else if (c.z < 1.5) {
		tint = vec3(0.07, 0.065, 0.06);
	} else {
		tint = parrot(c.z, part);
	}
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 1.0;
}
