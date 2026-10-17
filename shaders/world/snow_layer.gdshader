// The soft snow lying over a snow island's terrain (a next pass on its terrain material, PSXMat.terrain):
// the same triangles raised `depth` m where the ground is snow (the splat's grass weight, off steep rock,
// paths and the shore), so a captain's boots sink into it; no collider. Only near the camera: past
// `reach` it settles onto the ground and further out its vertices are thrown off screen, so the far island
// costs no fill. Footprints (ground_prints) open holes in it down to the darkened ground underneath.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

#include "res://shaders/psx/psx_common.gdshaderinc"
#include "res://shaders/world/cloud_shadow.gdshaderinc"
#include "res://shaders/world/ground_prints.gdshaderinc"

uniform sampler2D tex_snow : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform float tex_scale = 0.25;
uniform float depth = 0.24;
uniform float reach = 48.0;
uniform float water_level = 0.0;
uniform float slope_threshold = 0.45;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 print_tint = vec3(0.62, 0.7, 0.86);

varying vec3 world_pos;
varying float thick;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(wp.xz - CAMERA_POSITION_WORLD.xz);
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float snow = clamp(1.0 - COLOR.r - COLOR.g - COLOR.b, 0.0, 1.0);
	snow *= 1.0 - smoothstep(slope_threshold - 0.18, slope_threshold - 0.06, 1.0 - clamp(wn.y, 0.0, 1.0));
	snow *= smoothstep(water_level + 1.0, water_level + 2.0, wp.y);
	snow *= 1.0 - smoothstep(reach * 0.65, reach, d);
	thick = snow * depth;
	VERTEX.y += thick;
	world_pos = wp + vec3(0.0, thick, 0.0);
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (!IN_SHADOW_PASS) {
		clip = psx_snap(clip, psx_snap_res);
	}
	// (beyond reach by more than a terrain cell: off screen, and casting nothing)
	if (IN_SHADOW_PASS || d > reach + 6.0) {
		clip = vec4(2.0, 2.0, 2.0, 1.0);
	}
	POSITION = clip;
}

void fragment() {
	if (thick < 0.04) {
		discard;
	}
	// (a fresh print is a hole; one filling back in is a shadow on the surface)
	float pr = ground_print(world_pos.xz);
	if (pr > 0.5) {
		discard;
	}
	ALBEDO = texture(tex_snow, world_pos.xz * tex_scale).rgb * tint.rgb * mix(vec3(1.0), print_tint, pr) * cloud_shade(world_pos.xz);	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
