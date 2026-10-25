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
// Long-range haze: the sky melts into the world's fog colour toward the
// horizon (and is pure fog below it), so the fogged sea, distant clouds and
// the sky meet with no seam. haze_height = how far up it reaches (sin of the
// elevation): low on a clear day, high in rain and storms, everything in a cloud.
uniform vec3 fog_color : source_color = vec3(0.5, 0.72, 0.92);
uniform float haze_height = 0.08;
// The cloud look (1.21's sky rework, for Zach's pick): 0 the 1.20 layer, 1 painted layers (cirrus over lit and
// self-shadowed cumulus), 2 towers (cel-shaded cumulus towers round the horizon over the 1.20 layer), 3 a raymarched
// cloud deck.
uniform int look = 0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
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
	vec3 sdir = normalize(sun_dir);
	// the sun's warmth on the clouds low in the sky (sunrise, sunset)
	vec3 warm = mix(cloud_lit, sun_color * 1.15, low * 0.75 * (1.0 - storm));
	if (look == 0 || look == 2) {
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
	}
	if (look == 1 && up > -0.02) {
		// cirrus: thin streaks high up, stretched along the wind, catching the low sun
		vec2 wd = normalize(wind);
		vec2 q = d.xz / (max(up, 0.0) + 0.08);
		vec2 sq = vec2(dot(q, wd), dot(q, vec2(-wd.y, wd.x)));
		float ci = fbm(sq * vec2(0.18, 1.6) + vec2(cloud_time * 0.004, 0.0));
		float cir = smoothstep(0.55, 0.85, ci) * smoothstep(0.02, 0.25, up) * (0.25 + coverage * 0.4);
		col = mix(col, mix(cloud_lit, warm, 0.6), cir * 0.55 * (1.0 - storm));
		// cumulus: billows that change shape, lit on the sun's side and shadowed away from it
		vec2 cp = d.xz / (max(up, 0.0) + 0.12) * 0.9 + wd * cloud_time * 0.006;
		float ev = cloud_time * 0.0015;
		float n = fbm3(vec3(cp, ev), 5) * 0.75 + fbm(cp * 2.7 + 3.1) * 0.25;
		float thr = 1.0 - coverage;
		float c = smoothstep(thr - 0.04, thr + 0.12, n);
		// one step toward the sun: denser there = this side is in the cloud's own shade
		vec2 toward = normalize(sdir.xz + vec2(0.0001)) * 0.12;
		float ns = fbm3(vec3(cp + toward, ev), 4) * 0.75 + fbm((cp + toward) * 2.7 + 3.1) * 0.25;
		float shade = clamp((ns - n) * 6.0 + 0.5, 0.0, 1.0);
		float body = clamp((n - thr) * 4.0, 0.0, 1.0);
		vec3 cc = mix(warm, cloud_shade * mix(1.0, 0.85, body), shade * 0.85);
		// thin edges toward the sun glow (silver lining)
		cc += sun_color * pow(max(sd, 0.0), 6.0) * (1.0 - body) * 0.6 * (1.0 - storm);
		// sunset undersides: the shade picks up the sky's warm horizon
		cc = mix(cc, cc * mix(vec3(1.0), sun_color * 1.2, 0.5), low * (1.0 - storm) * shade * 0.6);
		float edge = smoothstep(-0.02, 0.12, up);
		col = mix(col, cc, c * edge * mix(0.9, 1.0, storm));
	}
	if (look == 2 && up > -0.03) {
		// towers: cumulus columns round the horizon, each topped with round lobes (cauliflower), cel-lit from the lobe's
		// own normal in three hard bands. Columns on a ring of CELLS (wraps cleanly all the way round).
		float az = atan(d.x, d.z);
		float cw = 6.2831853 / 40.0;
		float ci = floor(az / cw);
		float best = 2.0;
		vec3 nrm = vec3(0.0);
		float hit = 0.0;
		float hk = 0.0;
		float covk = mix(0.5, 1.2, coverage) * (1.0 - storm * 0.3);
		for (int o = -2; o <= 2; o++) {
			float cell = ci + float(o);
			float cid = mod(cell, 40.0);
			vec2 hp = vec2(cos(cid * cw), sin(cid * cw));
			float m = noise(hp * 2.2 + vec2(7.3, 1.9) + cloud_time * 0.0003) * 0.65 + noise(hp * 5.0 + 3.7) * 0.35;
			float colh = pow(clamp((m - 0.42) * 2.2, 0.0, 1.0), 1.2) * 0.36 * covk;
			if (colh < 0.012) continue;
			float jit = hash(vec2(cid, 3.1));
			float cx = (cell + 0.5 + (jit - 0.5) * 0.5) * cw;
			// a stack of lobes up the tower, smaller and leaning as it climbs, two to a row
			float w0 = min(cw * (0.9 + jit * 0.5), colh * 0.42);
			for (int l = 0; l < 8; l++) {
				float fl = float(l);
				float row = floor(fl * 0.5);
				float rk = 1.0 - row * 0.16;
				float r = w0 * rk * (0.75 + hash(vec2(cid, fl)) * 0.5);
				float sx = (mod(fl, 2.0) - 0.5) * w0 * 0.9 * rk + (hash(vec2(cid, fl + 9.0)) - 0.5) * w0 * 0.5 + row * w0 * 0.12 * (jit - 0.5);
				vec2 c = vec2(cx + sx, colh * (0.18 + row * 0.25) + r * 0.2);
				if (c.y + r > colh * 1.08) continue;
				vec2 dv = vec2(az - c.x, up - c.y) / r;
				float dd = length(dv);
				// the higher lobe wins where they overlap (it's in front of the top of the one below)
				float key = dd - row * 0.3;
				if (dd < 1.0 && key < best) {
					best = key;
					nrm = vec3(dv, sqrt(max(1.0 - dd * dd, 0.0)));
					hit = 1.0;
					hk = clamp(up / colh, 0.0, 1.0);
				}
			}
			// the tower's foot, a flat-bottomed skirt down into the haze
			if (abs(az - cx) < w0 * 1.3 && up < colh * 0.2 && hit < 0.5) {
				nrm = vec3((az - cx) / (w0 * 1.3) * 0.5, -0.2, 0.8);
				hit = 1.0;
				hk = clamp(up / colh, 0.0, 1.0);
			}
		}
		if (hit > 0.0) {
			// the sun in the view's frame: across (T), up, toward the viewer (V)
			vec2 df = normalize(d.xz + vec2(0.0001));
			vec2 tf = vec2(df.y, -df.x);
			vec3 sl = vec3(-dot(sdir.xz, tf), sdir.y, -dot(sdir.xz, df));
			float lam = dot(normalize(nrm), normalize(sl + vec3(0.0, 0.35, 0.25)));
			float band = lam > 0.45 ? 1.0 : (lam > 0.05 ? 0.7 : 0.42);
			vec3 base = mix(cloud_shade * 0.8, cloud_lit, band);
			// the low sun warms the lit faces
			base = mix(base, base * warm, band * low * 0.6);
			base = mix(base, fog_color, (1.0 - hk) * 0.35 + 0.06);
			col = mix(col, base, 1.0 - storm * 0.4);
		}
	}
	if (look == 3 && up > 0.0) {
		// a raymarched cloud deck between two heights over a flat world (units: the deck's thickness)
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
