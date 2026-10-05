// One puff of a 3D cloud (Clouds / scripts/world/cloud_spawner.gd draws
// hundreds in one MultiMesh, sorted back to front every frame). Camera-facing,
// soft round noisy edge, alpha blended (the PSX post pass quantises and
// dithers it on the game's own pixel grid, so it stays steady at any
// resolution); fades out right in front of the camera so flying through a
// cloud doesn't slap a giant sprite on the screen, and far away so the sky's
// own cloud layer takes over. Melts into the horizon haze exactly like the sky.
// Per-instance COLOR: rgb shade, a = opacity. INSTANCE_CUSTOM.x: noise seed.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, fog_disabled, blend_mix;

uniform vec3 lit_color : source_color = vec3(1.0);
uniform vec3 shade_color : source_color = vec3(0.62, 0.68, 0.8);
uniform vec3 fog_color : source_color = vec3(0.5, 0.72, 0.92);
uniform float haze_height = 0.08;
// horizontal distance: [start, end] of the far fade-out
uniform vec2 fade = vec2(820.0, 1150.0);
// distance haze: [begin, end] (a softer version of the world fog)
uniform vec2 fog_range = vec2(110.0, 1150.0);
uniform float time_s = 0.0;

varying vec4 inst;
varying float seed;
varying float cam_dist;
varying float far_k;
varying float haze_k;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 up = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 world = center + right * VERTEX.x * sx + up * VERTEX.y * sy;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	vec3 rel = world - CAMERA_POSITION_WORLD;
	cam_dist = length(rel);
	// fade and haze by the puff's centre, so a puff fades as one piece
	vec3 crel = center - CAMERA_POSITION_WORLD;
	far_k = 1.0 - smoothstep(fade.x, fade.y, length(crel.xz));
	float elev = crel.y / max(length(crel), 0.001);
	float hz = 1.0 - smoothstep(0.0, max(haze_height, 0.001), elev);
	hz = hz * hz * (3.0 - 2.0 * hz);
	float dz = pow(smoothstep(fog_range.x, fog_range.y, length(crel)), 1.6) * 0.65;
	haze_k = max(hz, dz);
	inst = COLOR;
	seed = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float n = noise(uv * 2.6 + seed + time_s * 0.02) * 0.6 + noise(uv * 6.0 - seed) * 0.4;
	float a = smoothstep(1.0, 0.55, r + (n - 0.5) * 0.55);
	// shade: lit on top, shaded underneath (plus the per-puff shade)
	float lit = clamp(0.5 + uv.y * -0.45 + (n - 0.5) * 0.3, 0.0, 1.0);
	vec3 col = mix(shade_color, lit_color, lit) * inst.rgb;
	col = mix(col, fog_color, haze_k);
	float opacity = inst.a * smoothstep(3.0, 22.0, cam_dist) * far_k;
	ALBEDO = col;
	ALPHA = clamp(a * opacity, 0.0, 1.0);
}
