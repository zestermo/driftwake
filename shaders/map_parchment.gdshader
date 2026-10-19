shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;
// The held map's sheet (MapHold): the page drawn on it (a SubViewport for our own captain, a sketch
// for a crewmate's), unrolled from the right-hand roll as `open` goes 0..1: the sheet's mesh spans
// x -half..half, the part showing reaches from the right roll to half - 2 half open, and shows the
// page's right-hand part (what's unrolled first). PSX vertex snap; lit, with a little of its own
// light so it reads by night.

#include "res://shaders/psx/psx_common.gdshaderinc"

uniform sampler2D page : source_color, filter_nearest, repeat_disable;
uniform vec4 paper : source_color = vec4(0.86, 0.78, 0.6, 1.0);
uniform float open : hint_range(0.0, 1.0) = 1.0;
uniform float half_w = 0.3;
uniform float glow = 0.15;
// The page's ink and paper as the sheet's own yellowed stock.
uniform vec4 stock : source_color = vec4(1.0, 0.93, 0.76, 1.0);

void vertex() {
	VERTEX.x = half_w - (half_w - VERTEX.x) * open;
	UV.x = 1.0 - (1.0 - UV.x) * open;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (!IN_SHADOW_PASS) {
		clip = psx_snap(clip, psx_snap_res);
	}
	POSITION = clip;
}

void fragment() {
	vec3 c = paper.rgb;
	if (FRONT_FACING) {
		vec4 t = texture(page, UV);
		c = mix(c, t.rgb * stock.rgb, t.a);
		// the sheet's edges browned with handling
		vec2 e = min(UV, 1.0 - UV);
		c *= mix(0.78, 1.0, smoothstep(0.0, 0.035, min(e.x * 0.6, e.y)));
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	EMISSION = c * glow;
}
