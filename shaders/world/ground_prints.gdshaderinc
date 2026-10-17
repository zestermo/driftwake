// Footprints pressed into snow and sand (scripts/world/ground_layer.gd): one RGBA8 texture wrapped over
// the world every GP_SIZE / GP_PX metres. A texel: r = how deep (0 = none), g and b = when it was made
// (16 bits of quarter seconds on GroundLayer's clock), a = which wrap of the world it belongs to (4 bits
// of x and z: prints from 40 m off never show here). ground_prints_at: x = the clock now (quarter
// seconds), y = how long a print lasts (s; 0 = no prints anywhere).
global uniform sampler2D ground_prints : filter_nearest, repeat_enable;
global uniform vec4 ground_prints_at;

const float GP_PX = 12.0;
const int GP_SIZE = 512;

// 0..1 in three pixel-stepped grades (fading out over the last half of its life).
float ground_print(vec2 world_xz) {
	if (ground_prints_at.y <= 0.0) {
		return 0.0;
	}
	ivec2 px = ivec2(floor(world_xz * GP_PX));
	ivec2 tile = px >> ivec2(9);
	vec4 t = texelFetch(ground_prints, px & ivec2(GP_SIZE - 1), 0);
	int id = (tile.x & 15) | ((tile.y & 15) << 4);
	if (t.r <= 0.0 || int(round(t.a * 255.0)) != id) {
		return 0.0;
	}
	float born = round(t.g * 255.0) * 256.0 + round(t.b * 255.0);
	float age = mod(ground_prints_at.x - born + 65536.0, 65536.0) * 0.25;
	float life = ground_prints_at.y;
	float k = t.r * (1.0 - smoothstep(life * 0.5, life, age));
	return floor(k * 3.0 + 0.5) / 3.0;
}
