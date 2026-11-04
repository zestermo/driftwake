shader_type spatial;
// The coral atoll's lagoon life moved entirely on the GPU (AtollShoals): mode 0 = a shoal of little fish circling under
// the water, turning together, tails beating; mode 1 = white seabirds wheeling over the lagoon. Per instance
// (INSTANCE_CUSTOM): x phase, y speed, z spread, w its level. The instance colour is the fish's or the bird's.
// Mode 2 (AtollBasin's vents): bubbles rising through a column.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float mode = 0.0;
uniform float radius = 4.0;
uniform float height = 1.0;

varying vec3 tint;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	tint = COLOR.rgb;
	if (mode > 1.5) {
		// a vent's bubbles streaming up its column (radius wide, height up and down from the middle), wobbling
		float rise = fract(TIME * (0.1 + c.y) * 6.0 / max(height, 1.0) + c.x);
		float wob = TIME * 3.0 + c.x * 20.0;
		vec3 bo = vec3(sin(wob) * 0.12 + (c.z - 0.5) * radius, height * (rise * 2.0 - 1.0), cos(wob * 0.8) * 0.12 + (c.w - 0.5) * radius);
		VERTEX = VERTEX * (0.6 + rise * 0.8) + bo;
	} else {
		float t = TIME * (0.2 + c.y) + c.x * 0.9;
		bool fish = mode < 0.5;
		float r = radius * (0.35 + 0.65 * c.z);
		// a fish shoal turns as one (the phase spread small), drifting in and out; birds spread round the whole circle
		float a = fish ? t + c.x * 0.6 : t + c.x * 6.2831;
		vec3 off = vec3(cos(a) * r, height * (c.w - 0.5) + sin(TIME * 1.1 + c.x * 9.0) * (fish ? 0.12 : 1.2), sin(a) * r);
		if (fish) {
			off.xz += vec2(sin(TIME * 0.31 + c.z * 4.0), cos(TIME * 0.27 + c.x * 3.0)) * radius * 0.25;
		}
		vec3 v = VERTEX;
		if (fish) {
			v.x += sin(TIME * 14.0 + c.x * 40.0) * 0.18 * max(v.z, 0.0);
		} else {
			v.y += abs(VERTEX.x) * sin(TIME * 7.0 + c.x * 30.0) * 0.6;
		}
		// (faces along the circle: the mesh's nose is -z)
		float head = a + 3.14159;
		float ch = cos(head);
		float sh = sin(head);
		v = vec3(v.x * ch - v.z * sh, v.y, v.x * sh + v.z * ch);
		VERTEX = v + off;
	}
}

void fragment() {
	ALBEDO = tint;
}
