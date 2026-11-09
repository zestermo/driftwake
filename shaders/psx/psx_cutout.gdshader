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

// The weather's wind (Weather sets wind_vec every frame: dir x/z, strength 0 calm .. ~1.4 a storm)
global uniform vec4 wind_vec;

varying vec3 affine_uv;

void vertex() {
	if (up_normals) {
		NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.6));
	}
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (wind_strength > 0.0) {
		// Foliage leans downwind by how hard it blows, gusts roll across
		// the island as bands moving downwind, and the leaves flutter faster in a blow
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vec2 wd = wind_vec.xy;
		float ws = wind_vec.z;
		float h = clamp(VERTEX.y / max(sway_height, 0.01), 0.0, 1.0);
		float gust = 0.5 + 0.5 * sin(dot(root.xz, wd) * 0.09 - TIME * (1.0 + ws * 1.4));
		gust *= gust;
		float ph = root.x * 0.13 + root.z * 0.17;
		float flutter = sin(TIME * (wind_speed * 1.4 + ws * 3.5) + ph * 3.0) + 0.4 * sin(TIME * (wind_speed * 3.1 + ws * 5.0) + ph * 5.1);
		float lean = ws * (0.5 + 1.3 * gust);
		vec3 d = vec3(wd.x, 0.0, wd.y) * (lean + flutter * (0.15 + 0.35 * ws)) + vec3(-wd.y, 0.0, wd.x) * flutter * 0.2;
		wp += d * wind_strength * 4.0 * h * h;
		wp.y -= lean * wind_strength * 1.2 * h * h * h;
		clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(wp, 1.0));
	}
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

#include "res://shaders/psx/psx_cel.gdshaderinc"
