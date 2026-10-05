// One puff of a 3D cloud (Clouds / scripts/world/cloud_spawner.gd draws
// hundreds in one MultiMesh). Camera-facing, soft round noisy edge, PS1
// screen-door (dithered) transparency so nothing needs sorting; fades out
// right in front of the camera so flying through a cloud doesn't slap a
// giant sprite on the screen. Per-instance COLOR: rgb shade, a = opacity.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform vec3 lit_color : source_color = vec3(1.0);
uniform vec3 shade_color : source_color = vec3(0.62, 0.68, 0.8);
uniform float time_s = 0.0;

varying vec4 inst;
varying float seed;
varying float cam_dist;

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
	cam_dist = length(world - CAMERA_POSITION_WORLD);
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
	float opacity = inst.a * smoothstep(3.0, 22.0, cam_dist);
	a *= opacity;
	// 4x4 ordered dither: PS1 screen-door transparency
	int x = int(FRAGCOORD.x) % 4;
	int y = int(FRAGCOORD.y) % 4;
	float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	float thr = (bayer[y * 4 + x] + 0.5) / 16.0;
	if (a < thr) {
		discard;
	}
	ALBEDO = col;
}
