// An unshaded flipbook mark on a surface (telegraphs, poison puddles): see psx_decal_body.gdshaderinc.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

#define PSX_DECAL_UNSHADED
#define PSX_DECAL_SHEET
#include "res://shaders/psx/psx_decal_body.gdshaderinc"
