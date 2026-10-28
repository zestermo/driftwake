// Edy aura's outer flame (EdyAura): a camera-facing card a little behind the body, drawn as a tall teardrop of
// rising tongues round the silhouette (thin in the middle where the body stands, so the captain shows through).
// Blended, not added, so it reads on a bright day. `look`: 0 haze (Still), 1 flame (Ember), 2 shimmer (Crown),
// 3 lightning (Storm), 4 swirl (Tide). `strength` fades it, `flash` brightens it for a moment (a blow shrugged off).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://shaders/psx/psx_common.gdshaderinc"

uniform vec4 color : source_color = vec4(0.42, 0.66, 1.0, 1.0);
uniform int look = 0;
uniform float strength = 1.0;
uniform float flash = 0.0;
uniform float bands = 4.0;
// pushed this far back from the body, toward away from the camera (metres)
uniform float behind = 0.25;
// widens the shape inside its card (a squat card off a hand wants a fuller flame)
uniform float girth = 1.0;

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
	// face the camera round the up axis, then step back from the body
	vec3 cam_r = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_cam = normalize(vec3(CAMERA_POSITION_WORLD.x - origin.x, 0.0, CAMERA_POSITION_WORLD.z - origin.z));
	vec3 w = origin + cam_r * VERTEX.x + vec3(0.0, VERTEX.y, 0.0) - to_cam * behind;
	vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
	clip = psx_snap(clip, psx_snap_res);
	POSITION = clip;
}

void fragment() {
	float t = TIME;
	// x: -1..1 across, y: 0 at the feet .. 1 at the top
	vec2 q = vec2((UV.x * 2.0 - 1.0) / girth, 1.0 - UV.y);
	float speed = look == 1 ? 2.4 : (look == 0 ? 0.8 : (look == 3 ? 1.6 : 1.2));
	// vertical tongues: the noise stretched up the card and rising
	float n = fbm(vec2(q.x * 5.0, q.y * 1.4 - t * speed));
	float n2 = fbm(vec2(q.x * 9.0 + 4.0, q.y * 2.6 - t * speed * 1.6));
	// the teardrop: narrow at the feet, widest at the waist, drawn up into a point
	float width = mix(0.42, 0.7, smoothstep(0.0, 0.3, q.y)) * mix(1.0, 0.12, smoothstep(0.35, 0.95, q.y));
	width += (n - 0.5) * (look == 0 ? 0.22 : 0.34) * (0.4 + q.y);
	float edge = width - abs(q.x);
	float shape = smoothstep(0.0, 0.08, edge);
	// tongues licking up out of the point, torn by the noise
	float tongue = smoothstep(0.62, 0.9, n2) * (1.0 - smoothstep(0.0, 0.3, abs(q.x) - 0.05)) * smoothstep(0.55, 0.8, q.y);
	shape = max(shape, tongue);
	shape *= 1.0 - smoothstep(0.9, 1.0, q.y + (n2 - 0.5) * 0.2);
	shape *= smoothstep(0.0, 0.06, q.y);
	// brightest at the edge of the shape, thinner inside where the body stands
	float rimb = 1.0 - smoothstep(0.0, 0.35, edge);
	float a = shape * mix(0.28, 0.95, rimb);
	vec3 col = color.rgb;
	vec3 hot = mix(col, vec3(1.0), 0.6);
	if (look == 1) {
		hot = vec3(1.0, 0.85, 0.45);
		a *= 0.75 + 0.5 * n2;
	} else if (look == 2) {
		float sp = step(0.93, hash(floor(vec2(q.x * 20.0, q.y * 20.0 - t * 4.0))));
		a = shape * mix(0.2, 0.75, rimb) + sp * shape * 0.8;
		hot = vec3(1.0, 0.97, 0.8);
	} else if (look == 3) {
		float vein = 1.0 - smoothstep(0.0, 0.035, abs(fbm(vec2(q.x * 4.0 + t * 0.7, q.y * 3.0 - t * 2.2)) - 0.5));
		float flick = step(0.3, hash(vec2(floor(t * 12.0), 1.0)));
		a = shape * mix(0.35, 0.95, rimb) + vein * shape * flick;
		hot = vec3(0.92, 0.85, 1.0);
		col = mix(col, vec3(0.08, 0.02, 0.14), 0.35);
	} else if (look == 4) {
		float band = sin(q.x * 6.0 + q.y * 9.0 - t * 4.0) * 0.5 + 0.5;
		a *= 0.55 + 0.6 * smoothstep(0.5, 0.9, band);
		hot = vec3(0.8, 1.0, 1.0);
	} else {
		a *= 0.7;
	}
	vec3 c = mix(col, hot, rimb * 0.5 + flash * 0.6);
	a = clamp(a * strength * (1.0 + flash), 0.0, 1.0);
	a = floor(a * bands + 0.5) / bands;
	ALBEDO = c;
	ALPHA = a;
}
