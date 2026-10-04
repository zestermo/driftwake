// Additive sword-swoosh ribbon. UV.x runs along the arc (0 = start, 1 = end),
// UV.y across it (0 = inner edge, 1 = blade tip edge). `progress` sweeps the
// bright head along the arc; the tail fades behind it.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://shaders/psx/psx_common.gdshaderinc"

uniform vec4 core_color : source_color = vec4(1.0, 1.0, 0.95, 1.0);
uniform vec4 edge_color : source_color = vec4(0.25, 0.55, 1.0, 1.0);
// Per-trail edge color (alpha 0 = use edge_color).
instance uniform vec4 edge_override : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float tail_length = 0.55;
uniform float bands = 6.0;  // PSX-style banding of the gradient
instance uniform float progress = 0.0;
instance uniform float fade = 1.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	clip = psx_snap(clip, psx_snap_res);
	POSITION = clip;
}

void fragment() {
	float head = progress;
	float along = UV.x;
	// visible between (head - tail) and head, brightest at the head
	float t = clamp((along - (head - tail_length)) / tail_length, 0.0, 1.0);
	float visible = step(along, head) * t;
	float across = pow(UV.y, 1.6);  // bright near the blade edge
	float a = visible * across * fade;
	a = floor(a * bands + 0.5) / bands;
	vec3 edge = mix(edge_color.rgb, edge_override.rgb, edge_override.a);
	vec3 col = mix(edge, core_color.rgb, smoothstep(0.75, 1.0, UV.y) * t);
	ALBEDO = col * a * 1.6;
}
