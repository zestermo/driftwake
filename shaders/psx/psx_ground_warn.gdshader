// The dither ground warnings of any size (1.19, matching gen_dither_fx.py's telegraph): FX.arc_warn's fans and
// BeastFX.lane's strips. Drawn here on a world-space pixel grid (`texel` m) instead of from a sheet, so a 9 m
// lane or a 120-degree fan keeps square pixels: thin rails with a dark outer pixel that boils, a sparse
// Bayer speckle, small chevrons marching along it behind a dithered front sweeping out to `reveal` m.
// A decal like psx_decal_body.gdshaderinc (snapped, no depth writes, pulled toward the camera).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

#include "res://shaders/psx/psx_common.gdshaderinc"

// 0 = lane (mesh x -0.5..0.5 across, z 0..-1 along, scaled by `size`), 1 = fan (unit radius about -Z, `angle` wide)
uniform int shape = 0;
uniform vec2 size = vec2(1.0, 4.0);
uniform float angle = 1.5;
uniform float texel = 0.09;
uniform float reveal = 0.0;
uniform float opacity = 0.6;
uniform vec4 pal_dark : source_color = vec4(0.1, 0.02, 0.02, 1.0);
uniform vec4 pal_deep : source_color = vec4(0.4, 0.08, 0.06, 1.0);
uniform vec4 pal_body : source_color = vec4(1.0, 0.45, 0.15, 1.0);
uniform vec4 pal_hi : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float pull = 0.04;

varying vec3 lp;

const float BAYER4[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	lp = VERTEX;
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float dd = -view.z;
	view.xyz -= normalize(view.xyz) * pull * clamp(dd / 5.0, 0.6, 5.0);
	POSITION = psx_snap(PROJECTION_MATRIX * view, psx_snap_res);
}

void fragment() {
	// across (m from the middle), along (m from the start), and how far the side and far edges are in pixels
	float across;
	float along;
	float side;
	float far_edge;
	if (shape == 0) {
		across = lp.x * size.x;
		along = -lp.z * size.y;
		side = (size.x * 0.5 - abs(across)) / texel;
		far_edge = (size.y - along) / texel;
	} else {
		float rad = length(lp.xz) * size.y;
		float a = atan(lp.x, -lp.z);
		across = a * rad;
		along = rad;
		side = (angle * 0.5 - abs(a)) * rad / texel;
		far_edge = (size.y - rad) / texel;
	}
	vec2 q = floor(vec2(across, along) / texel);
	float bay = (BAYER4[int(mod(q.y, 4.0)) * 4 + int(mod(q.x, 4.0))] + 0.5) / 16.0;
	// the edges boil: redrawn every few frames, nudged by up to a pixel in short runs
	float boil = floor(TIME * 6.0);
	side += hash(floor(q.y / 3.0) + boil * 7.0) * 1.2 - 0.6;
	far_edge += hash(floor(q.x / 3.0) + boil * 11.0) * 1.2 - 0.6;
	float edge = min(side, far_edge);

	int idx = 0;
	if (bay < 0.07) {
		idx = 2;
	}
	float front = (along - reveal) / texel;
	if (front < 0.0 && front > -3.5 && bay < 0.22) {
		idx = 3;
	}
	if (abs(front + 0.5) < 0.7 && bay < 0.6) {
		idx = 4;
	}
	// chevrons down the middle every metre, marching on, only where the front has passed
	float sc = mod(along - TIME * 1.4, 1.0) / texel;
	if (along < reveal && sc < 3.0 && abs(across) / texel <= (3.0 - sc) * 0.9) {
		idx = 4;
	}
	if (edge < 2.0) {
		idx = 3;
	}
	if (edge < 1.0) {
		idx = 1;
	}
	if (edge < 0.0 || idx == 0) {
		discard;
	}
	ALBEDO = idx == 1 ? pal_dark.rgb : idx == 2 ? pal_deep.rgb : idx == 3 ? pal_body.rgb : pal_hi.rgb;
	ALPHA = opacity;
}
