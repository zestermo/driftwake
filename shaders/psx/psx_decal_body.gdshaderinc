// A flat mark lying on a surface (blood splats, puddles): psx_decal.gdshader lit,
// psx_decal_unshaded.gdshader unshaded. It snaps to the same screen grid as the
// ground under it (so it doesn't slide over the wobble), never writes depth (so
// overlapping marks don't fight), and is pulled toward the camera by a distance
// that grows with depth: snapping tilts the ground's triangles by a few cm up close
// and more far off, which poked through marks lifted a fixed 1-2 cm.
#include "res://shaders/psx/psx_common.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
// Metres toward the camera at 5 m (scaled 0.6x..5x with depth, like psx_lit's depth_pull).
uniform float pull = 0.04;
#ifdef PSX_DECAL_SHEET
// Sheet mode (psx_decal_sheet*.gdshader): a flipbook of grid.x * grid.y frames on the mesh's UVs. `frame` is
// set by code (a one-shot, like a telegraph's charge); fps > 0 loops it by itself, each MultiMesh instance at
// its own phase. With palette_mode the sheet holds indices (grey 0.2 / 0.4 / 0.6 / 0.8) coloured by pal_*.
uniform sampler2D sheet : source_color, filter_nearest, hint_default_white;
uniform vec2 grid = vec2(4.0, 2.0);
uniform float frame = 0.0;
uniform float fps = 0.0;
uniform bool palette_mode = false;
uniform vec4 pal_dark : source_color = vec4(0.1, 0.02, 0.02, 1.0);
uniform vec4 pal_deep : source_color = vec4(0.4, 0.08, 0.06, 1.0);
uniform vec4 pal_body : source_color = vec4(1.0, 0.45, 0.15, 1.0);
uniform vec4 pal_hi : source_color = vec4(1.0, 0.85, 0.5, 1.0);
varying flat float v_frame;
#endif

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip;
	if (!IN_SHADOW_PASS) {
		float dd = -view.z;
		view.xyz -= normalize(view.xyz) * pull * clamp(dd / 5.0, 0.6, 5.0);
		clip = psx_snap(PROJECTION_MATRIX * view, psx_snap_res);
	} else {
		clip = PROJECTION_MATRIX * view;
	}
	POSITION = clip;
#ifdef PSX_DECAL_SHEET
	float fr = fps > 0.0 ? floor(TIME * fps + float(INSTANCE_ID) * 2.7) : floor(frame);
	v_frame = mod(fr, grid.x * grid.y);
#endif
}

void fragment() {
#ifdef PSX_DECAL_SHEET
	vec2 cell = vec2(mod(v_frame, grid.x), floor(v_frame / grid.x));
	vec4 s = texture(sheet, (cell + clamp(UV, 0.001, 0.999)) / grid);
	vec3 base = s.rgb;
	if (palette_mode) {
		// the sheet's greys are sRGB-decoded by source_color: undo that to read the index
		int i = int(round(pow(s.r, 1.0 / 2.2) * 5.0));
		base = i <= 1 ? pal_dark.rgb : i == 2 ? pal_deep.rgb : i == 3 ? pal_body.rgb : pal_hi.rgb;
	}
	ALBEDO = base * albedo_color.rgb * COLOR.rgb;
	ALPHA = s.a * albedo_color.a * COLOR.a;
#else
	ALBEDO = albedo_color.rgb * COLOR.rgb;
	ALPHA = albedo_color.a * COLOR.a;
#endif
#ifndef PSX_DECAL_UNSHADED
	ROUGHNESS = roughness;
	SPECULAR = specular;
#endif
}
