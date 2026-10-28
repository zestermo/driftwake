// Edy aura's ground circle (Reinforce, EdyAura): a flat disc under the captain's feet in the type's shape:
// 0 haze (Still: mist pooling), 1 flame (Ember: a burning ring), 2 shimmer (Crown: a gold sigil turning),
// 3 lightning (Storm: lit cracks), 4 swirl (Tide: a whirlpool). Added on top of the ground.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.42, 0.66, 1.0, 1.0);
uniform int look = 0;
uniform float strength = 1.0;
uniform float bands = 4.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float t = TIME;
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float a = 0.0;
	if (look == 0) {
		a = (1.0 - smoothstep(0.3, 1.0, r)) * (0.4 + 0.6 * noise(p * 3.0 + vec2(t * 0.3, -t * 0.2))) * 0.8;
	} else if (look == 1) {
		float ring = 1.0 - smoothstep(0.0, 0.12, abs(r - 0.78 - 0.06 * noise(vec2(ang * 3.0, t * 3.0))));
		a = ring * (0.6 + 0.4 * noise(vec2(ang * 8.0, t * 6.0))) + (1.0 - smoothstep(0.0, 0.75, r)) * 0.18;
	} else if (look == 2) {
		float ring = 1.0 - smoothstep(0.0, 0.05, abs(r - 0.82));
		float inner = 1.0 - smoothstep(0.0, 0.04, abs(r - 0.55));
		float spokes = step(0.85, sin(ang * 8.0 + t * 1.2) * 0.5 + 0.5) * step(0.55, r) * step(r, 0.82);
		a = ring + inner * 0.7 + spokes * 0.6;
	} else if (look == 3) {
		float crack = 1.0 - smoothstep(0.0, 0.05, abs(noise(vec2(ang * 2.5, r * 4.0)) - 0.5));
		float flick = step(0.35, hash(vec2(floor(t * 10.0), 2.0)));
		a = crack * (1.0 - smoothstep(0.5, 1.0, r)) * (0.5 + 0.5 * flick) * 1.4;
	} else {
		float sw = sin(ang * 3.0 + r * 9.0 - t * 5.0) * 0.5 + 0.5;
		a = smoothstep(0.55, 0.95, sw) * (1.0 - smoothstep(0.6, 1.0, r)) * smoothstep(0.1, 0.3, r);
	}
	a = clamp(a * strength, 0.0, 1.0) * (1.0 - smoothstep(0.92, 1.0, r));
	a = floor(a * bands + 0.5) / bands;
	ALBEDO = color.rgb * a;
}
