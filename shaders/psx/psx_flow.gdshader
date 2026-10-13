// psx_lit for water that runs and shows a little of what's under it: a
// waterfall's sheet, a pool, a lava run. Seen from both sides.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled, depth_draw_opaque;

#define PSX_FLOW
#include "res://shaders/psx/psx_lit_body.gdshaderinc"
