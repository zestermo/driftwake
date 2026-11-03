// The Scouring's long-range bursts (ScouringFX): one MultiMesh of camera-facing cards, each a glow (a fireball's
// bloom, a broadside's muzzle flash, a shell in flight: added, through the smoke) or a smoke puff (blended), by
// INSTANCE_CUSTOM.x (0 glow, 1 smoke); .y a seed for the puff's ragged edge. The instance colour's alpha fades it.
// Premultiplied blending, so both kinds draw in one call. Not fogged: the glow has to read through the smoke.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/psx/psx_common.gdshaderinc"

uniform float bands = 4.0;

varying float kind;
varying float seed;

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
	vec3 origin = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 w = origin + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * s;
	POSITION = psx_snap(PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0), psx_snap_res);
}

void fragment() {
	// (the instance colours are sRGB, like the rest of the game's)
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	if (kind > 0.5) {
		float n = noise(q * 2.6 + seed * 17.0) * 0.6 + noise(q * 5.3 + seed * 5.0) * 0.4;
		float a = 1.0 - smoothstep(0.45, 0.95, r + (n - 0.5) * 0.55);
		a *= COLOR.a;
		a = floor(a * bands + 0.5) / bands;
		vec3 c = base * mix(0.75, 1.15, n);
		ALBEDO = c * a;
		ALPHA = a;
	} else {
		float core = 1.0 - smoothstep(0.0, 1.0, r);
		float a = pow(core, 1.6) * COLOR.a;
		a = floor(a * bands + 0.5) / bands;
		ALBEDO = mix(base, vec3(1.0, 0.92, 0.7), pow(core, 5.0)) * a * 1.6;
		ALPHA = 0.0;
	}
}
