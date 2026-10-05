// PSX ocean. Wave math MUST stay in sync with scripts/ocean/ocean_manager.gd
// (the ship's buoyancy samples the same two sine waves).
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_lambert, specular_schlick_ggx;

#include "res://shaders/psx/psx_common.gdshaderinc"

uniform vec4 deep_color : source_color = vec4(0.02, 0.08, 0.22, 0.95);
uniform vec4 shallow_color : source_color = vec4(0.08, 0.35, 0.45, 0.8);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform sampler2D water_tex : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform float water_tex_scale = 0.08;
uniform vec2 water_scroll = vec2(0.02, 0.012);

uniform float wave_amplitude = 0.8;
uniform float wave_frequency = 0.8;
uniform float wave_speed = 1.5;
uniform vec2 wave_direction = vec2(0.857, 0.514);

uniform float wave2_amplitude = 0.3;
uniform float wave2_frequency = 1.5;
uniform float wave2_speed = 0.8;
uniform vec2 wave2_direction = vec2(-0.573, 0.819);

uniform float fresnel_power = 3.0;
uniform float foam_threshold = 0.6;
uniform float time_val = 0.0;
uniform float near_alpha = 0.82;

varying float wave_height_val;
varying vec3 world_pos;
varying vec3 affine_w;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float d1 = dot(world_pos.xz, normalize(wave_direction));
	float d2 = dot(world_pos.xz, normalize(wave2_direction));

	float h1 = sin(d1 * wave_frequency + time_val * wave_speed) * wave_amplitude;
	float h2 = sin(d2 * wave2_frequency + time_val * wave2_speed) * wave2_amplitude;
	float h = h1 + h2;

	VERTEX.y += h;
	wave_height_val = h;

	float eps = 0.2;
	float hx1 = sin((d1 + eps * normalize(wave_direction).x * wave_frequency) + time_val * wave_speed) * wave_amplitude;
	float hx2 = sin((d2 + eps * normalize(wave2_direction).x * wave2_frequency) + time_val * wave2_speed) * wave2_amplitude;
	float hz1 = sin((d1 + eps * normalize(wave_direction).y * wave_frequency) + time_val * wave_speed) * wave_amplitude;
	float hz2 = sin((d2 + eps * normalize(wave2_direction).y * wave2_frequency) + time_val * wave2_speed) * wave2_amplitude;
	float dx = ((hx1 + hx2) - h) / eps;
	float dz = ((hz1 + hz2) - h) / eps;
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

	float foam_factor = smoothstep(foam_threshold, foam_threshold + 0.3, wave_height_val / (wave_amplitude + wave2_amplitude));
	base_color = mix(base_color, foam_color.rgb, foam_factor * 0.35);

	ALBEDO = base_color;
	ALPHA = mix(near_alpha, 1.0, fresnel);
	ROUGHNESS = 0.5;
	METALLIC = 0.0;
	SPECULAR = 0.3;
}
