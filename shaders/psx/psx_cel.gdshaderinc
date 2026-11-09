// Cel shading: the light() every lit PSX surface shares (psx_lit, its fade and flow variants,
// psx_cutout foliage, the island terrain). The global psx_cel (PSX.set_cel, the video setting
// "cel") switches it:
//   0 off: plain lambert, the same light Godot's diffuse_lambert gives;
//   1 dithered cel: the sun and moon light in two steps whose terminator is the PS1's own 4x4
//     ordered dither on the PSX grid, warm on the lit side and cool in shadow; lamps keep their
//     soft falloff (thresholded, a lamp's whole range went full bright). PSX's ink pass
//     (psx_ink.gdshader) draws the silhouettes.
// Picked by Zach from four looks (2026-11-09; tools/dev/celshot.gd renders on/off).
global uniform float psx_cel;

const float CEL_BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	vec3 lc = LIGHT_COLOR / PI;
	if (psx_cel < 0.5 || !LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += lc * lit;
	} else {
		// the dither on the PSX grid (540 cells tall): the cells the post pass keeps
		ivec2 p = ivec2(mod(floor(FRAGCOORD.xy * (540.0 / VIEWPORT_SIZE.y)), 4.0));
		float th = 0.28 + (CEL_BAYER[p.y * 4 + p.x] / 16.0 - 0.5) * 0.30;
		float on = step(th, lit);
		vec3 hue = mix(vec3(0.80, 0.86, 1.15), vec3(1.03, 1.0, 0.95), on);
		DIFFUSE_LIGHT += lc * mix(0.12, 1.0, on) * hue;
	}
}
