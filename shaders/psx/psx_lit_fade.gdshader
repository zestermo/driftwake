// psx_lit, dissolving in and out in a dithered pattern (`fade`): a summoned
// ship appearing. Only swapped onto things while they fade (the discard would
// cost every opaque PSX surface otherwise).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

#define PSX_FADE
#include "res://shaders/psx/psx_lit_body.gdshaderinc"
