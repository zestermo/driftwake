// Dynamic PSX sky: day/night gradient, sun and moon discs, stars, a drifting
// high cloud layer (coverage from the weather) and lightning flashes. Driven
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

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
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
	// the high cloud layer
	if (up > -0.02) {
		vec2 cp = d.xz / (max(up, 0.0) + 0.12) * 0.9 + normalize(wind) * cloud_time * 0.006;
		float n = fbm(cp) * 0.7 + fbm(cp * 2.7 + 3.1) * 0.3;
		float thr = 1.0 - coverage;
		float c = smoothstep(thr - 0.08, thr + 0.18, n);
		float edge = smoothstep(-0.02, 0.15, up);
		vec3 cc = mix(cloud_shade, cloud_lit, clamp((n - thr) * 3.0, 0.0, 1.0));
		cc += sun_color * pow(max(sd, 0.0), 24.0) * 0.25 * (1.0 - storm);
		col = mix(col, cc, c * edge * mix(0.85, 1.0, storm));
	}
	col = mix(col, col * 0.55 + vec3(0.18, 0.19, 0.21), storm * 0.6);
	col += vec3(0.75, 0.8, 1.0) * flash;
	COLOR = col;
}
