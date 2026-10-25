// Light shafts under water (1.21 small fixes): Weather's "DiveShafts", one MultiMesh of long quads hung from the
// surface down along the sun's refracted direction, each turning to face the camera round its own axis. All on the
// GPU: every beam's place is its offset in a TILE m square that wraps round the camera here, so the CPU only sets
// the uniforms (strength, sun, colour) while you're under. Additive, soft at the edges, brightest just under the
// surface and fading down and with distance (the water's own fog is close), shimmering as the waves pass over.
// Per instance: the transform's origin = its offset in the tile, x scale = width, y scale = length; COLOR.a a seed.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never, fog_disabled;

uniform vec3 shaft_color : source_color = vec3(0.75, 0.95, 0.9);
uniform vec3 sun_dir = vec3(0.0, 0.8, 0.6);
uniform float intensity = 0.0;
uniform float surface_y = 0.0;
uniform float tile = 48.0;
// [full until, gone by] (m from the camera)
uniform vec2 fade = vec2(10.0, 30.0);

varying float seed;
varying float along_len;
varying vec3 world_pos;
varying float cam_d;

void vertex() {
	vec3 off = MODEL_MATRIX[3].xyz;
	float wid = length(MODEL_MATRIX[0].xyz);
	float len = length(MODEL_MATRIX[1].xyz);
	seed = COLOR.a;
	// the sun bent by the water: steeper under the surface
	vec3 s = normalize(sun_dir);
	vec3 axis = normalize(vec3(s.x * 0.35, max(s.y, 0.2), s.z * 0.35));
	// the beam's top on the surface, wrapped into the tile round the camera
	vec2 c = CAMERA_POSITION_WORLD.xz;
	vec2 p = c + mod(off.xz - c + tile * 0.5, tile) - tile * 0.5;
	// a slow sway, as the waves overhead move
	p += vec2(sin(TIME * 0.31 + seed * 17.0), cos(TIME * 0.27 + seed * 11.0)) * 0.6;
	vec3 top = vec3(p.x, surface_y, p.y);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - top);
	vec3 side = normalize(cross(axis, to_cam));
	// VERTEX.y runs 0 (the top) .. 1 (the far end) down the axis
	world_pos = top + side * VERTEX.x * wid - axis * VERTEX.y * len;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_pos, 1.0);
	cam_d = length(world_pos - CAMERA_POSITION_WORLD);
	along_len = len;
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	// (the quad's UV.y is 0 at its +y end, the far end here)
	float along = 1.0 - UV.y;
	float a = pow(across, 1.8) * smoothstep(0.0, 0.06, along) * pow(1.0 - along, 1.6);
	// shimmer: the light through the moving waves comes and goes along the beam
	float sh = sin(along * along_len * 0.9 - TIME * 1.7 + seed * 40.0) * 0.5 + 0.5;
	sh *= sin(TIME * (0.5 + seed) + seed * 23.0) * 0.35 + 0.65;
	a *= 0.55 + sh * 0.45;
	float far = 1.0 - smoothstep(fade.x, fade.y, cam_d);
	float near = smoothstep(0.8, 3.0, cam_d);
	ALBEDO = shaft_color * a * far * near * intensity;
}
