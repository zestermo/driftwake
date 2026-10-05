// PSX terrain: nearest-filtered world-space textures with crunchy dithered
// transitions. Two weighting modes:
//  - use_splat = false: height/slope based (procedural islands)
//  - use_splat = true : per-vertex splat from COLOR (r=dirt, g=rock, b=sand),
//                       grass fills the rest (hand-built starter island)
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

#include "res://shaders/psx/psx_common.gdshaderinc"

uniform sampler2D tex_grass : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform sampler2D tex_sand : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform sampler2D tex_wet_sand : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform sampler2D tex_dirt : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform sampler2D tex_rock : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform sampler2D tex_seafloor : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;

uniform bool use_splat = false;
uniform float tex_scale = 0.25; // tiles per meter
uniform float water_level = 0.0;
uniform float sand_height : hint_range(-5.0, 20.0) = 2.0;
uniform float grass_height : hint_range(-5.0, 30.0) = 6.0;
uniform float rock_height : hint_range(-5.0, 60.0) = 14.0;
uniform float slope_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float dither_amount : hint_range(0.0, 1.0) = 0.35;
uniform float dither_cells_per_meter = 6.0;
uniform float affine_amount : hint_range(0.0, 1.0) = 0.2;
uniform vec4 tint : source_color = vec4(1.0);

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 splat;
varying vec3 affine_w;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	splat = COLOR;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	// Never snap in the shadow pass: the light's projection follows the camera, so
	// snapping there makes shadows pop and flicker as the player moves.
	if (!IN_SHADOW_PASS) {
		clip = psx_snap(clip, psx_snap_res);
	}
	POSITION = clip;
	affine_w = vec3(world_pos.xz * clip.w, clip.w);
}

void fragment() {
	// (world-space texturing stays put: affine warp on these big triangles made
	// the ground slide with the camera)
	vec2 wuv = world_pos.xz;
	vec2 uv = wuv * tex_scale;
	float h = world_pos.y;
	float slope = 1.0 - clamp(normalize(world_normal).y, 0.0, 1.0);

	float w_sea = 1.0 - smoothstep(water_level - 1.6, water_level - 0.4, h);
	float w_wet = (1.0 - w_sea) * (1.0 - smoothstep(water_level + 0.1, water_level + 0.8, h));
	float land = 1.0 - max(w_sea, w_wet);

	float w_sand;
	float w_dirt;
	float w_rock;
	float w_grass;
	if (use_splat) {
		w_sand = splat.b;
		w_dirt = splat.r;
		w_rock = splat.g;
		w_grass = clamp(1.0 - w_sand - w_dirt - w_rock, 0.0, 1.0);
	} else {
		w_sand = 1.0 - smoothstep(sand_height - 0.8, sand_height + 0.8, h);
		w_rock = smoothstep(rock_height - 2.0, rock_height + 2.0, h);
		w_dirt = 0.0;
		w_grass = clamp(1.0 - w_sand - w_rock, 0.0, 1.0);
	}
	float slope_rock = smoothstep(slope_threshold - 0.08, slope_threshold + 0.08, slope);
	w_rock = max(w_rock, slope_rock * step(water_level + 0.5, h));

	w_sand *= land;
	w_dirt *= land;
	w_rock *= land;
	w_grass *= land;

	// Dithered winner-takes-all selection on a stable world-space grid.
	vec2 cell = floor(world_pos.xz * dither_cells_per_meter);
	float d = dither_amount;
	float s0 = w_sea + (hash12(cell) - 0.5) * d;
	float s1 = w_wet + (hash12(cell + 17.0) - 0.5) * d;
	float s2 = w_sand + (hash12(cell + 31.0) - 0.5) * d;
	float s3 = w_dirt + (hash12(cell + 47.0) - 0.5) * d;
	float s4 = w_rock + (hash12(cell + 59.0) - 0.5) * d;
	float s5 = w_grass + (hash12(cell + 73.0) - 0.5) * d;

	vec3 col = texture(tex_seafloor, uv).rgb;
	float best = s0;
	if (s1 > best) { best = s1; col = texture(tex_wet_sand, uv).rgb; }
	if (s2 > best) { best = s2; col = texture(tex_sand, uv).rgb; }
	if (s3 > best) { best = s3; col = texture(tex_dirt, uv).rgb; }
	if (s4 > best) { best = s4; col = texture(tex_rock, uv * 0.75).rgb; }
	if (s5 > best) { best = s5; col = texture(tex_grass, uv).rgb; }

	ALBEDO = col * tint.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
