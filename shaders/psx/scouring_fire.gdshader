// The Scouring's blazes (ScouringFX): tall camera-facing cards, upright, one MultiMesh for every fire. A wide burning
// base, tongues of flame licking up and tearing off, a white-yellow heart, orange to deep red at the edges, all moving
// on the GPU. The instance basis carries the numbers (custom data is half floats): column 0 the card's height, its
// width (m) and a seed, column 1 .x when it caught (`now`'s clock): it grows to full over the first seconds. Not
// fogged: it has to burn through the smoke.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/psx/psx_common.gdshaderinc"

uniform float now = 0.0;
uniform float bands = 5.0;

varying float seed;
varying float grow;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 3.7) * 0.3 + noise(p * 4.3 + 9.1) * 0.15;
}

void vertex() {
	seed = MODEL_MATRIX[0].z;
	grow = smoothstep(0.0, 3.0, now - MODEL_MATRIX[1].x);
	float h = MODEL_MATRIX[0].x * mix(0.25, 1.0, grow);
	float wd = MODEL_MATRIX[0].y * mix(0.5, 1.0, grow);
	vec3 cam_r = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 origin = MODEL_MATRIX[3].xyz;
	// (the quad is 1 x 1 round its middle: its foot at the origin)
	vec3 w = origin + cam_r * VERTEX.x * wd + vec3(0.0, (VERTEX.y + 0.5) * h, 0.0);
	POSITION = psx_snap(PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0), psx_snap_res);
}

void fragment() {
	float t = TIME + seed * 31.0;
	// x: -1..1 across, y: 0 at the foot .. 1 at the top
	vec2 q = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float n = fbm(vec2(q.x * 3.0 + seed * 7.0, q.y * 2.2 - t * 1.6));
	float n2 = fbm(vec2(q.x * 6.5 + seed * 3.0, q.y * 4.0 - t * 2.7));
	// the body: wide at the foot, drawn up into licking tongues
	float width = mix(0.95, 0.08, pow(q.y, 0.8)) + (n - 0.5) * 0.7 * (0.3 + q.y);
	float edge = width - abs(q.x + (n2 - 0.5) * 0.25 * q.y);
	float shape = smoothstep(0.0, 0.06, edge);
	// tongues tearing off higher up
	float tongue = smoothstep(0.66, 0.86, n2) * smoothstep(0.35, 0.7, q.y) * (1.0 - smoothstep(0.3, 0.7, abs(q.x)));
	shape = max(shape, tongue);
	shape *= 1.0 - smoothstep(0.82, 1.0, q.y + (n2 - 0.5) * 0.3);
	shape *= smoothstep(0.0, 0.05, q.y);
	// heat: the heart low and in the middle
	float heat = clamp(edge * 2.2 + (1.0 - q.y) * 0.5 - 0.35 + (n - 0.5) * 0.4, 0.0, 1.0);
	heat = floor(heat * bands) / bands;
	vec3 c = mix(vec3(0.55, 0.06, 0.02), vec3(1.0, 0.42, 0.06), smoothstep(0.0, 0.45, heat));
	c = mix(c, vec3(1.0, 0.9, 0.55), smoothstep(0.5, 0.9, heat));
	float a = shape * mix(0.75, 1.0, heat) * grow;
	a = step(0.5, a + (hash(floor(UV * 64.0) + floor(t * 10.0)) - 0.5) * 0.3);
	if (a < 0.5) {
		discard;
	}
	ALBEDO = c * 1.6;
}
