// Cloud shadows drifting over the ground and the sea. Weather drives the
// global each frame: x = coverage (0..1), y = strength (0 = off),
// zw = the wind's drift (metres). Included by the terrain and ocean shaders.
global uniform vec4 cloud_shadow;

float cs_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float cs_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(cs_hash(i), cs_hash(i + vec2(1.0, 0.0)), f.x), mix(cs_hash(i + vec2(0.0, 1.0)), cs_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 1 in sunlight .. 1 - strength under a cloud.
float cloud_shade(vec2 world_xz) {
	if (cloud_shadow.y <= 0.001) {
		return 1.0;
	}
	vec2 p = (world_xz - cloud_shadow.zw) * 0.0024;
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * cs_noise(p);
		p = p * 2.1 + vec2(5.2, 1.3);
		a *= 0.47;
	}
	v /= 0.94;
	float thr = 1.0 - cloud_shadow.x;
	return 1.0 - smoothstep(thr, thr + 0.14, v) * cloud_shadow.y;
}
