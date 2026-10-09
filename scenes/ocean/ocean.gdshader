// PSX ocean. Wave math MUST stay in sync with OceanManager.get_wave_height
// (scripts/ocean/ocean_manager.gd): swimmers, the ship and enemies float on it.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_lambert, specular_schlick_ggx;

#include "res://shaders/psx/psx_common.gdshaderinc"
#include "res://shaders/world/cloud_shadow.gdshaderinc"

uniform vec4 deep_color : source_color = vec4(0.05, 0.16, 0.3, 0.95);
uniform vec4 shallow_color : source_color = vec4(0.2, 0.5, 0.6, 0.8);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform sampler2D water_tex : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform float water_tex_scale = 0.14;
uniform vec2 water_scroll = vec2(0.02, 0.012);

// The swell (pushed by OceanManager._send_waves from its WAVES table):
// per wave [dir.x, dir.y, k, omega] and [amplitude, phase].
uniform vec4 waves[6];
uniform vec2 wave_amp_phase[6];
uniform float amp_mult = 1.0;
// Storm cells at sea (OceanManager.storm_cells): x, z, radius, extra swell.
uniform vec4 storm_cells[2];
// Whirlpools (OceanManager.whirls): x, z, radius, funnel depth.
uniform vec4 whirls[2];

// The funnel a whirlpool drags the sea down into (same as OceanManager.funnel).
float funnel(vec2 p) {
	float f = 0.0;
	for (int i = 0; i < 2; i++) {
		vec4 w = whirls[i];
		float k = 1.0 - smoothstep(0.0, max(w.z, 0.001), distance(p, w.xy));
		f -= w.w * k * k;
	}
	return f;
}

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

// Turquoise shallows (WorldGenerator.bake_shallows): the seabed's depth here,
// 0 at the waterline to 1 at OceanManager.SHOAL_DEPTH and below.
uniform sampler2D shoal_map : filter_linear, repeat_disable, hint_default_white;
uniform vec4 shoal_rect = vec4(0.0);
uniform sampler2D shoal_fine : filter_linear, repeat_disable, hint_default_white;
uniform vec4 fine_rect = vec4(0.0);
// the chain's islands built just now (OceanManager.isle_shoals, two at most)
uniform sampler2D shoal_isle0 : filter_linear, repeat_disable, hint_default_white;
uniform vec4 isle_rect0 = vec4(0.0);
uniform sampler2D shoal_isle1 : filter_linear, repeat_disable, hint_default_white;
uniform vec4 isle_rect1 = vec4(0.0);
uniform vec4 shoal_color : source_color = vec4(0.16, 0.72, 0.66, 1.0);

float shoal_depth(vec2 p) {
	vec2 fu = (p - fine_rect.xy) / max(fine_rect.z, 0.001);
	if (fine_rect.w > 0.5 && fu.x > 0.0 && fu.y > 0.0 && fu.x < 1.0 && fu.y < 1.0) {
		return texture(shoal_fine, fu).r;
	}
	vec2 iu = (p - isle_rect0.xy) / max(isle_rect0.z, 0.001);
	if (isle_rect0.w > 0.5 && iu.x > 0.0 && iu.y > 0.0 && iu.x < 1.0 && iu.y < 1.0) {
		return texture(shoal_isle0, iu).r;
	}
	iu = (p - isle_rect1.xy) / max(isle_rect1.z, 0.001);
	if (isle_rect1.w > 0.5 && iu.x > 0.0 && iu.y > 0.0 && iu.x < 1.0 && iu.y < 1.0) {
		return texture(shoal_isle1, iu).r;
	}
	vec2 u = (p - shoal_rect.xy) / max(shoal_rect.z, 0.001);
	if (shoal_rect.w > 0.5 && u.x > 0.0 && u.y > 0.0 && u.x < 1.0 && u.y < 1.0) {
		return texture(shoal_map, u).r;
	}
	return 1.0;
}
uniform float wave_total = 1.38;
uniform vec2 crest = vec2(2.0, 0.75);
uniform vec4 env_dirs = vec4(0.019, 0.011, -0.008, 0.016);
uniform vec3 env_params = vec3(0.22, 0.05, 0.037);
uniform vec2 crest_cap = vec2(0.85, 0.4);
uniform float near_half = 120.0;
uniform float growth = 0.08;

uniform float fresnel_power = 3.0;
uniform float foam_threshold = 0.6;
// Whitecaps (Weather: with the wind and storms, 0..1) streaked along the wind.
uniform float whitecaps = 0.0;
uniform vec2 wind_dir = vec2(1.0, 0.0);
uniform float time_val = 0.0;
uniform float near_alpha = 0.82;
// The horizon haze (Weather): rgb = the fog colour (sRGB), a = how far up the
// sky it reaches. Toward the horizon the sea melts into the same colour the
// sky does just above it, so there is no line where the sea stops.
global uniform vec4 sky_haze;
// The scene's depth fog (Weather): begin, end in metres.
global uniform vec2 fog_range;

varying float wave_height_val;
varying vec3 world_pos;
varying vec3 affine_w;

// Height of the swell at p. `cell` is the mesh spacing there: waves too short
// for the grid to draw fade out (far away) instead of turning into noise.
float wave_h(vec2 p, float t, float cell) {
	float h = 0.0;
	for (int i = 0; i < 6; i++) {
		vec4 w = waves[i];
		float lam = 6.2831853 / max(w.z, 0.0001);
		float keep = 1.0 - smoothstep(lam * 0.25, lam * 0.5, cell);
		float s = sin(dot(p, w.xy) * w.z + t * w.w + wave_amp_phase[i].y);
		h += wave_amp_phase[i].x * (2.0 * pow(max(0.5 + 0.5 * s, 0.0), crest.x) - crest.y) * keep;
	}
	float env = 1.0 + env_params.x * sin(dot(p, env_dirs.xy) + t * env_params.y) * sin(dot(p, env_dirs.zw) - t * env_params.z);
	h *= env;
	if (h > crest_cap.x) {
		float e = h - crest_cap.x;
		h = crest_cap.x + e / (1.0 + e / crest_cap.y);
	}
	float swell = 1.0;
	for (int i = 0; i < 2; i++) {
		vec4 c = storm_cells[i];
		swell += c.w * (1.0 - smoothstep(c.z * 0.35, max(c.z, 0.001), distance(p, c.xy)));
	}
	return h * amp_mult * swell;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// the graded grid: 1 m cells within near_half of its centre, then growing
	float d = max(abs(VERTEX.x), abs(VERTEX.z));
	float cell = d <= near_half ? 1.0 : 1.25 + growth * (d - near_half);

	float h = wave_h(world_pos.xz, time_val, cell);
	float fu = funnel(world_pos.xz);
	VERTEX.y += h + fu;
	wave_height_val = h;

	float eps = 0.25;
	float dx = (wave_h(world_pos.xz + vec2(eps, 0.0), time_val, cell) + funnel(world_pos.xz + vec2(eps, 0.0)) - h - fu) / eps;
	float dz = (wave_h(world_pos.xz + vec2(0.0, eps), time_val, cell) + funnel(world_pos.xz + vec2(0.0, eps)) - h - fu) / eps;
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
	base_color = mix(base_color, foam_color.rgb, max(foam_factor * 0.35, caps * 0.65));
	vec2 wf = whirl_foam(wuv, time_val);
	base_color = mix(base_color, foam_color.rgb, wf.x * 0.55);
	base_color = mix(base_color, deep_color.rgb * 0.35, wf.y);
	// over shoals the sea turns turquoise, lighter toward the beach, with a
	// lacing of light on the sand and a line of surf at the very edge
	float sd = shoal_depth(wuv);
	float shoal = 1.0 - smoothstep(0.05, 0.85, sd);
	float lace = smoothstep(0.55, 0.95, sin(wuv.x * 0.9 + sin(wuv.y * 0.7 + time_val * 0.6) * 1.8 + time_val * 0.4) * 0.5 + 0.5);
	base_color = mix(base_color, shoal_color.rgb * (1.0 + lace * 0.25 * shoal), shoal * 0.7);
	// surf rolling in: bands of foam riding in over the shallows toward the
	// beach (a bright leading edge, a short tail), and at the waterline a
	// sheet of swash running up the sand and draining back, in PSX blocks
	float near_shore = smoothstep(0.0, 0.03, sd) * (1.0 - smoothstep(0.12, 0.35, sd));
	float roll = fract(sd * 7.0 + time_val * 0.22);
	float band = smoothstep(0.0, 0.03, roll) * (1.0 - smoothstep(0.03, 0.11, roll));
	band *= near_shore * step(0.45, cell_noise(floor(wuv * 2.0) + floor(time_val * 1.5)));
	float reach = 0.009 + 0.016 * (0.5 + 0.5 * sin(time_val * 0.9 + wuv.x * 0.05 + wuv.y * 0.04));
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
	// (clearer over the shoals: the sand shows through)
	// (foam is opaque white water)
	ALPHA = mix(mix(near_alpha - shoal * 0.22, 1.0, fresnel), 1.0, max(hz, max(surf, caps) * 0.7));
	// (rough 0.5 spread the sun's reflection into pale sand-coloured sheets over
	// whole stretches of sea at some sun angles: a tighter glitter path instead)
	ROUGHNESS = 0.2;
	METALLIC = 0.0;
	SPECULAR = 0.2 * (1.0 - hz);
}
