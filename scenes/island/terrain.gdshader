shader_type spatial;
render_mode cull_back;

uniform float water_level = 0.0;
uniform float sand_height : hint_range(-5.0, 20.0) = 3.0;
uniform float grass_height : hint_range(-5.0, 30.0) = 12.0;
uniform float rock_height : hint_range(-5.0, 40.0) = 20.0;

uniform vec4 seafloor_color : source_color = vec4(0.08, 0.15, 0.12, 1.0);
uniform vec4 sand_color : source_color = vec4(0.76, 0.70, 0.50, 1.0);
uniform vec4 grass_color : source_color = vec4(0.22, 0.40, 0.15, 1.0);
uniform vec4 rock_color : source_color = vec4(0.40, 0.38, 0.35, 1.0);
uniform vec4 snow_color : source_color = vec4(0.90, 0.90, 0.88, 1.0);

uniform float slope_threshold : hint_range(0.0, 1.0) = 0.55;

varying float height;
varying vec3 world_normal;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	height = world_pos.y;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	float slope = 1.0 - dot(normalize(world_normal), vec3(0.0, 1.0, 0.0));

	// Determine blend factors based on height
	float underwater_f = 1.0 - smoothstep(water_level - 2.0, water_level, height);
	float sand_f = smoothstep(water_level - 0.5, water_level + 1.0, height) * (1.0 - smoothstep(sand_height - 1.0, sand_height + 1.0, height));
	float grass_f = smoothstep(sand_height - 1.0, sand_height + 1.0, height) * (1.0 - smoothstep(grass_height - 2.0, grass_height + 2.0, height));
	float rock_f = smoothstep(grass_height - 2.0, grass_height + 2.0, height) * (1.0 - smoothstep(rock_height - 2.0, rock_height + 2.0, height));
	float snow_f = smoothstep(rock_height - 2.0, rock_height + 2.0, height);

	vec3 col = seafloor_color.rgb * underwater_f
			 + sand_color.rgb * sand_f
			 + grass_color.rgb * grass_f
			 + rock_color.rgb * rock_f
			 + snow_color.rgb * snow_f;

	// Steep slopes get rock regardless of height (but only above water)
	if (height > water_level + 1.0) {
		float rock_slope = smoothstep(slope_threshold - 0.1, slope_threshold + 0.1, slope);
		col = mix(col, rock_color.rgb, rock_slope * 0.7);
	}

	ALBEDO = col;
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
}
