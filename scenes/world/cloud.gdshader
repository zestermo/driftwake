shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, shadows_disabled;

uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloud_shadow_color : source_color = vec4(0.7, 0.75, 0.85, 1.0);
uniform float cloud_density : hint_range(0.0, 1.0) = 0.6;
uniform float cloud_softness : hint_range(0.0, 1.0) = 0.3;
uniform float cloud_seed = 0.0;
uniform float drift_speed = 0.002;
uniform float scale = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p + cloud_seed, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.48;
	}
	return v;
}

void vertex() {
	// Billboard — always face camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0; // Center UVs at 0,0

	// Radial distance from center
	float dist = length(uv);

	// Circular falloff
	float circle = 1.0 - smoothstep(0.3, 1.0, dist);

	// Noise cloud shape
	vec2 noise_uv = uv * scale * 2.0 + vec2(TIME * drift_speed, TIME * drift_speed * 0.3);
	float n = fbm(noise_uv + cloud_seed);

	// Cloud alpha
	float cloud = n * circle;
	float alpha = smoothstep(cloud_softness, cloud_softness + cloud_density, cloud);

	// Shade: bottom of cloud is slightly darker
	float shade = smoothstep(-0.5, 0.5, uv.y);
	vec3 col = mix(cloud_shadow_color.rgb, cloud_color.rgb, shade * 0.5 + 0.5);

	ALBEDO = col;
	ALPHA = alpha * cloud_color.a;
}
