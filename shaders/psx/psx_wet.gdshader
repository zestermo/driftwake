// The PSX lit surface with a wet sheen (the Sea King's hide): a tight specular
// highlight and a cold rim catching the sky.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_back;

#define PSX_WET
#include "res://shaders/psx/psx_lit_body.gdshaderinc"
