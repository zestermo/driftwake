// The swell's height, shared by ocean.gdshader and tools/dev/shoreprobe.gd. It MUST stay in sync
// with OceanManager._height (scripts/ocean/ocean_manager.gd): swimmers, the ship and enemies float on it.

// The open swell (OceanManager._send_waves from its WAVES table):
// per wave [dir.x, dir.y, k, omega] and [amplitude, phase].
uniform vec4 waves[6];
uniform vec2 wave_amp_phase[6];
uniform float amp_mult = 1.0;
// Storm cells at sea (OceanManager.storm_cells): x, z, radius, extra swell.
uniform vec4 storm_cells[2];
// Whirlpools (OceanManager.whirls): x, z, radius, funnel depth.
uniform vec4 whirls[2];
uniform vec2 crest = vec2(2.0, 0.75);
uniform vec4 env_dirs = vec4(0.019, 0.011, -0.008, 0.016);
uniform vec3 env_params = vec3(0.22, 0.05, 0.037);
uniform vec2 crest_cap = vec2(0.85, 0.4);

// The islands' shore maps (ShoreMap, the MAX_SHORES nearest the camera): depth, phase distance
// offshore, how far the swell has turned to the shore, exposure. Rects (x0, z0, size, on).
uniform sampler2D shore0 : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D shore1 : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D shore2 : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D shore3 : filter_linear, repeat_disable, hint_default_black;
uniform vec4 shore_rect[4];
// The swell turned to the shore: per train [k, omega, amplitude, phase] (OceanManager.SHORE_WAVES).
uniform vec4 shore_waves[2];
// pow, mean, steepens from .w m deep to .z; fade from .y m deep to nothing at .x, growth, wobble.
uniform vec4 shore_shape = vec4(3.2, 0.607, 0.8, 5.0);
uniform vec4 shore_fade = vec4(0.05, 2.4, 0.25, 3.0);
uniform vec4 shore_wob = vec4(0.021, 0.013, -0.009, 0.019);
uniform vec4 shore_none = vec4(1000.0, 64.0, 0.0, 1.0);

// The funnel a whirlpool drags the sea down into (same as OceanManager.funnel).
float funnel(vec2 p) {
	float f = 0.0;
	for (int i = 0; i < 2; i++) {
		vec4 w = whirls[i];
		float k = 1.0 - smoothstep(0.0, max(w.z, 0.001), distance(p, w.xy));
		f -= w.w * k * k;
	}
	return f;
}

vec4 shore_pick(vec4 best, sampler2D tex, vec4 r, vec2 p) {
	vec2 u = (p - r.xy) / max(r.z, 0.001);
	if (r.w > 0.5 && u.x > 0.0 && u.y > 0.0 && u.x < 1.0 && u.y < 1.0) {
		vec4 s = textureLod(tex, u, 0.0);
		if (s.y < best.y) {
			return s;
		}
	}
	return best;
}

// Same as OceanManager.shore_at: the map nearest its shore wins where they overlap.
vec4 shore_at(vec2 p) {
	vec4 best = shore_none;
	best = shore_pick(best, shore0, shore_rect[0], p);
	best = shore_pick(best, shore1, shore_rect[1], p);
	best = shore_pick(best, shore2, shore_rect[2], p);
	best = shore_pick(best, shore3, shore_rect[3], p);
	return best;
}

float shore_calm(float depth) {
	float t = clamp((depth - shore_fade.x) / (shore_fade.y - shore_fade.x), 0.0, 1.0);
	return 1.0 - (1.0 - t) * (1.0 - t);
}

// Crests reach a coast a little out of step along it (a phase offset).
float shore_wobble(vec2 p) {
	return shore_fade.w * sin(p.x * shore_wob.x + p.y * shore_wob.y) * sin(p.x * shore_wob.z + p.y * shore_wob.w);
}

// The swell turned to the shore (OceanManager.shore_swell).
float shore_swell(vec2 p, float t, vec4 sh, float cell) {
	float steep = 1.0 - smoothstep(shore_shape.z, shore_shape.w, sh.x);
	float pw = mix(crest.x, shore_shape.x, steep);
	float mean = mix(crest.y, shore_shape.y, steep);
	float wob = shore_wobble(p);
	float h = 0.0;
	for (int i = 0; i < 2; i++) {
		vec4 w = shore_waves[i];
		float lam = 6.2831853 / max(w.x, 0.0001);
		float keep = 1.0 - smoothstep(lam * 0.25, lam * 0.5, cell);
		float s = sin(w.x * sh.y + t * w.y + w.w + wob);
		h += w.z * (2.0 * pow(max(0.5 + 0.5 * s, 0.0), pw) - mean) * keep;
	}
	return h * (1.0 + shore_fade.z * steep) * sh.w;
}

// Where the main shore train's crest is (0 on it, rising to 1 just ahead of the next): the surf's bands.
float shore_roll(vec2 p, float t, vec4 sh) {
	vec4 w = shore_waves[0];
	return fract((w.x * sh.y + t * w.y + w.w + shore_wobble(p) - 1.5707963) / 6.2831853);
}

// Height of the swell at p (sh: shore_at(p)). `cell` is the mesh spacing there: waves too short
// for the grid to draw fade out (far away) instead of turning into noise.
float wave_h(vec2 p, float t, float cell, vec4 sh) {
	float h = 0.0;
	for (int i = 0; i < 6; i++) {
		vec4 w = waves[i];
		float lam = 6.2831853 / max(w.z, 0.0001);
		float keep = 1.0 - smoothstep(lam * 0.25, lam * 0.5, cell);
		float s = sin(dot(p, w.xy) * w.z + t * w.w + wave_amp_phase[i].y);
		h += wave_amp_phase[i].x * (2.0 * pow(max(0.5 + 0.5 * s, 0.0), crest.x) - crest.y) * keep;
	}
	if (sh.z > 0.0) {
		h = mix(h, shore_swell(p, t, sh, cell), sh.z);
	}
	float env = 1.0 + env_params.x * sin(dot(p, env_dirs.xy) + t * env_params.y) * sin(dot(p, env_dirs.zw) - t * env_params.z);
	h *= env;
	if (h > crest_cap.x) {
		float e = h - crest_cap.x;
		h = crest_cap.x + e / (1.0 + e / crest_cap.y);
	}
	h *= shore_calm(sh.x);
	float swell = 1.0;
	for (int i = 0; i < 2; i++) {
		vec4 c = storm_cells[i];
		swell += c.w * (1.0 - smoothstep(c.z * 0.35, max(c.z, 0.001), distance(p, c.xy)));
	}
	return h * amp_mult * swell;
}
