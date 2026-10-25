// FarFigures (2026-10-25 GPU pass): townsfolk and villagers past FarFigures.ON_R drawn as one MultiMesh of a simple
// figure (FarFigures.mesh: facing -z, 1.72 m tall at scale 1), every one walked, sat and moved here. The CPU writes a
// figure's row only when its rig would have posed (every few frames that far off); between, it slides on along its
// velocity (for up to SLIDE s) with its legs and arms swinging in step with the ground it covers.
// Per instance: the transform = the body's (its place, its heading, its height); COLOR = four sRGB colours packed
// 8 bits a channel in a float each (top, legs, skin, hair); INSTANCE_CUSTOM x = the clock (`now`) it was written at,
// y = its speed along its heading (m/s), z = the ground it had covered then (m, wrapped), w = 0 standing or
// 1 + the seat's height (m) sitting. A free slot is scaled to nothing. UV.x of the mesh = the part
// (0 torso, 1 thigh, 2 shin, 3 sleeve, 4 hand, 5 head, 6 hair, 7 shoe, 8 pelvis). Past `far_r` it isn't drawn (the
// bodies' own visibility range).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

#include "res://shaders/psx/psx_common.gdshaderinc"

uniform float now = 0.0;
uniform float far_r = 220.0;
const float SLIDE = 1.0;
// a stride's cycle (two steps) per this many m covered
const float GAIT = 1.25;
const float HIP_Y = 0.86;
const float KNEE_Y = 0.44;
const float SHOULDER_Y = 1.42;

varying vec3 col;

vec3 unpack_srgb(float f) {
	uint v = uint(f + 0.5);
	vec3 c = vec3(float((v >> 16u) & 255u), float((v >> 8u) & 255u), float(v & 255u)) / 255.0;
	return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

// v turned by a about the x axis through the point (y, z) = p (+ swings forward: the rig's x+ for limbs)
vec3 swing(vec3 v, vec2 p, float a) {
	vec2 q = v.yz - p;
	return vec3(v.x, p.x + q.x * cos(a) - q.y * sin(a), p.y + q.x * sin(a) + q.y * cos(a));
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float part = UV.x;
	float side = sign(VERTEX.x);
	float dt = clamp(now - c.x, 0.0, SLIDE);
	float speed = c.y;
	float walk = clamp(speed / 1.2, 0.0, 1.0) * step(now - c.x, SLIDE);
	float s = sin(6.2831853 * (c.z + speed * dt) / GAIT) * walk;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	if (c.w > 0.5) {
		// sitting: thighs forward, shins down from the knee, the hips down onto the seat
		if ((part > 0.5 && part < 2.5) || (part > 6.5 && part < 7.5)) {
			if (part > 1.5) {
				v = swing(v, vec2(KNEE_Y, 0.0), -1.5708);
				n = swing(n, vec2(0.0), -1.5708);
			}
			v = swing(v, vec2(HIP_Y, 0.0), 1.5708);
			n = swing(n, vec2(0.0), 1.5708);
		}
		v.y += (c.w - 1.0) - HIP_Y + 0.05;
	} else {
		// walking: a leg forward as the other goes back, the knee bending on the way through, the arms against them
		if ((part > 0.5 && part < 2.5) || (part > 6.5 && part < 7.5)) {
			float a = s * side * 0.45;
			if (part > 1.5) {
				float knee = -max(0.0, -a) * 0.8 - walk * 0.1;
				v = swing(v, vec2(KNEE_Y, 0.0), knee);
				n = swing(n, vec2(0.0), knee);
			}
			v = swing(v, vec2(HIP_Y, 0.0), a);
			n = swing(n, vec2(0.0), a);
		} else if (part > 2.5 && part < 4.5) {
			float a = -s * side * 0.4;
			v = swing(v, vec2(SHOULDER_Y, 0.0), a);
			n = swing(n, vec2(0.0), a);
		}
		v.y += abs(s) * 0.04;
	}
	// on along its heading since the row was written (the instance's own scale: speed is in world m)
	v.z -= speed * dt / max(length(MODEL_MATRIX[0].xyz), 0.001);
	vec3 at = MODEL_MATRIX[3].xyz;
	VERTEX = v * step(distance(at, CAMERA_POSITION_WORLD), far_r);
	NORMAL = n;
	vec4 pc = COLOR;
	if (part < 0.5 || (part > 2.5 && part < 3.5)) {
		col = unpack_srgb(pc.x);
	} else if (part < 2.5 || part > 7.5) {
		col = unpack_srgb(pc.y);
	} else if (part > 6.5) {
		col = vec3(0.012, 0.01, 0.009);
	} else if (part > 5.5) {
		col = unpack_srgb(pc.w);
	} else {
		col = unpack_srgb(pc.z);
	}
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (!IN_SHADOW_PASS) {
		clip = psx_snap(clip, psx_snap_res);
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
