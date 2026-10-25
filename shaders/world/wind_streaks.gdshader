// SeaSpray's wind streaks (2026-10-25 GPU pass): each one flies on along the wind, turned edge-on to the camera
// round its own line, and brightens then fades over its life, all here. The CPU writes a streak's instance once,
// when it's born (SeaSpray._streak), and sets `now` (its own clock) once a frame.
// Per instance: the transform's origin = where it was born, basis x = its direction times its length, basis y's
// length = its width; INSTANCE_CUSTOM x = born at (`now`'s clock), y = its life (s), z = its speed (m/s). A slot
// whose life is over (or never began) is folded to nothing.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform sampler2D streak : source_color, filter_nearest, repeat_disable;
uniform float now = 0.0;

varying float fade;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 x = MODEL_MATRIX[0].xyz;
	float w = length(MODEL_MATRIX[1].xyz);
	float age = now - c.x;
	float k = age / max(c.y, 0.0001);
	float on = step(0.0, age) * step(k, 1.0) * step(0.0001, c.y);
	vec3 d = normalize(x);
	vec3 p = o + d * c.z * age;
	vec3 side = normalize(cross(d, normalize(CAMERA_POSITION_WORLD - p)));
	vec3 world = p + (x * VERTEX.x + side * w * VERTEX.y) * on;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	fade = 0.4 * sin(3.14159265 * clamp(k, 0.0, 1.0)) * on;
}

void fragment() {
	vec4 t = texture(streak, UV);
	ALBEDO = t.rgb;
	ALPHA = t.a * fade;
}
