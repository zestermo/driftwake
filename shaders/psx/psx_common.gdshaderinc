// Shared PSX helpers. Values are driven globally by the PSX autoload
// (scripts/psx/psx_settings.gd) through project [shader_globals].

// Vertex snap grid in screen pixels. Smaller = wobblier.
global uniform vec2 psx_snap_res;
// 0 = perspective-correct textures, 1 = full PS1 affine warping.
global uniform float psx_affine;

// The PS1 wobble is kept up close; far away it fades out (a finer grid and
// perspective-correct textures), since distant objects that are only a few
// pixels tall turn into shimmering mush otherwise.
const float PSX_NEAR = 12.0;
const float PSX_FAR = 45.0;

float psx_far(float depth) {
	return smoothstep(PSX_NEAR, PSX_FAR, depth);
}

// How much affine (PS1) texture warp to use at a depth: none right up
// against the camera (big polygons there make textures slide around as the
// camera moves) and none far away; the global psx_affine in between.
float psx_affine_at(float depth) {
	return psx_affine * smoothstep(2.0, 7.0, depth) * (1.0 - psx_far(depth));
}

// Snap a clip-space position to a coarse screen grid (PS1 had no sub-pixel precision).
vec4 psx_snap(vec4 clip, vec2 res) {
	if (clip.w <= 0.0) {
		return clip;
	}
	vec2 ndc = clip.xy / clip.w;
	vec2 half_res = res * 0.5 * mix(1.0, 6.0, psx_far(clip.w));
	ndc = floor(ndc * half_res + 0.5) / half_res;
	clip.xy = ndc * clip.w;
	return clip;
}
