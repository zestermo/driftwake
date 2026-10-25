// A city's pigeons (CityPigeons, 1.21's city detail pass): every bird one instance of a little pigeon mesh, all of
// them moved here on the GPU. On the ground they peck (the head dips), shuffle and now and then hop; when a captain
// walks into the flock (`scare`: the local captain's position, its radius) they lift off flapping and hang in the
// air over it until they're left alone, then settle again. Per instance: INSTANCE_CUSTOM x a phase, y its pace.
// The mesh's head is where z < -0.08 and its wings where |x| > 0.075 (CityPigeons.mesh).
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec4 scare = vec4(0.0, -1000.0, 0.0, 3.5);

varying vec3 col;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float t = TIME * (0.8 + c.y * 0.6) + c.x * 6.2831;
	vec3 v = VERTEX;
	vec3 at = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = length(at.xz - scare.xz);
	float up = smoothstep(scare.w, scare.w * 0.45, d) * step(abs(at.y - scare.y), 4.0);
	float head = smoothstep(-0.07, -0.11, v.z) * step(0.06, v.y);
	float wing = smoothstep(0.07, 0.09, abs(v.x));
	// on the ground: peck, and a hop now and then
	float peck = pow(max(sin(t * 2.3), 0.0), 3.0) * (1.0 - up);
	v.y -= head * peck * 0.07;
	v.z -= head * peck * 0.035;
	float hop = pow(max(sin(t * 0.45) - 0.92, 0.0) * 12.5, 1.0) * (1.0 - up);
	// in the air: wings beating, up over the captain's head
	float flap = sin(TIME * 22.0 + c.x * 9.0) * 1.1 * up;
	if (wing > 0.0) {
		// each wing hinged at its root (x 0.07, y 0.1), beating up and down
		float side = sign(v.x);
		vec2 q = vec2(abs(v.x) - 0.07, v.y - 0.1);
		float a = flap * wing;
		q = vec2(q.x * cos(a) - q.y * sin(a), q.x * sin(a) + q.y * cos(a));
		v.x = side * (0.07 + q.x);
		v.y = 0.1 + q.y;
	}
	v.y += hop * 0.12 + up * (2.6 + c.x * 1.6 + sin(TIME * 2.0 + c.x * 20.0) * 0.25);
	v.x += up * sin(TIME * 0.9 + c.x * 13.0) * 1.2;
	v.z += up * cos(TIME * 0.8 + c.x * 7.0) * 1.2;
	VERTEX = v;
	col = COLOR.rgb;
}

void fragment() {
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
