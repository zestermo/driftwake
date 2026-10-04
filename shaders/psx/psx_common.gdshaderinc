// Shared PSX helpers. Values are driven globally by the PSX autoload
// (scripts/psx/psx_settings.gd) through project [shader_globals].

// Vertex snap grid in screen pixels. Smaller = wobblier.
global uniform vec2 psx_snap_res;
// 0 = perspective-correct textures, 1 = full PS1 affine warping.
global uniform float psx_affine;

// Snap a clip-space position to a coarse screen grid (PS1 had no sub-pixel precision).
vec4 psx_snap(vec4 clip, vec2 res) {
	if (clip.w <= 0.0) {
		return clip;
	}
	vec2 ndc = clip.xy / clip.w;
	vec2 half_res = res * 0.5;
	ndc = floor(ndc * half_res + 0.5) / half_res;
	clip.xy = ndc * clip.w;
	return clip;
}
