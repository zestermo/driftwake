// PSX ocean. The wave math (ocean_waves.gdshaderinc) MUST stay in sync with
// OceanManager._height (scripts/ocean/ocean_manager.gd): swimmers, the ship and enemies float on it.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_lambert, specular_schlick_ggx;

#include "res://shaders/psx/psx_common.gdshaderinc"
#include "res://shaders/world/cloud_shadow.gdshaderinc"
#include "res://scenes/ocean/ocean_waves.gdshaderinc"

uniform vec4 deep_color : source_color = vec4(0.05, 0.16, 0.3, 0.95);
uniform vec4 shallow_color : source_color = vec4(0.2, 0.5, 0.6, 0.8);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform sampler2D water_tex : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform float water_tex_scale = 0.14;
uniform vec2 water_scroll = vec2(0.02, 0.012);

// Foam spiralling in toward the eye (0..1), and how near the eye (0..1).
vec2 whirl_foam(vec2 p, float t) {
	float foam = 0.0;
	float eye = 0.0;
	for (int i = 0; i < 2; i++) {
		vec4 w = whirls[i];
		if (w.z <= 0.0) {
			continue;
		}
		vec2 d = p - w.xy;
		float r = length(d) / w.z;
		if (r >= 1.0) {
			continue;
		}
		float a = atan(d.y, d.x);
		float s = sin(a * 3.0 + log(max(r, 0.02)) * 9.0 + t * 2.4);
		float k = 1.0 - smoothstep(0.45, 1.0, r);
		foam = max(foam, smoothstep(0.35, 0.95, s) * k);
		eye = max(eye, 1.0 - smoothstep(0.0, 0.22, r));
	}
	return vec2(foam, eye);
}
// Foam wakes (OceanManager._send_wakes): trails of (x, z, age, strength),
// newest first, a zero point between hulls; wake_box bounds them all.
uniform vec4 wake[40];
uniform vec4 wake_box = vec4(1.0, 1.0, -1.0, -1.0);
uniform float wake_life = 8.0;

// A cell's worth of noise (0..1): foam breaks up in PSX-sized blocks.
float cell_noise(vec2 c) {
	return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
}

// Foam behind a hull under way: churned white water close astern and the
// two arms of the V spreading out behind it, fading as they age. (Measured
// from the nearest point of the whole trail, so its joints don't show.)
float wake_foam(vec2 p, float t) {
	if (p.x < wake_box.x || p.y < wake_box.y || p.x > wake_box.z || p.y > wake_box.w) {
		return 0.0;
	}
	float d = 1e6;
	float age = 0.0;
	float str = 0.0;
	for (int i = 0; i < 39; i++) {
		vec4 a = wake[i];
		vec4 b = wake[i + 1];
		if (a.w <= 0.0 || b.w <= 0.0) {
			continue;
		}
		vec2 ab = b.xy - a.xy;
		float h = clamp(dot(p - a.xy, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
		float di = length(p - a.xy - ab * h);
		if (di < d) {
			d = di;
			age = mix(a.z, b.z, h);
			str = mix(a.w, b.w, h);
		}
	}
	float k = clamp(age / wake_life, 0.0, 1.0);
	float half_w = 1.2 + age * 0.85;
	if (str <= 0.0 || d > half_w + 1.5) {
		return 0.0;
	}
	float arms = 1.0 - smoothstep(0.15, 0.55 + age * 0.1, abs(d - half_w));
	float churn = (1.0 - smoothstep(0.0, half_w * 0.55, d)) * (1.0 - smoothstep(0.0, 0.3, k));
	float n = cell_noise(floor(p * 2.0) + floor(t * 3.0) * 0.37);
	float v = max(arms * 0.7, churn * 0.9) * (1.0 - k) * str;
	return v * step(0.35 + k * 0.45, n);
}

// Turquoise shallows: the seabed's depth here (an island's shore map, or
// WorldGenerator.bake_shallows' world map), 0 at the waterline to 1 at OceanManager.SHOAL_DEPTH and below.
uniform sampler2D shoal_map : filter_linear, repeat_disable, hint_default_white;
uniform vec4 shoal_rect = vec4(0.0);
uniform vec4 shoal_color : source_color = vec4(0.16, 0.72, 0.66, 1.0);
const float SHOAL_DEPTH = 14.0;

float shoal_depth(vec2 p, vec4 sh) {
	if (sh.x < shore_none.x - 1.0) {
		return clamp(sh.x / SHOAL_DEPTH, 0.0, 1.0);
	}
	vec2 u = (p - shoal_rect.xy) / max(shoal_rect.z, 0.001);
	if (shoal_rect.w > 0.5 && u.x > 0.0 && u.y > 0.0 && u.x < 1.0 && u.y < 1.0) {
		return texture(shoal_map, u).r;
	}
	return 1.0;
}
// A coral atoll's lagoon (AtollWater sets it near one, 0 elsewhere): x, z, radius, strength. Inside it the water is
// clear tropical blue however deep (its floor shows), and a texel of shore map with no shore in reach (its swell
// distance at FAR, where shore_at gives the open sea's NONE: the waves are unchanged) still gives the colour its depth.
uniform vec4 lagoon_disc = vec4(0.0);
uniform vec4 lagoon_color : source_color = vec4(0.1, 0.6, 0.78, 1.0);

float lagoon_depth(vec2 p, float sd) {
	float best = 1e6;
	for (int i = 0; i < 4; i++) {
		vec4 r = shore_rect[i];
		vec2 u = (p - r.xy) / max(r.z, 0.001);
		if (r.w > 0.5 && u.x > 0.0 && u.y > 0.0 && u.x < 1.0 && u.y < 1.0) {
			vec4 s = i == 0 ? textureLod(shore0, u, 0.0) : (i == 1 ? textureLod(shore1, u, 0.0) : (i == 2 ? textureLod(shore2, u, 0.0) : textureLod(shore3, u, 0.0)));
			best = min(best, s.x);
		}
	}
	return best < 1e5 ? clamp(best / SHOAL_DEPTH, 0.0, 1.0) : sd;
}
uniform float wave_total = 1.38;
uniform float near_half = 120.0;
uniform float growth = 0.08;

uniform float fresnel_power = 3.0;
uniform float foam_threshold = 0.6;
// Whitecaps (Weather: with the wind and storms, 0..1) streaked along the wind.
uniform float whitecaps = 0.0;
uniform vec2 wind_dir = vec2(1.0, 0.0);
uniform float time_val = 0.0;
uniform float near_alpha = 0.82;
// The glitter path (Weather): toward the sun by day, the moon by night; rgb its colour, a its strength (0 = none:
// under cloud, in storms, below the horizon).
uniform vec3 glint_dir = vec3(0.0, 1.0, 0.0);
uniform vec4 glint_color = vec4(1.0, 0.95, 0.8, 0.0);
// the camera is under the sea (Weather): the surface's underside is drawn, otherwise its back faces aren't
uniform float under_sea = 0.0;
// The horizon haze (Weather): rgb = the fog colour (sRGB), a = how far up the
// sky it reaches. Toward the horizon the sea melts into the same colour the
// sky does just above it, so there is no line where the sea stops.
global uniform vec4 sky_haze;
// Cel shading (PSX, the video setting "cel") turns the sea toon: Zach's pick of three looks, 2026-11-09
global uniform float psx_cel;
const float SEA_BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
// The scene's depth fog (Weather): begin, end in metres.
global uniform vec2 fog_range;

varying float wave_height_val;
varying vec3 world_pos;
varying vec3 affine_w;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// the graded grid: 1 m cells within near_half of its centre, then growing
	float d = max(abs(VERTEX.x), abs(VERTEX.z));
	float cell = d <= near_half ? 1.0 : 1.25 + growth * (d - near_half);

	vec4 sh = shore_at(world_pos.xz);
	float h = wave_h(world_pos.xz, time_val, cell, sh);
	float fu = funnel(world_pos.xz);
	VERTEX.y += h + fu;
	wave_height_val = h;

	float eps = 0.25;
	vec2 px = world_pos.xz + vec2(eps, 0.0);
	vec2 pz = world_pos.xz + vec2(0.0, eps);
	// (off the maps a neighbour's shore sample is the same: no fetch)
	vec4 shx = sh.x < shore_none.x - 1.0 ? shore_at(px) : sh;
	vec4 shz = sh.x < shore_none.x - 1.0 ? shore_at(pz) : sh;
	float dx = (wave_h(px, time_val, cell, shx) + funnel(px) - h - fu) / eps;
	float dz = (wave_h(pz, time_val, cell, shz) + funnel(pz) - h - fu) / eps;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));

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
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	vec2 wuv = world_pos.xz;
	vec3 tex = texture(water_tex, wuv * water_tex_scale + water_scroll * time_val).rgb;

	vec3 base_color = mix(deep_color.rgb, shallow_color.rgb, fresnel);
	base_color = mix(base_color, tex, 0.35);

	float crest_k = wave_height_val / max(wave_total, 0.01);
	float foam_factor = smoothstep(foam_threshold, foam_threshold + 0.3, crest_k);
	// whitecaps: broken patches on the crests, drawn out along the wind and
	// blown downwind, more of them (and lower down the waves) as it blows harder
	vec2 wd = normalize(wind_dir + vec2(0.0001));
	vec2 along = vec2(dot(wuv, wd), dot(wuv, vec2(-wd.y, wd.x)));
	float streaks = cell_noise(floor(vec2(along.x * 0.3 - time_val * 0.9, along.y * 1.3)));
	float caps = whitecaps * smoothstep(0.62 - whitecaps * 0.12, 0.92, crest_k) * step(0.72 - whitecaps * 0.22, streaks);
	if (psx_cel < 0.5) {
		base_color = mix(base_color, foam_color.rgb, max(foam_factor * 0.35, caps * 0.65));
	} else {
		// toon sea: the colour in three flat steps (dithered between on the PSX grid), hard white caps on
		// the crests with a dithered edge, and white contour lines riding the wave faces up close
		ivec2 bp = ivec2(mod(floor(FRAGCOORD.xy * (540.0 / VIEWPORT_SIZE.y)), 4.0));
		float b = (SEA_BAYER[bp.y * 4 + bp.x] + 0.5) / 16.0 - 0.5;
		float fs = (step(0.18 + b * 0.12, fresnel) + step(0.55 + b * 0.12, fresnel)) * 0.5;
		base_color = mix(mix(deep_color.rgb * vec3(0.85, 1.0, 1.15), shallow_color.rgb, fs), tex, 0.18);
		float cap = step(foam_threshold + 0.1 + b * 0.18, crest_k);
		base_color = mix(base_color, foam_color.rgb, max(cap * 0.8, caps * 0.75));
		float dcam = length(world_pos - CAMERA_POSITION_WORLD);
		float lines = step(0.88, fract(crest_k * 3.0 + 0.15)) * smoothstep(0.1, 0.4, crest_k) * (1.0 - smoothstep(35.0, 110.0, dcam));
		base_color = mix(base_color, foam_color.rgb, lines * 0.75);
	}
	vec2 wf = whirl_foam(wuv, time_val);
	base_color = mix(base_color, foam_color.rgb, wf.x * 0.55);
	base_color = mix(base_color, deep_color.rgb * 0.35, wf.y);
	// over shoals the sea turns turquoise, lighter toward the beach, with a
	// lacing of light on the sand and a line of surf at the very edge
	vec4 sh = shore_at(wuv);
	float sd = shoal_depth(wuv, sh);
	float sdc = sd;
	float clear = 0.0;
	if (lagoon_disc.w > 0.0) {
		clear = lagoon_disc.w * (1.0 - smoothstep(lagoon_disc.z * 0.9, lagoon_disc.z * 1.04, distance(wuv, lagoon_disc.xy)));
		if (clear > 0.0 && sh.x >= shore_none.x - 1.0) {
			sdc = lagoon_depth(wuv, sd);
		}
	}
	float shoal = 1.0 - smoothstep(0.05, 0.85, sdc);
	float lace = smoothstep(0.55, 0.95, sin(wuv.x * 0.9 + sin(wuv.y * 0.7 + time_val * 0.6) * 1.8 + time_val * 0.4) * 0.5 + 0.5);
	base_color = mix(base_color, lagoon_color.rgb * (1.0 + lace * 0.15), clear * (1.0 - shoal) * 0.9);
	base_color = mix(base_color, shoal_color.rgb * (1.0 + lace * 0.25 * shoal), shoal * 0.7);
	// surf: bands of foam on the shore swell's crests as they break in over
	// the shallows (a bright edge, a short tail; where it hasn't turned to the
	// shore, bands rolling in by depth), and at the waterline a sheet of swash
	// running up the sand as each crest arrives and draining back, in PSX blocks
	float near_shore = smoothstep(0.0, 0.03, sd) * (1.0 - smoothstep(0.12, 0.35, sd));
	float turned = clamp(sh.z * 1.6, 0.0, 1.0);
	float roll = turned > 0.0 ? shore_roll(wuv, time_val, sh) : fract(sd * 7.0 + time_val * 0.22);
	float rolled = smoothstep(0.0, 0.03, roll) * (1.0 - smoothstep(0.03, 0.11, roll));
	float surf_zone = mix(near_shore, smoothstep(0.08, 0.35, sh.x) * (1.0 - smoothstep(1.0, 2.8, sh.x)), turned);
	float band = rolled * surf_zone * step(0.45, cell_noise(floor(wuv * 2.0) + floor(time_val * 1.5)));
	float arriving = pow(0.5 + 0.5 * cos(roll * 6.2831853), 3.0);
	float reach = 0.007 + 0.014 * mix(0.5 + 0.5 * sin(time_val * 0.9 + wuv.x * 0.05 + wuv.y * 0.04), arriving, turned);
	float swash = (1.0 - smoothstep(reach * 0.5, reach, sd)) * step(0.4, cell_noise(floor(wuv * 3.0) + floor(time_val * 3.0)));
	float surf = max(band * 0.7, swash * 0.85);
	base_color = mix(base_color, foam_color.rgb, surf * 0.7);
	base_color = mix(base_color, foam_color.rgb, wake_foam(wuv, time_val) * 0.7);

	// long-range haze: by how close to the horizon you look (the sky's own
	// haze mirrored below it), only near the end of the scene fog: any nearer and
	// islands and ships (fogged by distance alone) float on a band of haze
	vec3 rel = world_pos - CAMERA_POSITION_WORLD;
	float dist = length(rel);
	float below = max(-rel.y / max(dist, 0.001), 0.0);
	float hz = 1.0 - smoothstep(0.0, max(sky_haze.a * 0.55, 0.004), below);
	hz = hz * hz * (3.0 - 2.0 * hz) * smoothstep(fog_range.y * 0.7, fog_range.y, dist);
	vec3 hc = sky_haze.rgb;
	vec3 haze_lin = mix(hc / 12.92, pow((hc + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), hc));
	ALBEDO = base_color * cloud_shade(world_pos.xz) * (1.0 - hz);
	EMISSION = haze_lin * hz;
	// the glitter path: where a wave's face mirrors the sun (or moon) to the eye, sparks flicker on in PSX blocks,
	// a few cells lit at a time and each for a beat, so it reads as a path of glints, not a smooth sheen
	if (glint_color.a > 0.001) {
		vec3 lv = normalize((VIEW_MATRIX * vec4(glint_dir, 0.0)).xyz);
		float align = dot(reflect(-VIEW, NORMAL), lv);
		float spark = cell_noise(floor(wuv * 3.2) + floor(time_val * 5.0) * 17.0);
		float glint = smoothstep(0.965, 0.995, align + (spark - 0.5) * 0.05) * step(0.62, spark);
		// (close by the cells would read as white tiles at your feet: the path shows on the water ahead)
		glint *= smoothstep(8.0, 25.0, dist);
		EMISSION += glint_color.rgb * glint * glint_color.a * (1.0 - hz) * (1.0 - surf);
	}
	// (clearer over the shoals: the sand shows through)
	// (foam is opaque white water)
	ALPHA = mix(mix(near_alpha - shoal * 0.22 - clear * (1.0 - shoal) * 0.16, 1.0, fresnel), 1.0, max(hz, max(surf, caps) * 0.7));
	// (round an atoll, outside its lagoon, deep water is opaque: the island's square of seabed down there and the open
	// sea past its edge read the same deep blue, no edge)
	ALPHA = mix(ALPHA, 1.0, lagoon_disc.w * (1.0 - clear) * smoothstep(0.45, 0.95, sdc));
	// (rough 0.5 spread the sun's reflection into pale sand-coloured sheets over
	// whole stretches of sea at some sun angles: a tighter glitter path instead)
	ROUGHNESS = 0.2;
	METALLIC = 0.0;
	SPECULAR = 0.2 * (1.0 - hz);
	// seen from under the sea (a diver's camera): the surface is a bright rippling window straight
	// overhead and, further off, a mirror of the deep (the scene fog does the distance)
	if (!FRONT_FACING) {
		if (under_sea < 0.5) {
			discard;
		}
		float up = clamp(-rel.y / max(dist, 0.001), 0.0, 1.0);
		float window = smoothstep(0.45, 0.8, up);
		float ripple = smoothstep(0.5, 0.9, tex.g + lace * 0.3);
		vec3 sky_lin = mix(haze_lin, vec3(0.75, 0.9, 1.0), 0.5);
		vec3 under = mix(deep_color.rgb * 0.6, sky_lin * 1.2, window) + ripple * window * 0.25;
		under = mix(under, foam_color.rgb, max(surf, caps) * 0.5);
		ALBEDO = vec3(0.0);
		EMISSION = under * cloud_shade(world_pos.xz);
		ALPHA = mix(0.75, 0.95, window);
		SPECULAR = 0.0;
	}
}
