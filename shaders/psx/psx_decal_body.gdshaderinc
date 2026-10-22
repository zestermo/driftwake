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
}

void fragment() {
	ALBEDO = albedo_color.rgb * COLOR.rgb;
	ALPHA = albedo_color.a * COLOR.a;
#ifndef PSX_DECAL_UNSHADED
	ROUGHNESS = roughness;
	SPECULAR = specular;
#endif
}
