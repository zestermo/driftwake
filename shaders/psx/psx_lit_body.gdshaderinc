// The PSX lit surface (psx_lit.gdshader, and psx_lit_fade.gdshader with
// PSX_FADE defined: the same surface dissolving in a 4x4 dither).
#include "res://shaders/psx/psx_common.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform bool use_vertex_color = true;
// Decal mode: texture alpha blends texture over the tint color (used for faces).
uniform bool decal_mode = false;
uniform float affine_amount : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D emission_tex : source_color, filter_nearest, hint_default_black;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 1.0;
uniform float emission_pulse = 0.0;
// Tint multiplier (hit flashes). A regular uniform, not an instance uniform:
// renderers cap how many instances may use instance uniforms (each reserves
// 16 slots), which a village full of characters and props would exceed.
// Objects that flash use their own material copies (see dummy_target.gd).
uniform vec4 tint_mul : source_color = vec4(1.0);
// Pull the surface toward the camera (metres, growing with distance): hair
// sits a couple of centimetres off the scalp, and far away vertex snapping +
// depth precision let the scalp poke through without this.
uniform float depth_pull = 0.0;
#ifdef PSX_FADE
// 0 = gone .. 1 = solid.
uniform float fade : hint_range(0.0, 1.0) = 1.0;
const float BAYER4[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
#endif

varying vec3 affine_uv;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (depth_pull > 0.0 && !IN_SHADOW_PASS) {
		float dd = -view.z;
		view.xyz -= normalize(view.xyz) * depth_pull * clamp(dd / 5.0, 0.6, 5.0);
	}
	vec4 clip = PROJECTION_MATRIX * view;
	// Never snap in the shadow pass: the light's projection follows the camera, so
	// snapping there makes shadows pop and flicker as the player moves.
	if (!IN_SHADOW_PASS) {
		clip = psx_snap(clip, psx_snap_res);
	}
	POSITION = clip;
	affine_uv = vec3(UV * uv_scale * clip.w, clip.w);
}

void fragment() {
#ifdef PSX_FADE
	ivec2 cell = ivec2(mod(FRAGCOORD.xy, 4.0));
	if (fade < (BAYER4[cell.y * 4 + cell.x] + 0.5) / 16.0) {
		discard;
	}
#endif
	vec2 uv_persp = UV * uv_scale;
	vec2 uv_aff = affine_uv.xy / affine_uv.z;
	vec2 uv = mix(uv_persp, uv_aff, affine_amount * psx_affine_at(affine_uv.z));

	vec4 tex = texture(albedo_tex, uv);
	vec3 tint = albedo_color.rgb;
	if (use_vertex_color) {
		tint *= COLOR.rgb;
	}
	vec3 col;
	if (decal_mode) {
		col = mix(tint, tex.rgb, tex.a);
	} else {
		col = tex.rgb * tint;
	}
	ALBEDO = col * tint_mul.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;

	vec3 em = texture(emission_tex, uv).rgb * emission_color.rgb;
	float pulse = 1.0 + sin(TIME * 2.0) * emission_pulse;
	EMISSION = em * emission_energy * pulse;
}
