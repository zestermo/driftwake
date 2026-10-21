class_name GreatswordMoves
## The greatsword (stance "greatsword"): a long two-handed blade, the right hand at the pommel end of the grip and
## the left above it toward the guard. The guard is low and relaxed (Zach's reference, docs/weapons_plan.md): both
## hands on the hilt at the right hip, the blade a long diagonal down and forward across the body, its point near the
## ground on the left; at a sprint the point drags behind and scrapes sparks off the ground (scrape()).
## Every move ("gs_*", reached from Humanoid._action_pose) keys the body plus the polearm's four grip channels
## (PoleMoves: "_gr" the right hand, "_gd" the blade's direction, "_ge" which way the edge faces, "_gs" the left
## hand's slide up the grip, < 0 one-handed; the chest's frame: x right, y up, z back), solved each frame by
## PoleMoves.hands.
## The combo flows: each blow's follow-through is the next one's wind-up ("carry" in ActionSpecs: a chained blow
## starts from where the last one ended, Humanoid._begin_action): out of the low guard up across to high right
## (C2), back down to low left (C1), flat round to the right (C4), and on round in a full turn. Same joint
## conventions as humanoid.gd.

## [right hand, blade, edge, left hand's slide] (chest frame). The low guard: hands at the right hip, the blade down
## and forward across the body to the left, the edge down.
const GUARD_GRIP := [Vector3(0.25, -0.6, -0.12), Vector3(-0.82, -0.47, -0.33), Vector3(0, -1, 0), 0.2]
## Sprinting: in the right hand alone, the point dragged along the ground behind.
const TRAIL_GRIP := [Vector3(0.3, -0.53, -0.18), Vector3(0.15, -0.82, 0.56), Vector3(0, -1, 0), -1.0]
## The guard (block, parry): the blade stood up in front, point high, the flat turned to them like a shield.
const BLOCK_GRIP := [Vector3(0.06, -0.42, -0.42), Vector3(-0.22, 0.96, 0.12), Vector3(1, 0, 0), 0.18]
const GRIPS := [GUARD_GRIP, BLOCK_GRIP, TRAIL_GRIP]

## The guard: upright and easy, the chest turned a little toward the blade, eyes down its line. The arms seed the IK.
const GUARD := {"hips": Vector3(0, 0.05, 0), "torso": Vector3(-0.06, 0.06, 0), "head": Vector3(0.12, -0.1, 0),
	"arm_r": Vector3(0.3, 0.0, 0.25), "fore_r": Vector3(0.7, 0, 0), "hand_r": Vector3.ZERO,
	"arm_l": Vector3(0.6, -0.45, -0.1), "fore_l": Vector3(0.9, 0, 0), "hand_l": Vector3.ZERO}
## The stance's feet (Humanoid.STANCE_LEGS): a relaxed stance, the left foot a little forward.
const LEGS := {"leg_l": Vector3(0.3, 0, -0.2), "leg_r": Vector3(-0.25, 0, 0.22), "shin_l": Vector3(-0.4, 0, 0), "shin_r": Vector3(-0.35, 0, 0),
	"_lift": Vector3(0, -0.08, 0)}
const BLOCK := {"hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.1, -0.08, 0), "head": Vector3(0.12, 0.1, 0),
	"arm_r": Vector3(1.0, 0.2, 0.3), "fore_r": Vector3(1.0, 0, 0), "arm_l": Vector3(1.1, -0.3, -0.3), "fore_l": Vector3(1.2, 0, 0)}
## Sprinting: how often the dragged point throws sparks (s), and how near the ground it must be (m).
const SCRAPE_EVERY := 0.07
const SCRAPE_H := 0.3

# action-key legs
const SET := {"leg_l": Vector3(0.3, 0, -0.2), "shin_l": Vector3(-0.4, 0, 0), "leg_r": Vector3(-0.25, 0, 0.22), "shin_r": Vector3(-0.35, 0, 0)}
const LUNGE := {"leg_l": Vector3(1.1, 0, -0.24), "shin_l": Vector3(-1.35, 0, 0), "leg_r": Vector3(-0.8, 0, 0.24), "shin_r": Vector3(-0.25, 0, 0)}
const STEP_R := {"leg_l": Vector3(-0.5, 0, -0.26), "shin_l": Vector3(-0.45, 0, 0), "leg_r": Vector3(0.9, 0, 0.26), "shin_r": Vector3(-1.05, 0, 0)}
const WIDE := {"leg_l": Vector3(0.5, 0, -0.48), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.32, 0, 0.48), "shin_r": Vector3(-0.9, 0, 0)}
## (wound right, the right foot forward instead: WIDE with the back leg kicked up otherwise)
const WIDE_R := {"leg_l": Vector3(-0.3, 0, -0.48), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(0.5, 0, 0.48), "shin_r": Vector3(-1.0, 0, 0)}
const SQUAT := {"leg_l": Vector3(0.95, 0, -0.45), "shin_l": Vector3(-1.6, 0, 0), "leg_r": Vector3(0.2, 0, 0.45), "shin_r": Vector3(-1.4, 0, 0)}
const TUCK := {"leg_l": Vector3(1.5, 0, -0.15), "shin_l": Vector3(-2.0, 0, 0), "leg_r": Vector3(1.1, 0, 0.15), "shin_r": Vector3(-1.7, 0, 0)}


static func _k(body: Dictionary, grip: Array) -> Dictionary:
	return PoleMoves._k(body, grip)


## The guard as an action key (every joint and channel).
static func _g() -> Dictionary:
	return _k(PoleMoves._p([GUARD, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.08, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}]), GUARD_GRIP)


static func pose(h, n: String, u: float) -> Array:
	return PoleMoves.take_grip(h, _pose(h, n, u))


## Tempest Turns: how far through its three turns the body is at `s` seconds (0..1), each turn quicker than the last.
const TEMPEST := Vector2(0.2, 1.35)


static func tempest_k(s: float) -> float:
	return pow(clampf((s - TEMPEST.x) / (TEMPEST.y - TEMPEST.x), 0.0, 1.0), 1.6)


## Sprinting with the point dragged behind: every SCRAPE_EVERY s, sparks where it scrapes the ground (local to each
## screen, like the grip; nothing far off: FX culls bursts out of range).
static func scrape(h, delta: float) -> void:
	h.gs_scrape -= delta
	if h.gs_scrape > 0.0:
		return
	h.gs_scrape = SCRAPE_EVERY
	var w: MeshInstance3D = h.weapon
	var tip: Vector3 = w.global_transform * Vector3(0, 0, w.mesh.get_aabb().position.z * 0.97)
	var feet: float = h.global_position.y
	if tip.y - feet > SCRAPE_H:
		return
	var back: Vector3 = h.global_basis.z
	var fx = h.get_node_or_null("/root/FX")
	if fx != null:
		fx.muzzle_sparks(Vector3(tip.x, feet + 0.04, tip.z), (back + Vector3.UP * 0.6).normalized(), 3, Color(1.0, 0.82, 0.45))


# --------------------------------------------------------------------------
# The combo's carries: where each blow's follow-through ends and the next one starts
# --------------------------------------------------------------------------
## C1: brought down across, the blade carried on round low past the left hip, the body wound left.
static func _c1() -> Dictionary:
	return _k({"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, 0.7, 0), "torso": Vector3(-0.3, 0.75, 0), "head": Vector3(0.22, -0.8, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.04, 0.95, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
		[Vector3(-0.2, -0.45, -0.28), Vector3(-0.8, -0.42, 0.42), Vector3(-0.25, -0.2, 0.95), 0.2])


## C2: swept up through the front, the blade on up over the right shoulder, the body wound right.
static func _c2() -> Dictionary:
	return _k({"pivot": Vector3(0.04, 0, 0), "hips": Vector3(0, -0.55, 0), "torso": Vector3(0.1, -0.6, 0), "head": Vector3(-0.05, 0.62, 0),
		"_lift": Vector3(0, -0.1, 0), "_scale": Vector3(0.97, 1.05, 1.0), "_smear": Vector3.ZERO}.merged(STEP_R),
		[Vector3(0.25, 0.05, -0.3), Vector3(0.45, 0.78, 0.43), Vector3(0.25, 0.4, 0.88), 0.2])


## C4: swept flat through the front from the left, the blade on round out past the right side, the body wound right.
static func _c4() -> Dictionary:
	return _k({"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, -0.85, 0), "torso": Vector3(-0.12, -0.9, 0), "head": Vector3(0.08, 1.05, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.03, 0.97, 1.0), "_smear": Vector3.ZERO}.merged(WIDE_R),
		[Vector3(0.12, -0.32, -0.36), Vector3(0.86, -0.05, 0.5), Vector3(0.5, 0, 0.86), 0.2])


## Swept flat out past the left side, the body wound left (the running cleave's follow-through).
static func _left_out() -> Dictionary:
	return _k({"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, 0.85, 0), "torso": Vector3(-0.12, 0.9, 0), "head": Vector3(0.08, -1.05, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.03, 0.97, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
		[Vector3(-0.1, -0.32, -0.38), Vector3(-0.86, -0.05, 0.5), Vector3(-0.5, 0, 0.86), 0.2])


## Raised for the cleave: both hands over the head, the blade hanging back behind it, the back arched.
static func _raised(body: Dictionary) -> Dictionary:
	return _k({"pivot": Vector3(0.1, 0, 0), "hips": Vector3(0, -0.08, 0), "torso": Vector3(0.25, -0.08, 0), "head": Vector3(-0.2, 0.08, 0),
		"_lift": Vector3(0, -0.12, 0), "_scale": Vector3(0.96, 1.07, 1.0), "_smear": Vector3.ZERO}.merged(body, true),
		[Vector3(0.06, 0.4, -0.08), Vector3(0.05, -0.3, 0.95), Vector3(0, 0.95, 0.3), 0.2])


## The cleave driven down in front: bent deep over it, the point biting the ground ahead. (The grip's channels are in
## the chest's frame: bent this far forward, a blade near level in that frame already points down at the ground.)
static func _cleaved(body: Dictionary) -> Dictionary:
	return _k({"pivot": Vector3(-0.25, 0, 0), "hips": Vector3(0, 0.05, 0), "torso": Vector3(-0.45, 0.05, 0), "head": Vector3(0.42, -0.05, 0),
		"_lift": Vector3(0, -0.42, 0), "_scale": Vector3(1.08, 0.9, 1.04), "_smear": Vector3.ZERO}.merged(LUNGE).merged(body, true),
		[Vector3(0.0, -0.15, -0.55), Vector3(0.0, 0.4, -0.92), Vector3(0, -0.92, -0.4), 0.2])


## On the way back to the low guard from high right: the blade lowered through the front first, so it never turns
## over the top.
static func _lowering(from: Dictionary) -> Dictionary:
	return from.merged({"_gr": Vector3(0.15, -0.4, -0.35), "_gd": Vector3(0.45, -0.25, -0.86), "_ge": Vector3(0, -1, 0)}, true)


static func _pose(h, n: String, u: float) -> Array:
	var g := _g()
	match n:
		"gs_stance":
			return [g, "full", Vector3.ZERO]
		# --- the combo ---
		"gs_1":
			# hit 1, out of the low guard: the point drawn back low on the left, then swept up through the front from low
			# left to high right, stepping through on the right foot, and on up over the right shoulder (C2)
			var load := _c1().merged({"hips": Vector3(0, 0.55, 0), "torso": Vector3(-0.25, 0.6, 0), "head": Vector3(0.2, -0.6, 0), "_lift": Vector3(0, -0.24, 0),
				"_gd": Vector3(-0.85, -0.45, 0.28)}, true)
			var strike := _k({"pivot": Vector3(-0.02, 0, 0), "hips": Vector3(0, -0.15, 0), "torso": Vector3(-0.05, -0.25, 0), "head": Vector3(0.05, 0.25, 0),
				"_lift": Vector3(0, -0.14, 0), "_scale": Vector3(0.96, 1.06, 1.0), "_smear": Vector3.ZERO}.merged(STEP_R),
				[Vector3(0.05, -0.25, -0.5), Vector3(0.3, 0.35, -0.89), Vector3(0.6, 0.75, 0.2), 0.2])
			var whoosh := PoleMoves._whip(load, strike, 0.5, Vector3(0.97, 1.07, 1.02), 0.12)
			var c2 := _c2()
			return [h._keys(u, [[0.0, g], [0.16, load, "out"], [0.26, whoosh, "in"], [0.34, strike, "out"], [0.52, c2, "out"], [0.68, c2],
				[0.84, _lowering(g)], [1.0, g]]), "full", Vector3.ZERO]
		"gs_2":
			# hit 2, out of C2: the blade's weight turned at the top by the right ear, then one great diagonal from high
			# right down through the front to low left, the body turning after it, carried on round past the left hip (C1)
			var c2 := _c2()
			var wind := _k({"pivot": Vector3(0.06, 0, 0), "hips": Vector3(0, -0.45, 0), "torso": Vector3(0.1, -0.5, 0.04), "head": Vector3(-0.04, 0.55, 0),
				"_lift": Vector3(0, -0.1, 0), "_scale": Vector3(0.98, 1.04, 1.0), "_smear": Vector3.ZERO}.merged(SET),
				[Vector3(0.25, 0.12, -0.15), Vector3(0.2, 0.75, 0.62), Vector3(-0.3, 0.3, -0.9), 0.2])
			var strike := _k({"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, 0.35, 0), "torso": Vector3(-0.3, 0.4, 0), "head": Vector3(0.25, -0.4, 0),
				"_lift": Vector3(0, -0.28, 0), "_scale": Vector3(1.05, 0.94, 1.02), "_smear": Vector3.ZERO}.merged(LUNGE),
				[Vector3(-0.05, -0.35, -0.48), Vector3(-0.55, -0.32, -0.77), Vector3(-0.6, -0.75, 0.2), 0.2])
			var whoosh := PoleMoves._whip(wind, strike, 0.5, Vector3(0.97, 1.02, 1.08), 0.12)
			return [h._keys(u, [[0.0, c2], [0.14, wind, "out"], [0.22, wind], [0.28, whoosh, "in"], [0.34, strike, "out"], [0.5, _c1(), "out"], [0.68, _c1()], [1.0, g]]), "full", Vector3.ZERO]
		"gs_3":
			# hit 3, out of C1: the blade levelled behind on the left at the waist, then one flat backhand sweep through the
			# front and on round to the right in a wide low stance (it breaks a guard), carried out past the right side (C4)
			var drop := _k({"pivot": Vector3(0.0, 0, 0), "hips": Vector3(0, 0.7, 0), "torso": Vector3(-0.05, 0.75, 0), "head": Vector3(0.1, -0.9, 0),
				"_lift": Vector3(0, -0.26, 0), "_scale": Vector3(1.05, 0.94, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
				[Vector3(-0.2, -0.35, -0.08), Vector3(-0.75, -0.05, 0.66), Vector3(-0.66, 0, -0.75), 0.2])
			var strike := _k({"pivot": Vector3(-0.08, 0, 0), "hips": Vector3(0, -0.45, 0), "torso": Vector3(-0.15, -0.5, 0), "head": Vector3(0.1, 0.6, 0),
				"_lift": Vector3(0, -0.32, 0), "_scale": Vector3(1.02, 0.98, 1.0), "_smear": Vector3.ZERO}.merged(WIDE_R),
				[Vector3(0.05, -0.32, -0.46), Vector3(0.15, -0.02, -0.99), Vector3(1, 0, 0.1), 0.2])
			var whoosh := PoleMoves._whip(drop, strike, 0.5, Vector3(1.08, 0.97, 1.0), 0.14)
			return [h._keys(u, [[0.0, _c1()], [0.16, drop, "out"], [0.24, drop], [0.31, whoosh, "in"], [0.38, strike, "linear"], [0.54, _c4(), "out"], [0.72, _c4()], [1.0, g]]), "full", Vector3.ZERO]
		"gs_4":
			# hit 4 (Gale Turn), out of C4: the sweep's momentum let carry the whole body on round once more with the
			# blade out at arm's length, then brought through level in front and down into the low guard
			var c4 := _c4()
			var turn := _k({"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, -0.15, 0), "torso": Vector3(-0.18, -0.15, 0), "head": Vector3(0.1, 0.1, 0),
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.05, 0.97, 1.0), "_smear": Vector3(0.12, 0, 0)}.merged(WIDE_R),
				[Vector3(0.08, -0.3, -0.45), Vector3(0.72, -0.06, -0.69), Vector3(0.66, 0, 0.75), 0.2])
			var finish := turn.merged({"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, -0.6, 0), "torso": Vector3(-0.25, -0.65, 0), "head": Vector3(0.2, 0.75, 0),
				"_lift": Vector3(0, -0.36, 0), "_scale": Vector3(1.06, 0.93, 1.02), "_smear": Vector3.ZERO,
				"_gd": Vector3(0.92, -0.1, -0.38), "_ge": Vector3(0.38, 0, 0.92)}, true)
			var pz: Dictionary = h._keys(u, [[0.0, c4], [0.12, turn, "in"], [0.6, turn, "linear"], [0.7, finish, "out"], [0.84, finish], [0.92, _lowering(g)], [1.0, g]])
			var k := clampf((u - 0.08) / 0.56, 0.0, 1.0)
			pz["pivot"] = (pz["pivot"] as Vector3) + Vector3(-0.05 * sin(k * PI), -TAU * k, 0)
			return [pz, "full", Vector3.ZERO]
		# --- the heavy: held raised while it charges (gs_charge, Humanoid.hold), then the cleave (gs_heavy) ---
		"gs_charge":
			var raise := _raised(SET.merged({"leg_l": Vector3(0.5, 0, -0.25), "shin_l": Vector3(-0.6, 0, 0)}, true))
			var tremble := raise.merged({"_gr": (raise["_gr"] as Vector3) + Vector3(0.005 * sin(h._t * 61.0), 0.007 * sin(h._t * 83.0), 0)}, true)
			return [h._keys(u, [[0.0, g], [1.0, tremble, "out"]]), "full", Vector3.ZERO]
		"gs_heavy":
			# the cleave: from overhead, straight down through them into the ground ahead, deep in the lunge
			var raise := _raised(SET)
			var hit := _cleaved({})
			var whoosh := PoleMoves._whip(raise, hit, 0.5, Vector3(0.95, 1.05, 1.08), 0.18)
			return [h._keys(u, [[0.0, raise], [0.12, whoosh, "in"], [0.2, hit, "out"], [0.56, hit], [1.0, g]]), "full", Vector3.ZERO]
		# --- moving ---
		"gs_rush":
			# Running Cleave (attacked at a sprint): out of the drag, the blade swung low round behind on the right, then
			# one flat sweep through them driving forward in a long lunge, carried round to the left
			var from := _k(PoleMoves._p([GUARD, SET, {"pivot": Vector3(-0.2, 0, 0), "_lift": Vector3(0, -0.1, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}]), TRAIL_GRIP)
			var drag := _k({"pivot": Vector3(-0.22, 0, 0), "hips": Vector3(0, -0.55, 0), "torso": Vector3(-0.3, -0.6, 0), "head": Vector3(0.3, 0.7, 0),
				"_lift": Vector3(0, -0.34, 0), "_scale": Vector3(1.04, 0.93, 1.03), "_smear": Vector3.ZERO}.merged(LUNGE),
				[Vector3(0.3, -0.42, 0.0), Vector3(0.65, -0.3, 0.7), Vector3(0.6, 0, -0.8), 0.2])
			var strike := _k({"pivot": Vector3(-0.15, 0, 0), "hips": Vector3(0, 0.45, 0), "torso": Vector3(-0.3, 0.5, 0), "head": Vector3(0.25, -0.6, 0),
				"_lift": Vector3(0, -0.4, 0), "_scale": Vector3(1.03, 0.95, 1.06), "_smear": Vector3.ZERO}.merged(LUNGE),
				[Vector3(0.0, -0.36, -0.48), Vector3(-0.15, -0.12, -0.98), Vector3(-1, 0, 0.1), 0.2])
			var whoosh := PoleMoves._whip(drag, strike, 0.5, Vector3(1.06, 0.97, 1.04), 0.14)
			return [h._keys(u, [[0.0, from], [0.16, drag, "out"], [0.3, drag], [0.38, whoosh, "in"], [0.44, strike, "linear"], [0.58, _left_out(), "out"], [0.74, _left_out()], [1.0, g]]), "full", Vector3.ZERO]
		"gs_dive":
			# Falling Cleave: knees tucked with the blade heaved up overhead, held there the whole way down
			var raise := _raised(TUCK)
			var fall := _raised({"torso": Vector3(0.15, 0, 0), "leg_l": Vector3(0.6, 0, -0.15), "shin_l": Vector3(-1.0, 0, 0),
				"leg_r": Vector3(0.2, 0, 0.15), "shin_r": Vector3(-0.8, 0, 0), "_scale": Vector3(0.97, 1.05, 1.0)})
			return [h._keys(u, [[0.0, g], [0.3, raise, "out"], [0.55, raise], [0.75, fall], [1.0, fall]]), "full", Vector3.ZERO]
		"gs_land":
			# Falling Cleave's landing: the blade driven down into the ground on impact, crouched deep over it
			var hit := _cleaved(SQUAT)
			return [h._keys(u, [[0.0, hit], [0.55, hit.merged({"_scale": Vector3.ONE}, true)], [1.0, g]]), "full", Vector3.ZERO]
		# --- the techniques (GreatswordArts; keyed in seconds of the length they're played at) ---
		"gs_guardbreak":
			# Guardbreaker: a short rising cut that knocks their guard up, the blade wheeled on up overhead, then brought
			# straight down on them
			var T: float = float(h._action.get("dur", 0.95))
			var load := _c1().merged({"hips": Vector3(0, 0.45, 0), "torso": Vector3(-0.2, 0.5, 0), "head": Vector3(0.15, -0.5, 0), "_lift": Vector3(0, -0.22, 0),
				"_gd": Vector3(-0.85, -0.45, 0.28)}, true)
			var rise := _k({"pivot": Vector3(-0.02, 0, 0), "hips": Vector3(0, -0.2, 0), "torso": Vector3(0.0, -0.25, 0), "head": Vector3(0.0, 0.25, 0),
				"_lift": Vector3(0, -0.12, 0), "_scale": Vector3(0.96, 1.06, 1.0), "_smear": Vector3(0.12, 0, 0)}.merged(STEP_R),
				[Vector3(0.05, -0.15, -0.5), Vector3(0.15, 0.6, -0.79), Vector3(0.2, 0.75, 0.6), 0.2])
			var up := _raised(SET)
			var crush := _cleaved({"_smear": Vector3(0.14, 0, 0)})
			var held := _cleaved({})
			return [h._keys(u, [[0.0, g], [0.1 / T, load, "out"], [0.22 / T, rise, "out"], [0.36 / T, up, "out"], [0.48 / T, up], [0.55 / T, crush, "in"],
				[0.75 / T, held], [1.0, g]]), "full", Vector3.ZERO]
		"gs_crescent":
			# Crescent Gale: the blade levelled behind on the left, then one huge flat sweep through the front that flings
			# a crescent of air off its edge, carried out past the right
			var T: float = float(h._action.get("dur", 0.8))
			var drop := _k({"pivot": Vector3(0.0, 0, 0), "hips": Vector3(0, 0.75, 0), "torso": Vector3(-0.05, 0.8, 0), "head": Vector3(0.1, -0.95, 0),
				"_lift": Vector3(0, -0.28, 0), "_scale": Vector3(1.06, 0.93, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
				[Vector3(-0.2, -0.32, -0.08), Vector3(-0.75, 0.0, 0.66), Vector3(-0.66, 0, -0.75), 0.2])
			var strike := _k({"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, -0.45, 0), "torso": Vector3(-0.15, -0.5, 0), "head": Vector3(0.1, 0.6, 0),
				"_lift": Vector3(0, -0.34, 0), "_scale": Vector3(1.06, 0.96, 1.02), "_smear": Vector3(0.16, 0, 0)}.merged(WIDE_R),
				[Vector3(0.05, -0.28, -0.5), Vector3(0.15, 0.04, -0.99), Vector3(1, 0, 0.1), 0.2])
			return [h._keys(u, [[0.0, g], [0.18 / T, drop, "out"], [0.24 / T, drop], [0.3 / T, strike, "linear"], [0.45 / T, _c4(), "out"], [0.6 / T, _c4()], [1.0, g]]), "full", Vector3.ZERO]
		"gs_tempest":
			# Tempest Turns: the blade let out at arm's length and the body turned round after it three times, each turn
			# quicker than the last, then brought through level and down into the guard
			var T: float = float(h._action.get("dur", 1.7))
			var s := u * T
			var turn := _k({"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, -0.15, 0), "torso": Vector3(-0.18, -0.15, 0), "head": Vector3(0.1, 0.1, 0),
				"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.05, 0.97, 1.0), "_smear": Vector3(0.12, 0, 0)}.merged(WIDE_R),
				[Vector3(0.08, -0.3, -0.45), Vector3(0.72, -0.06, -0.69), Vector3(0.66, 0, 0.75), 0.2])
			var finish := turn.merged({"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, -0.6, 0), "torso": Vector3(-0.25, -0.65, 0), "head": Vector3(0.2, 0.75, 0),
				"_lift": Vector3(0, -0.36, 0), "_smear": Vector3.ZERO, "_gd": Vector3(0.92, -0.1, -0.38), "_ge": Vector3(0.38, 0, 0.92)}, true)
			var pz: Dictionary = h._keys(u, [[0.0, g], [0.2 / T, turn, "out"], [1.35 / T, turn, "linear"], [1.45 / T, finish, "out"], [1.58 / T, finish], [1.0, g]])
			pz["pivot"] = (pz["pivot"] as Vector3) + Vector3(0, -TAU * 3.0 * tempest_k(s), 0)
			return [pz, "full", Vector3.ZERO]
		"gs_sky":
			# Skysplitter, the way up: a deep crouch, then up with the knees tucked and the blade heaved overhead, held
			# there (the landing plays gs_land)
			var crouch := _k({"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.3, -0.1, 0), "head": Vector3(0.25, 0.1, 0),
				"_lift": Vector3(0, -0.38, 0), "_scale": Vector3(1.07, 0.88, 1.0), "_smear": Vector3.ZERO}.merged(SQUAT), GUARD_GRIP)
			var up := _raised(TUCK)
			return [h._keys(u, [[0.0, g], [0.15, crouch, "out"], [0.2, crouch], [0.34, up, "out"], [1.0, up]]), "full", Vector3.ZERO]
		# --- the guard: the flat of the blade as a shield ---
		"gs_block":
			return [_k(PoleMoves._p([BLOCK, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.2, 0)}]), BLOCK_GRIP), "full", Vector3.ZERO]
		"gs_parry":
			# the blade snapped up in front, its flat to them, braced, then back
			var blk := _k(PoleMoves._p([BLOCK, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.02, 0.97, 1.0), "_smear": Vector3.ZERO}]), BLOCK_GRIP)
			return [h._keys(u, [[0.0, g], [0.12, blk, "out"], [0.6, blk], [1.0, g]]), "full", Vector3.ZERO]
		"gs_deflect":
			# the blow taken on the flat, then the blade shoved out into them with a step, turning it aside
			var blk := _k(PoleMoves._p([BLOCK, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.22, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}]), BLOCK_GRIP)
			var shove := _k({"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, 0.2, 0), "torso": Vector3(-0.22, 0.25, 0), "head": Vector3(0.2, -0.25, 0),
				"_lift": Vector3(0, -0.26, 0), "_scale": Vector3(0.97, 1.0, 1.07), "_smear": Vector3.ZERO}.merged(LUNGE),
				[Vector3(0.0, -0.36, -0.52), Vector3(-0.6, 0.75, -0.28), Vector3(0.5, 0.2, -0.85), 0.18])
			return [h._keys(u, [[0.0, blk], [0.3, shove, "out"], [0.6, shove], [1.0, g]]), "full", Vector3.ZERO]
	push_error("GreatswordMoves: no pose for \"%s\"" % n)
	return [g, "full", Vector3.ZERO]
