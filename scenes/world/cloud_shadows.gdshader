shader_type spatial;
render_mode blend_mul, unshaded, cull_disabled, shadows_disabled;

uniform float cloud_scale = 0.0012;
uniform float cloud_speed = 0.005;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.45;
uniform vec2 wind_direction = vec2(1.0, 0.3);
// Controls how much of the sky is covered (higher = more cloud, lower = more clear)
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.4;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	for (int i = 0; i < 6; i++) {
		value += amplitude * noise(p * frequency);
		frequency *= 2.1;
		amplitude *= 0.45;
	}
	return value;
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = world_pos.xz * cloud_scale;

	// Drifting clouds
	vec2 wind = normalize(wind_direction) * cloud_speed * TIME;

	// Two fbm layers at different scales for more interesting shapes
	float cloud1 = fbm(uv + wind);
	float cloud2 = fbm(uv * 2.3 + wind * 0.7 + vec2(5.2, 1.3));

	// Combine and shape into distinct clouds
	float cloud = (cloud1 + cloud2 * 0.4) / 1.4;

	// Threshold to create distinct cloud vs clear areas
	float threshold = 1.0 - cloud_coverage;
	cloud = smoothstep(threshold, threshold + 0.15, cloud);

	// Shadow intensity
	float shadow = 1.0 - cloud * shadow_strength;

	ALBEDO = vec3(shadow);
	ALPHA = 1.0;
}
