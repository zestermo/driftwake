// PSX-style alpha-cutout foliage: double sided, hard alpha edges, optional wind sway.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

#include "res://shaders/psx/psx_common.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap_anisotropic, repeat_disable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_vertex_color = true;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform float affine_amount : hint_range(0.0, 1.0) = 0.5;
// Sway amount in meters at model-space height `sway_height`.
uniform float wind_strength = 0.0;
uniform float sway_height = 1.0;
uniform float wind_speed = 1.6;
// Flip normals toward the light so both faces of a card shade alike.
uniform bool up_normals = true;

varying vec3 affine_uv;

void vertex() {
	if (wind_strength > 0.0) {
		vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float h = clamp(VERTEX.y / max(sway_height, 0.01), 0.0, 1.0);
		float phase = world.x * 0.13 + world.z * 0.17;
		float s = sin(TIME * wind_speed + phase) + 0.4 * sin(TIME * wind_speed * 2.3 + phase * 1.7);
		VERTEX.x += s * wind_strength * h * h;
		VERTEX.z += s * wind_strength * 0.5 * h * h;
	}
	if (up_normals) {
		NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.6));
	}
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	// Never snap in the shadow pass: the light's projection follows the camera, so
	// snapping there makes shadows pop and flicker as the player moves.
	if (!IN_SHADOW_PASS) {
		clip = psx_snap(clip, psx_snap_res);
	}
	POSITION = clip;
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, affine_amount * psx_affine_at(affine_uv.z));
	vec4 tex = texture(albedo_tex, uv);
	vec3 tint = albedo_color.rgb;
	if (use_vertex_color) {
		tint *= COLOR.rgb;
	}
	ALBEDO = tex.rgb * tint;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
