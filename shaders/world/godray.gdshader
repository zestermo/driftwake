// A shaft of sunlight (Weather's godrays): a long quad along the sun's
// direction that turns to face the camera around its long axis, additive,
// soft at the edges and both ends, drifting dust-noise inside. Strongest
// when you look toward the sun. Per-instance COLOR.a = strength.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never, fog_disabled;

uniform vec3 ray_color : source_color = vec3(1.0, 0.9, 0.7);
uniform vec3 sun_dir = vec3(0.0, 0.7, 0.7);
uniform float intensity = 0.0;
uniform float time_s = 0.0;

varying float strength;
varying vec3 world_pos;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 axis = normalize(MODEL_MATRIX[1].xyz);
	float len = length(MODEL_MATRIX[1].xyz);
	float wid = length(MODEL_MATRIX[0].xyz);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - center);
	vec3 side = normalize(cross(axis, to_cam));
	world_pos = center + side * VERTEX.x * wid + axis * VERTEX.y * len;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_pos, 1.0);
	strength = COLOR.a;
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = UV.y;
	float a = pow(across, 1.6) * smoothstep(0.0, 0.25, along) * smoothstep(1.0, 0.55, along);
	// dust drifting in the beam
	float d = sin(along * 23.0 + time_s * 0.7 + strength * 50.0) * 0.5 + 0.5;
	a *= 0.75 + d * 0.25;
	vec3 view = normalize(world_pos - CAMERA_POSITION_WORLD);
	float toward = pow(max(dot(view, normalize(sun_dir)), 0.0), 2.0) * 0.8 + 0.2;
	ALBEDO = ray_color * a * strength * intensity * toward;
}
