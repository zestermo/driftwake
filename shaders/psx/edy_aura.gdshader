// Edy aura (EdyAura): an additive shell over a body part (a copy of its mesh pushed out along the normals), bright at
// the silhouette and licking upward in rising tongues. `look` picks the type's shape:
//   0 haze (Still: soft, slow, wide)   1 flame (Ember: ragged tongues, fast)   2 shimmer (Crown: a bright rim, sparkles)
//   3 lightning (Storm: thin crawling veins over the body)   4 swirl (Tide: bands turning round the body)
// `strength` fades it in and out (EdyAura drives it), `grow` is how far the shell stands off the skin.
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

#include "res://shaders/psx/psx_common.gdshaderinc"

uniform vec4 color : source_color = vec4(0.42, 0.66, 1.0, 1.0);
uniform int look = 0;
uniform float strength = 1.0;
uniform float grow = 0.035;
uniform float bands = 5.0;  // PSX-style banding

varying vec3 wpos;
varying vec3 wnrm;

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
	float t = TIME;
	vec3 n = normalize(NORMAL);
	// the shell breathes, and the flame shapes reach further where their tongues rise
	float lick = 0.0;
	if (look == 1) {
		lick = fbm(vec2(VERTEX.x * 6.0 + VERTEX.z * 4.0, VERTEX.y * 3.0 - t * 3.0)) * 0.05;
	} else if (look == 0) {
		lick = fbm(vec2(VERTEX.x * 3.0, VERTEX.y * 2.0 - t * 0.8)) * 0.035;
	}
	VERTEX += n * (grow + lick) * strength;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	clip = psx_snap(clip, psx_snap_res);
	POSITION = clip;
}

void fragment() {
	float t = TIME;
	vec3 vdir = normalize(CAMERA_POSITION_WORLD - wpos);
	float rim = 1.0 - abs(dot(normalize(wnrm), vdir));
	// a coordinate round the body and up it, for the rising patterns
	vec2 uv = vec2(atan(wnrm.z, wnrm.x) * 1.2 + wpos.x * 0.6, wpos.y * 2.0);
	float a = 0.0;
	vec3 col = color.rgb;
	if (look == 0) {
		float n = fbm(uv * vec2(1.5, 1.0) - vec2(0.0, t * 0.7));
		a = smoothstep(0.25, 0.95, rim) * (0.45 + 0.55 * n);
		col = mix(col, vec3(1.0), 0.15);
	} else if (look == 1) {
		float n = fbm(uv * vec2(2.5, 1.6) - vec2(0.0, t * 2.6));
		a = smoothstep(0.15, 0.9, rim) * smoothstep(0.3, 0.75, n) * 1.4;
		col = mix(col, vec3(1.0, 0.9, 0.55), smoothstep(0.6, 0.95, n) * 0.6);
	} else if (look == 2) {
		float sp = step(0.94, hash(floor(uv * 14.0 + vec2(0.0, floor(t * 6.0)))));
		a = pow(rim, 1.6) * 1.2 + sp * 0.8;
		col = mix(col, vec3(1.0, 0.97, 0.8), 0.35 + sp * 0.5);
	} else if (look == 3) {
		// veins: thin lines where a moving noise crosses its middle, flickering
		float n = fbm(uv * vec2(3.0, 2.0) + vec2(t * 0.9, -t * 1.7));
		float vein = 1.0 - smoothstep(0.0, 0.045, abs(n - 0.5));
		float flick = step(0.35, hash(vec2(floor(t * 14.0), 0.0)));
		a = vein * (0.6 + 0.4 * flick) * 1.6 + pow(rim, 3.0) * 0.35;
		col = mix(col, vec3(1.0), vein * 0.5);
	} else {
		float band = sin(atan(wnrm.z, wnrm.x) * 3.0 + wpos.y * 5.0 - t * 4.0) * 0.5 + 0.5;
		a = smoothstep(0.2, 0.9, rim) * (0.3 + 0.7 * smoothstep(0.55, 0.9, band));
		col = mix(col, vec3(0.85, 1.0, 1.0), 0.2);
	}
	a = clamp(a * strength, 0.0, 1.5);
	a = floor(a * bands + 0.5) / bands;
	ALBEDO = col * a;
}
