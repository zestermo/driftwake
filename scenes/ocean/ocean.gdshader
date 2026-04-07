shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

uniform vec4 deep_color : source_color = vec4(0.02, 0.08, 0.22, 0.95);
uniform vec4 shallow_color : source_color = vec4(0.08, 0.35, 0.45, 0.8);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);

uniform float wave_amplitude = 0.8;
uniform float wave_frequency = 0.8;
uniform float wave_speed = 1.5;
uniform vec2 wave_direction = vec2(0.857, 0.514);

uniform float wave2_amplitude = 0.3;
uniform float wave2_frequency = 1.5;
uniform float wave2_speed = 0.8;
uniform vec2 wave2_direction = vec2(-0.573, 0.819);

uniform float fresnel_power = 3.0;
uniform float foam_threshold = 0.6;
uniform float time_val = 0.0;

varying float wave_height_val;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float d1 = dot(world_pos.xz, normalize(wave_direction));
	float d2 = dot(world_pos.xz, normalize(wave2_direction));

	float h1 = sin(d1 * wave_frequency + time_val * wave_speed) * wave_amplitude;
	float h2 = sin(d2 * wave2_frequency + time_val * wave2_speed) * wave2_amplitude;
	float h = h1 + h2;

	VERTEX.y += h;
	wave_height_val = h;

	// Finite difference normal
	float eps = 0.2;
	float hx1 = sin((d1 + eps * normalize(wave_direction).x * wave_frequency) + time_val * wave_speed) * wave_amplitude;
	float hx2 = sin((d2 + eps * normalize(wave2_direction).x * wave2_frequency) + time_val * wave2_speed) * wave2_amplitude;
	float hz1 = sin((d1 + eps * normalize(wave_direction).y * wave_frequency) + time_val * wave_speed) * wave_amplitude;
	float hz2 = sin((d2 + eps * normalize(wave2_direction).y * wave2_frequency) + time_val * wave2_speed) * wave2_amplitude;

	float dx = ((hx1 + hx2) - h) / eps;
	float dz = ((hz1 + hz2) - h) / eps;

	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);

	vec3 base_color = mix(deep_color.rgb, shallow_color.rgb, fresnel);

	// Foam on wave peaks
	float foam_factor = smoothstep(foam_threshold, foam_threshold + 0.3, wave_height_val / (wave_amplitude + wave2_amplitude));
	base_color = mix(base_color, foam_color.rgb, foam_factor * 0.4);

	ALBEDO = base_color;
	ALPHA = mix(deep_color.a, 1.0, fresnel);
	ROUGHNESS = 0.05;
	METALLIC = 0.0;
	SPECULAR = 0.9;
}
