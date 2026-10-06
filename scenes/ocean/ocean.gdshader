// PSX ocean. Wave math MUST stay in sync with OceanManager.get_wave_height
// (scripts/ocean/ocean_manager.gd): swimmers, the ship and enemies float on it.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_lambert, specular_schlick_ggx;

#include "res://shaders/psx/psx_common.gdshaderinc"
#include "res://shaders/world/cloud_shadow.gdshaderinc"

uniform vec4 deep_color : source_color = vec4(0.02, 0.08, 0.22, 0.95);
uniform vec4 shallow_color : source_color = vec4(0.08, 0.35, 0.45, 0.8);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform sampler2D water_tex : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform float water_tex_scale = 0.08;
uniform vec2 water_scroll = vec2(0.02, 0.012);

// The swell (pushed by OceanManager._send_waves from its WAVES table):
// per wave [dir.x, dir.y, k, omega] and [amplitude, phase].
uniform vec4 waves[6];
uniform vec2 wave_amp_phase[6];
uniform float amp_mult = 1.0;
uniform float wave_total = 1.38;
uniform vec2 crest = vec2(2.0, 0.75);
uniform vec4 env_dirs = vec4(0.019, 0.011, -0.008, 0.016);
uniform vec3 env_params = vec3(0.22, 0.05, 0.037);
uniform vec2 crest_cap = vec2(0.85, 0.4);
uniform float near_half = 120.0;
uniform float growth = 0.08;

uniform float fresnel_power = 3.0;
uniform float foam_threshold = 0.6;
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
	return h * amp_mult;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// the graded grid: 1 m cells within near_half of its centre, then growing
	float d = max(abs(VERTEX.x), abs(VERTEX.z));
	float cell = d <= near_half ? 1.0 : 1.25 + growth * (d - near_half);

	float h = wave_h(world_pos.xz, time_val, cell);
	VERTEX.y += h;
	wave_height_val = h;

	float eps = 0.25;
	float dx = (wave_h(world_pos.xz + vec2(eps, 0.0), time_val, cell) - h) / eps;
	float dz = (wave_h(world_pos.xz + vec2(0.0, eps), time_val, cell) - h) / eps;
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

	float foam_factor = smoothstep(foam_threshold, foam_threshold + 0.3, wave_height_val / max(wave_total, 0.01));
	base_color = mix(base_color, foam_color.rgb, foam_factor * 0.35);

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
	ALPHA = mix(mix(near_alpha, 1.0, fresnel), 1.0, hz);
	// (rough 0.5 spread the sun's reflection into pale sand-coloured sheets over
	// whole stretches of sea at some sun angles: a tighter glitter path instead)
	ROUGHNESS = 0.2;
	METALLIC = 0.0;
	SPECULAR = 0.2 * (1.0 - hz);
}
