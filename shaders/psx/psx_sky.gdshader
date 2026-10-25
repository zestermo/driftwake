// Dynamic PSX sky: day/night gradient, sun and moon discs, stars, a raymarched
// cloud deck (coverage from the weather) and lightning flashes. Driven
// every frame by the Weather autoload (scripts/world/weather.gd).
shader_type sky;
render_mode use_debanding;

uniform vec3 top_color : source_color = vec3(0.15, 0.4, 0.82);
uniform vec3 horizon_color : source_color = vec3(0.5, 0.72, 0.92);
uniform vec3 ground_color : source_color = vec3(0.1, 0.2, 0.35);
uniform vec3 sun_dir = vec3(0.0, 0.5, -0.86);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.78);
uniform float sun_size = 0.035;
uniform vec3 moon_dir = vec3(0.0, -0.5, 0.86);
uniform float night = 0.0;          // 0 day .. 1 full night (stars, moon)
uniform float coverage = 0.35;      // cloud cover 0..1
uniform float storm = 0.0;          // darkens and greys everything
uniform vec3 cloud_lit : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.62, 0.68, 0.8);
uniform float flash = 0.0;          // lightning
uniform float cloud_time = 0.0;
uniform vec2 wind = vec2(1.0, 0.3);
// Long-range haze: the sky melts into the world's fog colour toward the
// horizon (and is pure fog below it), so the fogged sea, distant clouds and
// the sky meet with no seam. haze_height = how far up it reaches (sin of the
// elevation): low on a clear day, high in rain and storms, everything in a cloud.
uniform vec3 fog_color : source_color = vec3(0.5, 0.72, 0.92);
uniform float haze_height = 0.08;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm3(vec3 p, int oct) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < oct; i++) {
		v += a * noise3(p);
		p = p * 2.02 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = d.y;
	// gradient (a little banding, PS1 style, comes from the dither pass)
	vec3 col;
	if (up >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(up, 0.0, 1.0), 0.55));
	} else {
		col = mix(horizon_color, ground_color, pow(clamp(-up * 3.0, 0.0, 1.0), 0.6));
	}
	// sunset glow around the sun near the horizon
	float sd = dot(d, normalize(sun_dir));
	float low = 1.0 - clamp(normalize(sun_dir).y * 3.0, 0.0, 1.0);
	col += sun_color * pow(max(sd, 0.0), 10.0) * 0.28 * low * (1.0 - storm);
	// stars
	if (night > 0.01 && up > 0.0) {
		vec2 sp = d.xz / (up + 0.25) * 140.0;
		vec2 cell = floor(sp);
		float h = hash(cell);
		float star = step(0.985, h) * smoothstep(0.42, 0.05, length(fract(sp) - 0.5));
		float tw = 0.6 + 0.4 * sin(TIME * (2.0 + h * 5.0) + h * 40.0);
		col += vec3(star * tw * night * (1.0 - coverage) * (1.0 - storm));
	}
	// sun disc
	float sun_disc = smoothstep(cos(sun_size), cos(sun_size * 0.7), sd);
	col = mix(col, sun_color * 1.6, sun_disc * (1.0 - storm * 0.9) * clamp(normalize(sun_dir).y * 8.0 + 1.0, 0.0, 1.0));
	// moon disc (with a darker crescent bite)
	float md = dot(d, normalize(moon_dir));
	float moon = smoothstep(cos(0.03), cos(0.022), md);
	float bite = smoothstep(cos(0.026), cos(0.018), dot(d, normalize(moon_dir + vec3(0.012, 0.008, 0.0))));
	col = mix(col, vec3(0.92, 0.94, 1.0), moon * (1.0 - bite * 0.85) * night * (1.0 - storm * 0.8));
	vec3 sdir = normalize(sun_dir);
	// the sun's warmth on the clouds low in the sky (sunrise, sunset)
	vec3 warm = mix(cloud_lit, sun_color * 1.15, low * 0.75 * (1.0 - storm));
	if (up > 0.0) {
		// the clouds (1.21: Zach's pick, look C): a raymarched cloud deck between two heights over a flat world (units: the deck's thickness)
		float h0 = 1.0;
		float h1 = 1.7;
		float t0 = h0 / max(up, 0.015);
		float t1 = h1 / max(up, 0.015);
		int steps = AT_CUBEMAP_PASS ? 5 : 14;
		float dt = (t1 - t0) / float(steps);
		float trans = 1.0;
		vec3 acc = vec3(0.0);
		vec3 drift = vec3(wind.x, 0.0, wind.y) * cloud_time * 0.01;
		float thr = 1.0 - coverage;
		float j = hash(SCREEN_UV * 731.0) * dt;
		for (int i = 0; i < steps; i++) {
			if (trans < 0.03) break;
			vec3 pos = d * (t0 + j + dt * float(i));
			if (length(pos.xz) > 40.0) break;
			float hk = (pos.y - h0) / (h1 - h0);
			float shape = smoothstep(0.0, 0.25, hk) * smoothstep(1.0, 0.55, hk);
			vec3 sp = pos * 0.9 + drift;
			float dens = smoothstep(thr - 0.02, thr + 0.12, fbm3(sp, 4)) * shape * 2.6;
			if (dens > 0.01) {
				// one sample toward the sun for its shade
				float dl = smoothstep(thr - 0.02, thr + 0.12, fbm3(sp + sdir * 0.35, 3)) * 2.0;
				float lit = exp(-dl * 2.4) * (0.6 + 0.4 * hk);
				vec3 cc = mix(cloud_shade * 0.8, warm, lit);
				cc += sun_color * pow(max(sd, 0.0), 8.0) * lit * 0.4 * (1.0 - storm);
				float a = 1.0 - exp(-dens * dt * 2.2);
				acc += trans * a * cc;
				trans *= 1.0 - a;
			}
		}
		float fade = smoothstep(0.0, 0.1, up);
		col = mix(col, acc / max(1.0 - trans, 0.001), (1.0 - trans) * fade);
	}
	col = mix(col, col * 0.55 + vec3(0.18, 0.19, 0.21), storm * 0.6);
	float haze = 1.0 - smoothstep(0.0, max(haze_height, 0.001), up);
	col = mix(col, fog_color, haze * haze * (3.0 - 2.0 * haze));
	col += vec3(0.75, 0.8, 1.0) * flash;
	COLOR = col;
}
