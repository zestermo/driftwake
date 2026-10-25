// SeaSpray's foam patches (2026-10-25 GPU pass): each drifts downwind from where it was born, rides the swell (its
// height and tilt from the ocean's own wave sums, ocean_waves.gdshaderinc, whose uniforms SeaSpray copies from the
// ocean's material) and fades in and out over its life, all here: the CPU writes a patch's row once, when it's born.
// Per instance: the transform = where it was born (y 0), turned and sized; INSTANCE_CUSTOM x = born at (`now`'s
// clock), y = its life (s), zw = its drift (m/s). A slot whose life is over (or never began) is folded to nothing.
shader_type spatial;
render_mode cull_disabled, shadows_disabled, specular_disabled;

#include "res://scenes/ocean/ocean_waves.gdshaderinc"

uniform sampler2D foam_tex : source_color, filter_nearest, repeat_disable;
uniform float now = 0.0;
// the ocean's wave clock (its time_val)
uniform float time_val = 0.0;

varying float fade;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float age = now - c.x;
	float k = age / max(c.y, 0.0001);
	float on = step(0.0, age) * step(k, 1.0) * step(0.0001, c.y);
	vec2 p = MODEL_MATRIX[3].xz + c.zw * age;
	float h = wave_h(p, time_val, 0.0, shore_at(p));
	float e = 0.1;
	float hx = wave_h(p + vec2(e, 0.0), time_val, 0.0, shore_at(p + vec2(e, 0.0)));
	float hz = wave_h(p + vec2(0.0, e), time_val, 0.0, shore_at(p + vec2(0.0, e)));
	vec3 n = normalize(vec3(h - hx, e, h - hz));
	// the quad laid flat (its x, -y), turned and sized as its instance says, then onto the swell's slope there
	vec3 o = mat3(MODEL_MATRIX) * vec3(VERTEX.x, 0.0, -VERTEX.y);
	o.y = -(n.x * o.x + n.z * o.z) / n.y;
	vec3 world = vec3(p.x, h + 0.05, p.y) + o * on;
	mat4 inv = inverse(MODEL_MATRIX);
	VERTEX = (inv * vec4(world, 1.0)).xyz;
	NORMAL = normalize(mat3(inv) * n);
	fade = clamp(min(k * 4.0, (1.0 - k) * 2.5), 0.0, 1.0) * on;
}

void fragment() {
	vec4 t = texture(foam_tex, UV);
	ALBEDO = t.rgb * vec3(0.9, 0.94, 0.96);
	ALPHA = t.a * fade;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
}
