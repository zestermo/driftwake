class_name StaffMoves
extends RefCounted
## The fighting staff (1.28, stance "staff"): a plain pole held in both hands near its middle (the shaft slid SHIFT m
## back through the right hand, so both ends strike), blunt and acrobatic: overhead blows, rising butt-ends that throw
## them up, flat sweeps and full turns, a vault kick off the planted staff. Every "sf_*" action keys the body and the
## grip like PoleMoves (its four grip channels, solved by PoleMoves.hands); the sweeps and turns borrow the polearm's
## keys with the staff slid to its middle, the strikes, the vault kick and the guard are the staff's own.

## How far the shaft is slid back through the right hand (m): the hands near its middle.
const SHIFT := 0.62
## The guard: side on, the staff held across the body, its front end at their chest, the rear low behind.
const GUARD_GRIP := [Vector3(0.1, -0.36, -0.26), Vector3(-0.62, 0.3, -0.72), Vector3(0, -1, 0), 0.5]
const GRIPS := [GUARD_GRIP, PoleMoves.BLOCK_GRIP, PoleMoves.RUN_GRIP]
const GUARD := {"hips": Vector3(0, -0.4, 0), "torso": Vector3(-0.08, -0.35, 0), "head": Vector3(0.06, 0.55, 0),
	"arm_l": Vector3(0.7, 0, -0.4), "fore_l": Vector3(0.9, 0, 0), "arm_r": Vector3(0.2, 0, 0.3), "fore_r": Vector3(1.1, 0, 0)}
const LEGS := {"leg_l": Vector3(0.5, 0, -0.24), "leg_r": Vector3(-0.32, 0, 0.24), "shin_l": Vector3(-0.8, 0, 0), "shin_r": Vector3(-0.55, 0, 0),
	"_lift": Vector3(0, -0.16, 0)}
const BLOCK := PoleMoves.BLOCK
## The polearm keys a staff move borrows (slid to the middle).
const BORROW := {"sf_3": "pole_sweep", "sf_4": "pole_wheel", "sf_low": "pole_legsweep", "sf_parry": "pole_parry",
	"sf_deflect": "pole_deflect", "sf_block": "pole_block", "sf_dive": "pole_dive", "sf_land": "pole_land"}


## [pose, mask, lift] for a staff move (the grip taken off into the body's pole_grip).
static func pose(h, n: String, u: float) -> Array:
	var res: Array
	if BORROW.has(n):
		res = PoleMoves._pose(h, BORROW[n], u)
	else:
		res = _pose(h, n, u)
	# (the staff held near its middle all through)
	var p: Dictionary = res[0]
	if p.has("_gs"):
		p["_gs"] = Vector3((p["_gs"] as Vector3).x, SHIFT, 0)
	return PoleMoves.take_grip(h, res)


static func _g() -> Dictionary:
	return PoleMoves._k(PoleMoves._p([GUARD, LEGS, {"pivot": Vector3.ZERO, "_scale": Vector3.ONE, "_smear": Vector3.ZERO}]), GUARD_GRIP)


static func _pose(h, n: String, u: float) -> Array:
	var g := _g()
	match n:
		"sf_stance":
			return [g, "full", Vector3.ZERO]
		"sf_1", "sf_heavy_a":
			# hit 1: the staff swung up over the head and brought straight down on them, the front end leading
			var up := PoleMoves._k({"pivot": Vector3(0.08, 0, 0), "hips": Vector3(0, -0.2, 0), "torso": Vector3(0.12, -0.2, 0), "head": Vector3(-0.1, 0.3, 0),
				"_lift": Vector3(0, -0.06, 0), "_scale": Vector3(0.97, 1.05, 0.98), "_smear": Vector3.ZERO}.merged(PoleMoves.SET),
				[Vector3(0.12, 0.28, -0.08), Vector3(-0.2, 0.75, 0.62), Vector3(0, 0.3, 0.95), 0.5])
			var down := PoleMoves._k({"pivot": Vector3(-0.22, 0, 0), "hips": Vector3(0, -0.05, 0), "torso": Vector3(-0.35, -0.1, 0), "head": Vector3(0.3, 0.15, 0),
				"_lift": Vector3(0, -0.32, 0), "_scale": Vector3(1.04, 0.95, 1.02), "_smear": Vector3.ZERO}.merged(PoleMoves.LUNGE),
				[Vector3(0.0, -0.18, -0.46), Vector3(-0.08, -0.52, -0.85), Vector3(0, -0.85, -0.5), 0.46])
			var whoosh := PoleMoves._whip(up, down, 0.55, Vector3(0.96, 1.06, 1.04))
			return [h._keys(u, [[0.0, g], [0.26, up, "out"], [0.32, up], [0.4, whoosh, "in"], [0.46, down, "out"], [0.66, down], [1.0, g]]), "full", Vector3.ZERO]
		"sf_2", "sf_rise":
			# hit 2 (the launcher): the rear end swung low behind, then up through them from below, the body rising
			# onto the toes with it - it throws a light foe into the air
			var low := PoleMoves._k({"pivot": Vector3(-0.15, 0, 0), "hips": Vector3(0, 0.35, 0), "torso": Vector3(-0.3, 0.35, 0.05), "head": Vector3(0.25, -0.5, 0),
				"_lift": Vector3(0, -0.34, 0), "_scale": Vector3(1.05, 0.93, 1.0), "_smear": Vector3.ZERO}.merged(PoleMoves.WIDE),
				[Vector3(0.08, -0.4, -0.18), Vector3(0.55, 0.35, 0.75), Vector3(0, -0.6, -0.8), 0.48])
			var up := PoleMoves._k({"pivot": Vector3(0.12, 0, 0), "hips": Vector3(0, -0.2, 0), "torso": Vector3(0.15, -0.25, 0), "head": Vector3(-0.15, 0.4, 0),
				"_lift": Vector3(0, 0.08, 0), "_scale": Vector3(0.95, 1.08, 0.98), "_smear": Vector3.ZERO}.merged(PoleMoves.STEP_R),
				[Vector3(0.12, 0.05, -0.3), Vector3(0.35, -0.75, 0.55), Vector3(0, 0.8, -0.6), 0.44])
			var whoosh := PoleMoves._whip(low, up, 0.5, Vector3(0.95, 1.08, 1.0))
			return [h._keys(u, [[0.0, g], [0.24, low, "out"], [0.3, low], [0.38, whoosh, "in"], [0.45, up, "out"], [0.64, up], [1.0, g]]), "full", Vector3.ZERO]
		"sf_heavy":
			# the heavy (Cyclone): the staff spun round twice with the whole body, low and wide, then the last turn
			# ending in a blow that drives everyone off
			var load: Dictionary = PoleMoves._pose(h, "pole_wheel", 0.24)[0]
			var turn: Dictionary = PoleMoves._pose(h, "pole_wheel", 0.45)[0]
			var land: Dictionary = PoleMoves._pose(h, "pole_wheel", 0.8)[0]
			var pz: Dictionary = h._keys(u, [[0.0, g], [0.12, load, "out"], [0.18, load], [0.24, turn, "in"], [0.78, turn, "linear"], [0.86, land, "out"], [1.0, g]])
			var k := clampf((u - 0.18) / 0.62, 0.0, 1.0)
			pz["pivot"] = Vector3(-0.08 * sin(k * PI), TAU * 2.0 * k, 0)
			return [pz, "full", Vector3.ZERO]
		"sf_dash":
			# at a sprint (Vault Kick): the staff planted ahead, the body swung up on it and both feet driven through
			# the one in front, the staff pulled free on the landing
			var plant: Dictionary = PoleMoves._pose(h, "pole_vault", 0.1)[0]
			var kick: Dictionary = (PoleMoves._pose(h, "pole_vault", 0.42)[0] as Dictionary).merged({"pivot": Vector3(-0.5, 0, 0),
				"leg_l": Vector3(2.0, 0, -0.1), "shin_l": Vector3(-0.1, 0, 0), "leg_r": Vector3(1.9, 0, 0.1), "shin_r": Vector3(-0.15, 0, 0),
				"_smear": Vector3(0.12, 0, 0)}, true)
			var land: Dictionary = PoleMoves._pose(h, "pole_vault", 0.9)[0]
			return [h._keys(u, [[0.0, plant], [0.18, plant], [0.38, kick, "out"], [0.52, kick], [0.78, land], [1.0, g]]), "full", Vector3.ZERO]
	return [g, "full", Vector3.ZERO]
