// Full-screen PS1 color treatment: 15-bit color (32 levels per channel)
// with a 4x4 ordered dither, and the low-resolution pixelation itself: the
// 3D view is sampled on a `pixel_res` grid (the PSX preset) while the UI,
// drawn above this layer, stays at the full 640x360 canvas.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float color_levels = 32.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;
uniform bool enabled = true;
uniform bool pixelate = false;
uniform vec2 pixel_res = vec2(640.0, 360.0);

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 cell = FRAGCOORD.xy;
	if (pixelate) {
		cell = floor(SCREEN_UV * pixel_res);
		uv = (cell + 0.5) / pixel_res;
	}
	vec3 c = texture(screen_tex, uv).rgb;
	if (enabled) {
		ivec2 p = ivec2(mod(cell, 4.0));
		float t = BAYER[p.y * 4 + p.x] / 16.0 - 0.5;
		float levels = max(color_levels - 1.0, 1.0);
		c += t * dither_strength / levels;
		c = floor(clamp(c, 0.0, 1.0) * levels + 0.5) / levels;
	}
	COLOR = vec4(c, 1.0);
}
