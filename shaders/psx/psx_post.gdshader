// Full-screen PS1 color treatment: 15-bit color (32 levels per channel)
// with a 4x4 ordered dither, and the low-resolution pixelation itself: the
// 3D view is sampled on a `pixel_res` grid (the PSX preset) while the UI,
// drawn above this layer, stays at the full 640x360 canvas.
// (1.31) Screen feel, local to each captain (the camera rig sets it through PSX.set_feel): a vignette
// (low health, red and pulsing), a dim (the blink of a knockdown or a big fall) and a speed smear
// (launched, dashing, falling fast: the picture streaks out from the middle). All before the
// 15-bit quantize, so they step and dither like everything else.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float color_levels = 32.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;
uniform bool enabled = true;
uniform bool pixelate = false;
uniform vec2 pixel_res = vec2(640.0, 360.0);
uniform float vignette = 0.0;
uniform vec3 vignette_color : source_color = vec3(0.55, 0.0, 0.02);
uniform float dim = 0.0;
uniform float speed = 0.0;

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
	vec2 rel = SCREEN_UV - 0.5;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(rel * vec2(aspect, 1.0));
	if (speed > 0.01) {
		// streaks out from the middle: the edges smear toward the centre, the middle stays sharp
		float k = speed * smoothstep(0.15, 0.7, r) * 0.05;
		vec3 acc = c;
		for (int i = 1; i <= 4; i++) {
			vec2 su = uv - rel * k * float(i);
			if (pixelate) {
				su = (floor(su * pixel_res) + 0.5) / pixel_res;
			}
			acc += texture(screen_tex, su).rgb;
		}
		c = acc / 5.0;
	}
	if (vignette > 0.001) {
		c = mix(c, vignette_color, smoothstep(0.32, 0.9, r) * vignette);
	}
	c *= 1.0 - dim;
	if (enabled) {
		ivec2 p = ivec2(mod(cell, 4.0));
		float t = BAYER[p.y * 4 + p.x] / 16.0 - 0.5;
		float levels = max(color_levels - 1.0, 1.0);
		c += t * dither_strength / levels;
		c = floor(clamp(c, 0.0, 1.0) * levels + 0.5) / levels;
	}
	COLOR = vec4(c, 1.0);
}
