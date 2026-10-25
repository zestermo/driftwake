// The high flocks over an island (SkyBirds, 2026-10-25 GPU pass): a dark flock wheeling in a loose clump or flying
// round in a V, or vultures circling on a thermal, all flown here. Each bird's path is a function of the clock
// (SkyBirds._target, the same sums), so the CPU only writes a bird's row in `birds` when it joins or leaves the
// flocks and sets `now` (SkyBirds' own clock) once a frame. Its heading, bank and pitch come from the path a moment
// either side; the wings beat or glide by the same rule SkyBirds._wings uses. Past `draw_r` from the camera a bird
// isn't drawn. The instance transforms are identity: everything is placed in world space here.
// `birds` (RGBA float, a row per instance): [centre x, height, centre z, mode 0 wheel / 1 vee],
// [angle at clock 0 (wheel: + its own offset), angular speed, radius (vee: the lead's), seed],
// [vee: rank back (m), rank aside (m), height offset; kind], [size, wingbeat rate, glide above, glide rate (0 never)].
shader_type spatial;
render_mode cull_disabled, shadows_disabled, specular_disabled;

#include "res://shaders/sky_bird.gdshaderinc"

uniform sampler2D birds : filter_nearest, repeat_disable;
uniform float now = 0.0;
uniform float draw_r = 480.0;

varying vec3 tint;

vec3 path(vec4 d0, vec4 d1, vec4 d2, float t) {
	float s = d1.w;
	float a = d1.x + d1.y * t;
	if (d0.w < 0.5) {
		float r = d1.z + sin(t * 0.37 + s) * 5.0;
		vec3 c = vec3(d0.x + sin(t * 0.05 + s * 0.01) * 18.0, 0.0, d0.z + cos(t * 0.043) * 18.0);
		return c + vec3(cos(a) * r, d0.y + sin(t * 0.6 + s) * 2.5, sin(a) * r);
	}
	vec3 lead = vec3(d0.x + cos(a) * d1.z, d0.y, d0.z + sin(a) * d1.z);
	vec3 dir = vec3(-sin(a), 0.0, cos(a)) * sign(d1.y);
	vec3 side = cross(dir, vec3(0.0, 1.0, 0.0));
	return lead - dir * d2.x + side * d2.y + vec3(0.0, sin(t * 1.3 + s) * 0.3 + d2.z, 0.0);
}

float wrap_pi(float a) {
	return a - 6.2831853 * floor((a + 3.14159265) / 6.2831853);
}

void vertex() {
	int id = INSTANCE_ID;
	vec4 d0 = texelFetch(birds, ivec2(0, id), 0);
	vec4 d1 = texelFetch(birds, ivec2(1, id), 0);
	vec4 d2 = texelFetch(birds, ivec2(2, id), 0);
	vec4 d3 = texelFetch(birds, ivec2(3, id), 0);
	const float H = 0.25;
	vec3 p = path(d0, d1, d2, now);
	vec3 pa = path(d0, d1, d2, now + H);
	vec3 pb = path(d0, d1, d2, now - H);
	vec3 v = (pa - pb) / (2.0 * H);
	vec3 va = pa - p;
	vec3 vb = p - pb;
	// heading along the path; banked into the turn (SkyBirds._steer: -turn * 6, turn = the heading's lag); pitched with the climb
	float yaw = atan(-v.x, -v.z);
	float rate = wrap_pi(atan(-va.x, -va.z) - atan(-vb.x, -vb.z)) / H;
	float bank = clamp(-rate, -0.9, 0.9);
	float pitch = clamp(v.y * 0.08, -0.5, 0.5);
	// Basis.from_euler(pitch, yaw, bank) (YXZ): Ry * Rx * Rz
	float cy = cos(yaw), sy = sin(yaw), cx = cos(pitch), sx = sin(pitch), cz = cos(bank), sz = sin(bank);
	mat3 ry = mat3(vec3(cy, 0.0, -sy), vec3(0.0, 1.0, 0.0), vec3(sy, 0.0, cy));
	mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cx, sx), vec3(0.0, -sx, cx));
	mat3 rz = mat3(vec3(cz, sz, 0.0), vec3(-sz, cz, 0.0), vec3(0.0, 0.0, 1.0));
	mat3 b = ry * rx * rz;
	// the wings (SkyBirds._wings): beating harder climbing, gliding now and then
	float effort = clamp(0.2 + v.y * 0.3, 0.0, 1.0);
	float flap = now * d3.y + d1.w * 7.0;
	float beat = sin(flap) * (0.55 + 0.25 * effort) + 0.1;
	float glide = d3.w > 0.0 ? smoothstep(d3.z - 0.08, d3.z + 0.08, sin(now * d3.w + d1.w)) * (1.0 - smoothstep(0.55, 0.65, effort)) : 0.0;
	float wing = mix(beat, 0.14 + 0.04 * sin(flap * 0.2), glide);
	float size = d3.x * step(distance(p, CAMERA_POSITION_WORLD), draw_r);
	vec3 world = p + b * (bird_wings(VERTEX, wing, 0.0) * size);
	mat4 inv = inverse(MODEL_MATRIX);
	VERTEX = (inv * vec4(world, 1.0)).xyz;
	NORMAL = normalize(mat3(inv) * (b * NORMAL));
	tint = bird_tint(d2.w, COLOR.rgb, COLOR.a);
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 1.0;
}
