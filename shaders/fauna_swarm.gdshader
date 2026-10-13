shader_type spatial;
// Ambient wildlife moved entirely on the GPU (FaunaAmbient): mode 0 = a swarm
// over the jungle floor (butterflies by day, blinking fireflies by night),
// mode 1 = a flock of birds wheeling over the canopy. Per instance
// (INSTANCE_CUSTOM): x phase, y speed, z spread, w size.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float night = 0.0;
uniform float mode = 0.0;
uniform float radius = 4.0;
uniform float height = 1.0;
uniform float day_on = 1.0;
uniform float night_on = 1.0;

varying vec3 tint;
varying float glow;
varying float hidden;

vec3 wing_col(float h) {
	if (h < 0.25) return vec3(0.95, 0.5, 0.08);
	if (h < 0.5) return vec3(0.15, 0.5, 0.95);
	if (h < 0.75) return vec3(0.98, 0.88, 0.25);
	return vec3(0.9, 0.95, 0.9);
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float t = TIME * (0.25 + c.y) + c.x * 6.2831;
	bool swarm = mode < 0.5;
	bool fly = swarm && night > 0.5;
	vec3 off;
	float head;
	if (swarm) {
		off = vec3(sin(t * 0.7 + c.x * 5.0) * radius * c.z, height * (0.35 + c.x * 0.9) + sin(t * 1.3) * 0.4, cos(t * 0.53 + c.x * 3.0) * radius);
		head = t * 0.7;
	} else {
		off = vec3(cos(t) * radius * c.z, height + sin(t * 0.5 + c.x * 4.0) * 1.5, sin(t) * radius * c.z);
		head = -t;
	}
	float flap = sin(TIME * (swarm ? 16.0 : 8.0) + c.x * 30.0);
	vec3 v = VERTEX * c.w * (fly ? 0.35 : 1.0);
	v.y += abs(VERTEX.x) * c.w * flap * (swarm ? 1.4 : 0.6) * (fly ? 0.0 : 1.0);
	float ch = cos(head);
	float sh = sin(head);
	v = vec3(v.x * ch - v.z * sh, v.y, v.x * sh + v.z * ch);
	VERTEX = v + off;
	glow = 0.0;
	hidden = 0.0;
	if (swarm) {
		tint = wing_col(fract(c.x * 7.13));
		if (fly) {
			tint = vec3(0.75, 1.0, 0.35);
			glow = 0.5 + 0.5 * sin(TIME * 2.5 + c.x * 40.0);
			hidden = night_on < 0.5 ? 1.0 : 0.0;
		} else {
			hidden = day_on < 0.5 ? 1.0 : 0.0;
		}
	} else {
		tint = vec3(0.07, 0.06, 0.06);
	}
}

void fragment() {
	if (hidden > 0.5 || (glow > 0.0 && glow < 0.25)) {
		discard;
	}
	ALBEDO = tint * (1.0 + glow * 2.0);
}
