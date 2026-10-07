// PSX-style lit surface: vertex snapping, affine texture warp, nearest-filtered
// textures, vertex-color tint, flat specular-free lighting.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

#include "res://shaders/psx/psx_lit_body.gdshaderinc"
