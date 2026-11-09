// Cel shading's ink: warm dark-brown silhouettes from the depth buffer, drawn by a full-screen
// quad PSX keeps at the camera while psx_cel is on (scripts/psx/psx_settings.gd). Edges are
// found cell to cell on the PSX grid, so every line is a whole cell, on the nearer side of a
// depth step; they fade out by 70 m. Transparent things (the sea, particles) aren't in the depth
// buffer: they draw over the lines (the quad sorts first). Depth only, no normal buffer: the
// creases are left to the dithered light.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// the PSX grid (PSX.pixel_res, or the window when pixelation is off)
uniform vec2 grid = vec2(960.0, 540.0);
uniform vec3 ink : source_color = vec3(0.16, 0.08, 0.05);
uniform float strength = 0.85;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// 1 / view distance: planes are affine in screen space in it, so their second difference is 0
float inv_z(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return max(-v.w / v.z, 1e-5);
}

void fragment() {
	vec2 px = 1.0 / grid;
	vec2 uv = (floor(SCREEN_UV * grid) + 0.5) / grid;
	float c = inv_z(uv, INV_PROJECTION_MATRIX);
	float l = inv_z(uv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float r = inv_z(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float u = inv_z(uv - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float dn = inv_z(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	// the near side of a step bends the wrong way (negative second difference)
	float s = min(l + r - 2.0 * c, u + dn - 2.0 * c) / c;
	float edge = smoothstep(0.12, 0.25, -s) * (1.0 - smoothstep(35.0, 70.0, 1.0 / c));
	if (edge < 0.01) {
		discard;
	}
	ALBEDO = ink;
	ALPHA = edge * strength;
}
