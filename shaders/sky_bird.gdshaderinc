// The sky's birds' shared look (sky_bird.gdshader: the birds the CPU flies; world/sky_flock.gdshader: the high
// flocks flown here on the GPU). The mesh (SkyBirds._bird_mesh): span along x, facing -z, wings hinged at the
// shoulders; vertex colour the gull's plumage, alpha marking body 1, inner wing 0.6, tip 0.3.

const float SHOULDER = 0.07;

vec3 parrot(float k, float part) {
	vec3 c = vec3(0.86, 0.14, 0.1);
	if (k > 2.5) c = vec3(0.12, 0.38, 0.9);
	if (k > 3.5) c = vec3(0.95, 0.78, 0.12);
	if (k > 4.5) c = vec3(0.16, 0.66, 0.24);
	return part < 0.45 ? c * 0.35 + vec3(0.05, 0.1, 0.4) * 0.5 : (part < 0.8 ? c * 0.8 : c);
}

// The wings turned up by `wing` (radians) and folded along the back by `fold` (1 = tucked).
vec3 bird_wings(vec3 v, float wing, float fold) {
	float d = abs(v.x) - SHOULDER;
	if (d > 0.0) {
		float s = sign(v.x);
		d *= 1.0 - 0.72 * fold;
		v.x = s * (SHOULDER + d * cos(wing));
		v.y += d * sin(wing);
		v.z += fold * d * 0.45;
	}
	return v;
}

// Its colour by kind (0 gull, 1 dark far bird, 2-5 a parrot's colour, 6 a vulture) and part (vertex alpha).
vec3 bird_tint(float kind, vec3 plumage, float part) {
	if (kind < 0.5) {
		return plumage;
	} else if (kind < 1.5) {
		return vec3(0.07, 0.065, 0.06);
	} else if (kind > 5.5) {
		// a vulture: dun-brown body and coverts, dark flight feathers, near-black fingered tips
		return part > 0.8 ? vec3(0.24, 0.17, 0.12) : (part > 0.45 ? vec3(0.13, 0.09, 0.07) : vec3(0.04, 0.035, 0.03));
	}
	return parrot(kind, part);
}
