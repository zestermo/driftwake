class_name InstrumentPoses
extends RefCounted
## Playing an instrument ("music_<kind>", held by Jam): the stance and the time-keeping, a sway every two
## beats and the right foot tapping each one (Jam sets the body's meta "jam_beat", beats since the tune
## began, from the shared clock, so a band sways together). Jam's IK puts the hands on the instrument after
## this pose; the arms here are keyed close to where it puts them, so the blend in reads.

static func pose(h, n: String, u: float) -> Array:
	var bt: float = float(h.get_meta("jam_beat", h._t * 2.0))
	var ph := fposmod(bt, 1.0)
	var sw := sin(bt * PI)
	var tap := maxf(0.0, sin(ph * TAU))
	var p := {"hips": Vector3(0, 0.05 * sw, -0.03 * sw), "torso": Vector3(0.0, 0.0, 0.04 * sw), "head": Vector3(0.0, 0.0, -0.05 * sw),
		"leg_l": Vector3(0.06, 0, -0.1), "shin_l": Vector3(-0.14, 0, 0),
		"leg_r": Vector3(0.04 + 0.16 * tap, 0, 0.1), "shin_r": Vector3(-0.12 - 0.3 * tap, 0, 0),
		"_lift": Vector3(0.015 * sw, -0.025 - 0.012 * absf(sin(ph * PI)), 0)}
	var up: Dictionary
	match n:
		"music_concertina":
			up = {"torso": Vector3(0.1, 0.0, 0.04 * sw), "head": Vector3(-0.1, 0.0, -0.06 * sw),
				"arm_l": Vector3(0.9, 0.2, -0.45), "fore_l": Vector3(1.3, 0, 0), "arm_r": Vector3(0.9, -0.2, 0.45), "fore_r": Vector3(1.3, 0, 0)}
		"music_fiddle":
			# the head laid on the chinrest, the fiddle out to the left, the bow arm out to the right
			up = {"torso": Vector3(0.06, 0.18, 0.05 + 0.03 * sw), "head": Vector3(-0.22, 0.38, 0.3),
				"arm_l": Vector3(1.35, -0.45, -0.35), "fore_l": Vector3(1.55, 0, 0), "arm_r": Vector3(0.75, 0.1, 0.65), "fore_r": Vector3(1.5, 0, 0)}
		"music_whistle":
			up = {"torso": Vector3(0.08, 0.0, 0.04 * sw), "head": Vector3(-0.18, 0.0, -0.04 * sw),
				"arm_l": Vector3(1.25, 0.25, -0.25), "fore_l": Vector3(1.85, 0, 0), "arm_r": Vector3(1.0, -0.25, 0.25), "fore_r": Vector3(1.85, 0, 0)}
		"music_bodhran":
			# turned a little to the drum on the left hip, eyes on it
			up = {"torso": Vector3(-0.05, 0.25, 0.04 * sw), "head": Vector3(-0.25, 0.1, 0.0),
				"arm_l": Vector3(0.75, 0.1, -0.5), "fore_l": Vector3(1.4, 0, 0), "arm_r": Vector3(0.9, -0.1, 0.35), "fore_r": Vector3(1.7, 0, 0)}
		"music_gurdy":
			# leant over the keys, the crank turning at the right hip
			up = {"torso": Vector3(-0.14, 0.0, 0.04 * sw), "head": Vector3(-0.3, 0.05, 0.0),
				"arm_l": Vector3(0.75, 0.2, -0.3), "fore_l": Vector3(1.25, 0, 0), "arm_r": Vector3(0.55, 0.0, 0.4), "fore_r": Vector3(1.1, 0, 0)}
		"music_banjo":
			# a little hunched over the pot, eyes down the neck to the left
			up = {"torso": Vector3(-0.08, 0.1, 0.04 * sw), "head": Vector3(-0.28, 0.25, 0.0),
				"arm_l": Vector3(1.0, 0.3, -0.35), "fore_l": Vector3(1.2, 0, 0), "arm_r": Vector3(0.45, -0.1, 0.35), "fore_r": Vector3(1.55, 0, 0)}
	for k in up.keys():
		p[k] = up[k]
	return [h._keys(minf(u, 1.0), [[0.0, {}], [1.0, p]]), "full", Vector3.ZERO]
