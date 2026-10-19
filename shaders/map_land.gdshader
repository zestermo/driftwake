shader_type canvas_item;
// The held map's island page (MapIsleView): the land from the island's heights (UV 0..1 over its
// height grid) inked like a sea chart, or with fog_pass the fog of war over what the crew hasn't seen.
// Hard-edged on purpose: every line is a whole page pixel, no smoothing.

uniform sampler2D heights : filter_linear_mipmap, repeat_disable;
uniform sampler2D fog : filter_linear, repeat_disable;
uniform bool fog_pass = false;
// On the sea chart: the sea left as the chart's own paper, only the land and its shore drawn.
uniform bool sea_clear = false;
// The height grid's cells a side (the texture is one more), the island's metres a side,
// and the fog's share of that: the fog grid is a little bigger than the height grid.
uniform float cells = 260.0;
uniform float extent = 780.0;
uniform float fog_k = 1.0;
uniform float contour = 6.0;
uniform vec4 paper : source_color = vec4(0.91, 0.84, 0.68, 1.0);
uniform vec4 ink : source_color = vec4(0.3, 0.2, 0.12, 1.0);
uniform vec4 shallow : source_color = vec4(0.7, 0.76, 0.7, 1.0);
uniform vec4 deep : source_color = vec4(0.56, 0.64, 0.64, 1.0);
uniform vec4 low : source_color = vec4(0.82, 0.73, 0.52, 1.0);
uniform vec4 high : source_color = vec4(0.62, 0.52, 0.36, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 m = UV * extent;
	if (fog_pass) {
		float f = texture(fog, UV * fog_k).r;
		float v = f + (vnoise(m / 10.0) * 0.65 + vnoise(m / 3.5) * 0.35 - 0.5) * 0.6;
		if (v > 0.5) {
			discard;
		}
		// blank paper where nobody's been, a band of hatching and an inked edge where the known ends
		vec2 px = floor(FRAGCOORD.xy);
		vec3 c = paper.rgb;
		if (v > 0.45) {
			c = mix(paper.rgb, ink.rgb, 0.6);
		} else if (v > 0.36 && mod(px.x + px.y, 3.0) < 1.0) {
			c = mix(paper.rgb, ink.rgb, 0.3);
		}
		COLOR = vec4(c, 1.0);
	} else {
		float h = texture(heights, (UV * cells + 0.5) / (cells + 1.0)).r;
		float w = fwidth(h);
		vec3 c;
		if (sea_clear) {
			// the chart's few pixels an island: flat land by height, an inked edge
			if (h < 0.0) {
				discard;
			}
			c = h < max(w, 1.5) ? ink.rgb : mix(low.rgb, high.rgb, clamp(h / 40.0, 0.0, 1.0));
		} else if (h < 0.0) {
			float band = floor(clamp(-h / 5.0, 0.0, 2.0));
			c = mix(shallow.rgb, deep.rgb, band * 0.5);
			// a dotted ring of shallows off the shore
			if (abs(h + 1.5) < w * 0.6 && mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 3.0) < 1.0) {
				c = mix(c, ink.rgb, 0.4);
			}
		} else {
			float band = floor(h / contour);
			c = mix(low.rgb, high.rgb, clamp(band / 7.0, 0.0, 1.0));
			if (abs(fract(h / contour + 0.5) - 0.5) * contour < w * 0.75 && h > contour * 0.5) {
				c = mix(c, ink.rgb, 0.35);
			}
		}
		if (!sea_clear && abs(h) < w * 1.1) {
			c = ink.rgb;
		}
		COLOR = vec4(c, 1.0);
	}
}
