// The Scouring's long-range bursts (ScouringFX): MultiMesh cards, by INSTANCE_CUSTOM.x: 0 a glow (a fireball's bloom,
// a broadside's flash, a shell in flight: added, through the smoke), 1 a smoke puff (blended, lit from below by the
// fires at night: `under`), 2 a shell's shadow on the ground (flat, darkening, an ember rim flickering; the instance's
// own basis lays it down). .y a seed.
// `driven`: the cards move themselves from `now` (ScouringFX's game clock): written once when spawned, the instance
// basis carrying the numbers (custom data is half floats: a birth time would lose its seconds): column 0 the start
// size, the end size and the rise (m/s), column 1 the birth and the life; dead ones fold away.
// Otherwise (the shells in flight and their shadows) the CPU writes them each frame, the colour's alpha fading them.
// Premultiplied blending, so every kind draws in one call. Not fogged: the glow has to read through the smoke.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/psx/psx_common.gdshaderinc"

uniform float bands = 4.0;
uniform bool driven = false;
uniform float now = 0.0;
uniform float under = 0.0;
uniform vec4 under_color : source_color = vec4(0.46, 0.2, 0.08, 1.0);

varying float kind;
varying float seed;
varying float fade;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	kind = INSTANCE_CUSTOM.x;
	seed = INSTANCE_CUSTOM.y;
	fade = 1.0;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	if (driven) {
		vec3 sz = MODEL_MATRIX[0].xyz;
		float age = now - MODEL_MATRIX[1].x;
		float u = age / max(MODEL_MATRIX[1].y, 0.01);
		s = (u < 0.0 || u > 1.0) ? 0.0 : mix(sz.x, sz.y, sqrt(u));
		u = clamp(u, 0.0, 1.0);
		origin.y += sz.z * max(age, 0.0);
		fade = kind > 0.5 ? (1.0 - u * u) * smoothstep(0.0, 0.08, u) : 1.0 - u;
	}
	vec3 w;
	if (kind > 1.5) {
		w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	} else {
		w = origin + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * s;
	}
	POSITION = psx_snap(PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0), psx_snap_res);
}

void fragment() {
	// (the instance colours are sRGB, like the rest of the game's)
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	if (kind > 1.5) {
		float flick = 0.6 + 0.4 * step(0.5, hash(vec2(floor(TIME * 14.0), seed)));
		float a = (1.0 - smoothstep(0.55, 1.0, r)) * COLOR.a;
		float rim = smoothstep(0.7, 0.88, r) * (1.0 - smoothstep(0.88, 1.0, r)) * flick;
		a = floor(a * bands + 0.5) / bands;
		ALBEDO = vec3(1.0, 0.35, 0.08) * rim * COLOR.a * 0.7;
		ALPHA = a * 0.85;
	} else if (kind > 0.5) {
		float n = noise(q * 2.6 + seed * 17.0) * 0.6 + noise(q * 5.3 + seed * 5.0) * 0.4;
		float a = 1.0 - smoothstep(0.45, 0.95, r + (n - 0.5) * 0.55);
		a *= COLOR.a * fade;
		a = floor(a * bands + 0.5) / bands;
		vec3 c = base * mix(0.75, 1.15, n);
		c = mix(c, pow(under_color.rgb, vec3(2.2)), under * 0.6 * smoothstep(0.35, 1.0, UV.y) * mix(0.4, 1.0, n));
		ALBEDO = c * a;
		ALPHA = a;
	} else {
		float core = 1.0 - smoothstep(0.0, 1.0, r);
		float a = pow(core, 1.6) * COLOR.a * fade;
		a = floor(a * bands + 0.5) / bands;
		ALBEDO = mix(base, vec3(1.0, 0.92, 0.7), pow(core, 5.0)) * a * 1.6;
		ALPHA = 0.0;
	}
}
