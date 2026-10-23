class_name GreatswordMoves
## The greatsword (stance "greatsword"): a long two-handed blade, the right hand at the pommel end of the grip and
## the left above it toward the guard. The guard is low and relaxed (Zach's reference, docs/weapons_plan.md): both
## hands on the hilt at the right hip, the blade a long diagonal down and forward across the body, its point near the
## ground on the left; moving, it's carried in the right hand down at the side, the point trailed low behind, and at a
## sprint the point drags and scrapes sparks off the ground (scrape()).
## Every move ("gs_*", reached from Humanoid._action_pose) keys the body plus the polearm's four grip channels
## (PoleMoves: "_gr" the right hand, "_gd" the blade's direction, "_ge" which way the edge faces, "_gs" the left
## hand's slide up the grip, < 0 one-handed; the chest's frame: x right, y up, z back), solved each frame by
## PoleMoves.hands; between keys the hand swings round the chest and the blade turns the short way (_arc).
## The combo flows: each blow's follow-through is the next one's wind-up ("carry" in ActionSpecs: a chained blow
## starts from where the last one ended, Humanoid._begin_action): out of the low guard up across to high right, the
## left hand letting go at the top (C2), taken again for the great falling diagonal down to low left (C1), a wide
## one-handed backhand flat round to the right (C4), and on round in a full turn at arm's length. The left hand also
## lets go for Running Cleave, Crescent Gale and Tempest Turns, and flings out against the cut. Same joint
## conventions as humanoid.gd.

## [right hand, blade, edge, left hand's slide] (chest frame). The low guard (Zach's reference, 2026-10-22): both hands at the
## right hip, the blade down and out to the right and a little behind, the point near the ground, the edge down.
const GUARD_GRIP := [Vector3(0.08, -0.56, -0.34), Vector3(0.76, -0.61, 0.2), Vector3(-0.59, -0.79, -0.15), 0.1]
## Sprinting: in the right hand alone down at the side, the point dragged along the ground behind.
const TRAIL_GRIP := [Vector3(0.36, -0.5, -0.02), Vector3(0.28, -0.86, 0.42), Vector3(0, -1, 0), -1.0]
## Moving (any direction, StanceLife's carry): the same, the point trailing low just off the ground.
const CARRY_GRIP := [Vector3(0.36, -0.5, 0.0), Vector3(0.36, -0.74, 0.57), Vector3(0, -1, 0), -1.0]
## The guard (block, parry): the blade stood up in front, point high, the flat turned to them like a shield.
const BLOCK_GRIP := [Vector3(0.06, -0.42, -0.42), Vector3(-0.22, 0.96, 0.12), Vector3(1, 0, 0), 0.18]
const GRIPS := [GUARD_GRIP, BLOCK_GRIP, TRAIL_GRIP, CARRY_GRIP]
## The free arm while the right hand swings alone: flung out back on the left against the cut, out level to the side
## for a turn's balance, reaching forward on a backhand's wind-up, pulled back by the hip under a forehand.
const FLING := {"arm_l": Vector3(-0.45, 0.1, -0.95), "fore_l": Vector3(0.45, 0, 0), "hand_l": Vector3.ZERO}
const OUT := {"arm_l": Vector3(0.25, 0.2, -1.3), "fore_l": Vector3(0.3, 0, 0), "hand_l": Vector3.ZERO}
const POINT := {"arm_l": Vector3(1.0, 0.35, -0.35), "fore_l": Vector3(0.45, 0, 0), "hand_l": Vector3.ZERO}
const PULL := {"arm_l": Vector3(-0.55, 0.0, -0.35), "fore_l": Vector3(1.3, 0, 0), "hand_l": Vector3.ZERO}
## The hands swing round this point (chest frame, about the breastbone) between keys, not straight across.
const ARC_C := Vector3(0, -0.3, 0)

## The guard: upright and easy, the chest turned a little toward the blade, eyes down its line. The arms seed the IK.
const GUARD := {"hips": Vector3(0, -0.3, 0), "torso": Vector3(-0.12, -0.32, 0), "head": Vector3(0.28, 0.4, 0),
	"arm_r": Vector3(0.3, 0.0, 0.25), "fore_r": Vector3(0.7, 0, 0), "hand_r": Vector3.ZERO,
	"arm_l": Vector3(0.6, -0.45, -0.1), "fore_l": Vector3(0.9, 0, 0), "hand_l": Vector3.ZERO}
## The stance's feet (Humanoid.STANCE_LEGS): a relaxed stance, the left foot a little forward.
const LEGS := {"leg_l": Vector3(0.3, 0, -0.2), "leg_r": Vector3(-0.25, 0, 0.22), "shin_l": Vector3(-0.4, 0, 0), "shin_r": Vector3(-0.35, 0, 0),
	"_lift": Vector3(0, -0.08, 0)}
const BLOCK := {"hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.1, -0.08, 0), "head": Vector3(0.12, 0.1, 0),
	"arm_r": Vector3(1.0, 0.2, 0.3), "fore_r": Vector3(1.0, 0, 0), "arm_l": Vector3(1.1, -0.3, -0.3), "fore_l": Vector3(1.2, 0, 0)}
## Sprinting: how often the dragged point throws sparks (s), and how near the ground it must be (m).
const SCRAPE_EVERY := 0.07
const SCRAPE_H := 0.12

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


## A key part way into a strike (PoleMoves._whip's body: stretched along the motion, smeared) with its own grip, so the
## blade turns round the way it should between two far-apart directions instead of a blend through the body.
static func _mid(a: Dictionary, b: Dictionary, sc: Vector3, smear: float, grip: Array, body: Dictionary = {}) -> Dictionary:
	return _k(PoleMoves._whip(a, b, 0.5, sc, smear).merged(body, true), grip)


## Humanoid._keys with the grip swung on arcs: the right hand round ARC_C (its distance eased between the keys'), the
## blade turned the short way round. A straight blend cuts chords through the body and shrinks every swing.
static func _arc(h, u: float, keys: Array) -> Dictionary:
	var out: Dictionary = h._keys(u, keys)
	if u <= keys[0][0] or u >= keys[keys.size() - 1][0]:
		return out
	var i := 0
	while u > keys[i + 1][0]:
		i += 1
	var a: Dictionary = keys[i][1]
	var b: Dictionary = keys[i + 1][1]
	var span := Vector3.ZERO
	var at := ""
	for c in ["_gr", "_gd", "pivot", "torso", "hips", "_lift"]:
		if a.has(c) and b.has(c) and ((b[c] as Vector3) - (a[c] as Vector3)).length() > span.length():
			span = (b[c] as Vector3) - (a[c] as Vector3)
			at = c
	if at == "":
		return out
	var k: float = ((out[at] as Vector3) - (a[at] as Vector3)).dot(span) / span.length_squared()
	var pa: Vector3 = (a["_gr"] as Vector3) - ARC_C
	var pb: Vector3 = (b["_gr"] as Vector3) - ARC_C
	out["_gr"] = ARC_C + pa.normalized().slerp(pb.normalized(), k) * lerpf(pa.length(), pb.length(), k)
	out["_gd"] = (a["_gd"] as Vector3).normalized().slerp((b["_gd"] as Vector3).normalized(), k)
	return out


static func pose(h, n: String, u: float) -> Array:
	return PoleMoves.take_grip(h, _pose(h, n, u))


## Tempest Turns: how far through its three turns the body is at `s` seconds (0..1), each turn quicker than the last.
const TEMPEST := Vector2(0.2, 1.35)


static func tempest_k(s: float) -> float:
	return pow(clampf((s - TEMPEST.x) / (TEMPEST.y - TEMPEST.x), 0.0, 1.0), 1.6)


## Sprinting with the point dragged behind: every SCRAPE_EVERY s, sparks where the blade meets the ground (local to each
## screen, like the grip; nothing far off: FX culls bursts out of range). Called once the grip is solved this frame, on
## the blade as drawn (interpolated), so the sparks sit on the point.
static func scrape(h, delta: float) -> void:
	h.gs_scrape -= delta
	if h.gs_scrape > 0.0:
		return
	h.gs_scrape = SCRAPE_EVERY
	var at: Vector3 = scrape_at(h)
	if not at.is_finite():
		return
	var fx = h.get_node_or_null("/root/FX")
	if fx != null:
		fx.muzzle_sparks(at, (h.global_basis.z.normalized() + Vector3.UP * 0.6).normalized(), 3, Color(1.0, 0.82, 0.45))


## Where the dragged blade meets the ground (the point, or where the blade dips under the feet' level before it), or
## INF while the point is more than SCRAPE_H up.
static func scrape_at(h) -> Vector3:
	var w: MeshInstance3D = h.weapon
	var t: Transform3D = w.get_global_transform_interpolated()
	var tip: Vector3 = t * Vector3(0, 0, w.mesh.get_aabb().position.z * 0.97)
	var guard: Vector3 = t * Vector3(0, 0, -WeaponDesigns.GREAT_GUARD)
	var feet: float = (h as Node3D).get_global_transform_interpolated().origin.y
	if tip.y - feet > SCRAPE_H:
		return Vector3.INF
	if tip.y >= feet or guard.y <= feet:
		return tip
	return guard.lerp(tip, (guard.y - feet) / (guard.y - tip.y))


# --------------------------------------------------------------------------
# The combo's carries: where each blow's follow-through ends and the next one starts
# --------------------------------------------------------------------------
## C1: brought down across in both hands, the blade carried on round low past the left hip, the body wound left.
static func _c1() -> Dictionary:
	return _k({"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, 0.7, 0), "torso": Vector3(-0.3, 0.75, 0), "head": Vector3(0.22, -0.8, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.04, 0.95, 1.0), "_smear": Vector3.ZERO}.merged(WIDE),
		[Vector3(-0.3, -0.45, -0.32), Vector3(-0.8, -0.42, 0.42), Vector3(-0.25, -0.2, 0.95), 0.2])


## C2: swept up through the front and on up over the right shoulder in the right hand alone, the blade hanging back
## behind it, the left arm flung back, the body wound right.
static func _c2() -> Dictionary:
	return _k({"pivot": Vector3(0.04, 0, 0), "hips": Vector3(0, -0.55, 0), "torso": Vector3(0.1, -0.6, 0), "head": Vector3(-0.05, 0.62, 0),
		"_lift": Vector3(0, -0.1, 0), "_scale": Vector3(0.97, 1.05, 1.0), "_smear": Vector3.ZERO}.merged(STEP_R).merged(FLING),
		[Vector3(0.4, 0.28, -0.08), Vector3(0.38, 0.62, 0.69), Vector3(0.25, 0.4, 0.88), -1.0])


## C4: the backhand carried out past the right side at arm's length in the right hand alone, the body wound right.
static func _c4() -> Dictionary:
	return _k({"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, -0.7, 0), "torso": Vector3(-0.12, -0.72, 0), "head": Vector3(0.08, 0.9, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.03, 0.97, 1.0), "_smear": Vector3.ZERO}.merged(WIDE_R).merged(FLING),
		[Vector3(0.58, -0.22, -0.18), Vector3(0.88, -0.05, 0.45), Vector3(0.45, 0, 0.88), -1.0])


## Swept flat out past the left side in the right hand, the body wound left (the running cleave's follow-through).
static func _left_out() -> Dictionary:
	return _k({"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, 0.85, 0), "torso": Vector3(-0.12, 0.9, 0), "head": Vector3(0.08, -1.05, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.03, 0.97, 1.0), "_smear": Vector3.ZERO}.merged(WIDE).merged(PULL),
		[Vector3(-0.2, -0.32, -0.42), Vector3(-0.86, -0.05, 0.5), Vector3(-0.5, 0, 0.86), -1.0])


## Raised for the cleave: both hands over the head, the blade hanging back behind it, the back arched.
static func _raised(body: Dictionary) -> Dictionary:
	return _k({"pivot": Vector3(0.1, 0, 0), "hips": Vector3(0, -0.08, 0), "torso": Vector3(0.25, -0.08, 0), "head": Vector3(-0.2, 0.08, 0),
		"_lift": Vector3(0, -0.12, 0), "_scale": Vector3(0.96, 1.07, 1.0), "_smear": Vector3.ZERO}.merged(body, true),
		[Vector3(0.06, 0.4, -0.08), Vector3(0.05, -0.3, 0.95), Vector3(0, 0.95, 0.3), 0.2])


## Out of the low guard to the left: the point lifted forward first, so drawn back it passes over the left knee.
const LIFT_GRIP := [Vector3(0.05, -0.45, -0.42), Vector3(-0.66, -0.12, -0.74), Vector3(0, -1, 0), 0.2]


static func _lift(g: Dictionary, load: Dictionary) -> Dictionary:
	return _k(PoleMoves._whip(g, load, 0.35, Vector3.ONE, 0.0), LIFT_GRIP)


## Over the top on the way down from raised: the blade stood straight up over the head, the edge leading forward.
const TOP_GRIP := [Vector3(0.05, 0.32, -0.38), Vector3(0.0, 0.92, -0.4), Vector3(0, -0.4, -0.92), 0.2]


## The cleave driven down in front: bent deep over it, the point biting the ground ahead. (The grip's channels are in
## the chest's frame: bent this far forward, a blade near level in that frame already points down at the ground.)
static func _cleaved(body: Dictionary) -> Dictionary:
	return _k({"pivot": Vector3(-0.25, 0, 0), "hips": Vector3(0, 0.05, 0), "torso": Vector3(-0.45, 0.05, 0), "head": Vector3(0.42, -0.05, 0),
		"_lift": Vector3(0, -0.42, 0), "_scale": Vector3(1.08, 0.9, 1.04), "_smear": Vector3.ZERO}.merged(LUNGE).merged(body, true),
		[Vector3(0.0, -0.15, -0.55), Vector3(0.0, 0.4, -0.92), Vector3(0, -0.92, -0.4), 0.2])


## Guardbreaker's crush: the cleave from standing (the full _cleaved is a landing's, bent near prone over it).
const BREAK_CRUSH := {"pivot": Vector3(-0.12, 0, 0), "torso": Vector3(-0.3, 0.05, 0), "head": Vector3(0.3, -0.05, 0), "_lift": Vector3(0, -0.28, 0)}


## The short rising cut (Guardbreaker's, Updraft's, Gatekeeper's release): low on the right swept up through the front.
static func _rising() -> Dictionary:
	return _k({"pivot": Vector3(-0.02, 0, 0), "hips": Vector3(0, -0.2, 0), "torso": Vector3(0.0, -0.25, 0), "head": Vector3(0.0, 0.25, 0),
		"_lift": Vector3(0, -0.12, 0), "_scale": Vector3(0.96, 1.06, 1.0), "_smear": Vector3(0.12, 0, 0)}.merged(STEP_R),
		[Vector3(0.05, -0.15, -0.5), Vector3(0.15, 0.6, -0.79), Vector3(0.2, 0.75, 0.6), 0.2])


## Gatekeeper's gate: the blade point-down in the ground before you, hands on the pommel, the flat to them; `sunk`
## leans on it harder (the plant's give, the release's dip).
const GATE_GRIP := [Vector3(0.0, -0.32, -0.46), Vector3(0.0, -0.97, -0.24), Vector3(1, 0, 0), 0.14]


static func _gate(sunk: bool) -> Dictionary:
	return _k({"pivot": Vector3(-0.1 if sunk else -0.05, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.18 if sunk else -0.1, 0, 0), "head": Vector3(0.1, 0, 0),
		"_lift": Vector3(0, -0.36 if sunk else -0.26, 0), "_scale": Vector3(1.04, 0.95, 1.0) if sunk else Vector3.ONE, "_smear": Vector3.ZERO}.merged(WIDE),
		GATE_GRIP)


## On the way back to the low guard (on the right) from the left: the blade carried forward and down out in front of the
## legs first, so it never cuts back across through the thighs; both hands on it again.
static func _ahead(from: Dictionary) -> Dictionary:
	return from.merged({"_gr": Vector3(0.05, -0.38, -0.5), "_gd": Vector3(0.25, -0.45, -0.86), "_ge": Vector3(0, -0.89, 0.46), "_gs": Vector3(0.15, 0, 0)}, true)


## On the way back to the low guard from the right: the blade lowered through the front on the right first, so it never
## turns over the top or down through the legs; the left hand takes the grip again.
static func _lowering(from: Dictionary) -> Dictionary:
	return from.merged({"_gr": Vector3(0.15, -0.4, -0.35), "_gd": Vector3(0.45, -0.25, -0.86), "_ge": Vector3(0, -1, 0), "_gs": Vector3(0.2, 0, 0)}, true)


## The one-handed backhand's wind-up (gs_3, Crescent Gale): the right hand across at the left hip, the blade levelled
## behind on the left, the left arm pointing at them, the body wound left.
static func _backhand_load(lift: float) -> Dictionary:
	return _k({"pivot": Vector3(0.0, 0, 0), "hips": Vector3(0, 0.7, 0), "torso": Vector3(-0.05, 0.75, 0), "head": Vector3(0.1, -0.9, 0),
		"_lift": Vector3(0, lift, 0), "_scale": Vector3(1.05, 0.94, 1.0), "_smear": Vector3.ZERO}.merged(WIDE).merged(POINT),
		[Vector3(-0.22, -0.3, -0.2), Vector3(-0.72, 0.0, 0.7), Vector3(-0.66, 0, -0.75), -1.0])


## The backhand meeting them: the arm long out in front, the blade level and pointed ahead, sweeping right, the left
## arm flung back.
static func _backhand_hit(lift: float, smear: float) -> Dictionary:
	return _k({"pivot": Vector3(-0.08, 0, 0), "hips": Vector3(0, -0.35, 0), "torso": Vector3(-0.15, -0.35, 0), "head": Vector3(0.1, 0.45, 0),
		"_lift": Vector3(0, lift, 0), "_scale": Vector3(1.04, 0.97, 1.0), "_smear": Vector3(smear, 0, 0)}.merged(WIDE_R).merged(FLING),
		[Vector3(0.22, -0.3, -0.56), Vector3(0.25, -0.02, -0.97), Vector3(0.97, 0, 0.25), -1.0])


## Between those two: the blade sweeping round the left side into the front.
const BACKHAND_MID := [Vector3(-0.1, -0.3, -0.5), Vector3(-0.95, -0.02, -0.3), Vector3(0.3, 0, -0.95), -1.0]


## A turn at arm's length (Gale Turn, Tempest Turns): the blade out on the right in the right hand, trailing the turn,
## the left arm out for balance; and the finish, brought through level in front.
static func _turn() -> Dictionary:
	return _k({"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, -0.15, 0), "torso": Vector3(-0.18, -0.15, 0), "head": Vector3(0.1, 0.1, 0),
		"_lift": Vector3(0, -0.3, 0), "_scale": Vector3(1.05, 0.97, 1.0), "_smear": Vector3(0.12, 0, 0)}.merged(WIDE_R).merged(OUT),
		[Vector3(0.5, -0.28, -0.3), Vector3(0.75, -0.08, -0.65), Vector3(0.66, 0, 0.75), -1.0])


static func _turn_finish(turn: Dictionary) -> Dictionary:
	return turn.merged({"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, -0.6, 0), "torso": Vector3(-0.25, -0.65, 0), "head": Vector3(0.2, 0.75, 0),
		"_lift": Vector3(0, -0.36, 0), "_scale": Vector3(1.06, 0.93, 1.02), "_smear": Vector3.ZERO,
		"_gr": Vector3(0.55, -0.26, -0.22), "_gd": Vector3(0.92, -0.1, -0.38), "_ge": Vector3(0.38, 0, 0.92)}, true).merged(FLING, true)


static func _pose(h, n: String, u: float) -> Array:
	var g := _g()
	match n:
		"gs_stance":
			return [g, "full", Vector3.ZERO]
		# --- the combo ---
		"gs_1":
			# hit 1, out of the low guard: the point drawn back low on the left, then swept up through the front from low
			# left to high right, stepping through on the right foot; the left hand lets go at the top and the right
			# carries it on up over the right shoulder, the left arm flung back (C2)
			var load := _c1().merged({"hips": Vector3(0, 0.55, 0), "torso": Vector3(-0.25, 0.6, 0), "head": Vector3(0.2, -0.6, 0), "_lift": Vector3(0, -0.24, 0),
				"leg_l": Vector3(0.5, 0, -0.3), "_gr": Vector3(-0.22, -0.4, -0.36), "_gd": Vector3(-0.72, -0.25, 0.64), "_ge": Vector3(0.15, 0.1, -0.98)}, true)
			var strike := _k({"pivot": Vector3(-0.02, 0, 0), "hips": Vector3(0, -0.15, 0), "torso": Vector3(-0.05, -0.25, 0), "head": Vector3(0.05, 0.25, 0),
				"_lift": Vector3(0, -0.14, 0), "_scale": Vector3(0.96, 1.06, 1.0), "_smear": Vector3(0.1, 0, 0)}.merged(STEP_R),
				[Vector3(0.12, -0.25, -0.55), Vector3(0.25, 0.35, -0.9), Vector3(0.55, 0.7, 0.45), 0.2])
			var whoosh := _mid(load, strike, Vector3(0.97, 1.07, 1.02), 0.12,
				[Vector3(-0.08, -0.42, -0.52), Vector3(-0.55, -0.45, -0.7), Vector3(0.7, 0.7, 0), 0.2])
			var free := _k({"pivot": Vector3(0.02, 0, 0), "hips": Vector3(0, -0.4, 0), "torso": Vector3(0.05, -0.45, 0), "head": Vector3(-0.02, 0.45, 0),
				"_lift": Vector3(0, -0.12, 0), "_scale": Vector3(0.97, 1.05, 1.0), "_smear": Vector3(0.06, 0, 0)}.merged(STEP_R).merged(FLING),
				[Vector3(0.42, 0.1, -0.4), Vector3(0.5, 0.8, -0.33), Vector3(0.4, 0.3, 0.87), -1.0])
			var c2 := _c2()
			return [_arc(h, u, [[0.0, g], [0.07, _lift(g, load)], [0.18, load, "out"], [0.27, whoosh, "in"], [0.33, strike, "linear"], [0.4, free, "linear"],
				[0.52, c2, "out"], [0.66, c2], [0.82, _lowering(g)], [1.0, g]]), "full", Vector3.ZERO]
		"gs_2":
			# hit 2, out of C2: both hands on it again as the blade's weight turns at the top by the right ear, then one great
			# diagonal over the top and down through the front to low left, the body turning after it, carried on round
			# past the left hip (C1)
			var c2 := _c2()
			var wind := _k({"pivot": Vector3(0.06, 0, 0), "hips": Vector3(0, -0.45, 0), "torso": Vector3(0.12, -0.5, 0.04), "head": Vector3(-0.04, 0.55, 0),
				"_lift": Vector3(0, -0.1, 0), "_scale": Vector3(0.97, 1.05, 1.0), "_smear": Vector3.ZERO}.merged(SET),
				[Vector3(0.22, 0.2, -0.2), Vector3(0.2, 0.72, 0.66), Vector3(0.0, 0.6, -0.8), 0.2])
			var strike := _k({"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, 0.35, 0), "torso": Vector3(-0.3, 0.4, 0), "head": Vector3(0.25, -0.4, 0),
				"_lift": Vector3(0, -0.28, 0), "_scale": Vector3(1.05, 0.94, 1.02), "_smear": Vector3(0.1, 0, 0)}.merged(LUNGE),
				[Vector3(0.0, -0.22, -0.52), Vector3(-0.45, -0.25, -0.86), Vector3(-0.6, -0.75, 0.25), 0.2])
			var top := _mid(wind, strike, Vector3(0.97, 1.02, 1.08), 0.12,
				[Vector3(0.15, 0.08, -0.42), Vector3(0.12, 0.9, -0.42), Vector3(-0.25, -0.4, -0.88), 0.2])
			return [_arc(h, u, [[0.0, c2], [0.14, wind, "out"], [0.2, wind], [0.27, top, "in"], [0.33, strike, "linear"], [0.5, _c1(), "out"],
				[0.66, _c1()], [1.0, g]]), "full", Vector3.ZERO]
		"gs_3":
			# hit 3, out of C1: the left hand lets go and points at them, the blade levelled behind on the left, then one
			# wide flat backhand at arm's length through the front and on round to the right in a wide low stance (it
			# breaks a guard), the left arm flung back, carried out past the right side (C4); lowered on the right and
			# taken in both hands again
			var drop := _backhand_load(-0.26)
			var strike := _backhand_hit(-0.32, 0.1)
			var mid := _mid(drop, strike, Vector3(1.08, 0.97, 1.0), 0.14, BACKHAND_MID)
			return [_arc(h, u, [[0.0, _c1()], [0.16, drop, "out"], [0.22, drop], [0.3, mid, "in"], [0.36, strike, "linear"], [0.5, _c4(), "out"],
				[0.66, _c4()], [0.84, _lowering(g)], [1.0, g]]), "full", Vector3.ZERO]
		"gs_4":
			# hit 4 (Gale Turn), out of C4: the sweep's momentum let carry the whole body on round once more with the
			# blade out at arm's length in the right hand, then brought through level in front, lowered and taken in both
			# hands into the low guard
			var c4 := _c4()
			var turn := _turn()
			var finish := _turn_finish(turn)
			var pz: Dictionary = _arc(h, u, [[0.0, c4], [0.12, turn, "in"], [0.6, turn, "linear"], [0.7, finish, "out"], [0.84, finish],
				[0.92, _lowering(g)], [1.0, g]])
			var k := clampf((u - 0.08) / 0.56, 0.0, 1.0)
			pz["pivot"] = (pz["pivot"] as Vector3) + Vector3(-0.05 * sin(k * PI), -TAU * k, 0)
			return [pz, "full", Vector3.ZERO]
		# --- the heavy: held raised while it charges (gs_charge, Humanoid.hold), then the cleave (gs_heavy) ---
		"gs_charge":
			# swung up through the front (never down across the legs) and over into the raise
			var raise := _raised(SET.merged({"leg_l": Vector3(0.5, 0, -0.25), "shin_l": Vector3(-0.6, 0, 0)}, true))
			var up := raise.merged(_k({}, [Vector3(0.15, 0.0, -0.4), Vector3(-0.05, 0.95, -0.3), Vector3(0, 0.3, 0.95), 0.2]), true)
			var tremble := raise.merged({"_gr": (raise["_gr"] as Vector3) + Vector3(0.005 * sin(h._t * 61.0), 0.007 * sin(h._t * 83.0), 0)}, true)
			return [_arc(h, u, [[0.0, g], [0.45, up], [1.0, tremble, "out"]]), "full", Vector3.ZERO]
		"gs_heavy":
			# the cleave: from overhead, over the top and straight down through them into the ground ahead, deep in the lunge
			var raise := _raised(SET)
			var hit := _cleaved({})
			var top := _mid(raise, hit, Vector3(0.95, 1.05, 1.08), 0.18, TOP_GRIP)
			return [_arc(h, u, [[0.0, raise], [0.1, top, "in"], [0.18, hit, "out"], [0.56, hit], [1.0, g]]), "full", Vector3.ZERO]
		# --- moving ---
		"gs_rush":
			# Running Cleave (attacked at a sprint): out of the drag, the blade swung low round behind on the right in the
			# right hand, then one flat sweep through them driving forward in a long lunge, carried round to the left
			var from := _k(PoleMoves._p([GUARD, SET, FLING, {"pivot": Vector3(-0.2, 0, 0), "_lift": Vector3(0, -0.1, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}]), TRAIL_GRIP)
			var drag := _k({"pivot": Vector3(-0.22, 0, 0), "hips": Vector3(0, -0.55, 0), "torso": Vector3(-0.3, -0.6, 0), "head": Vector3(0.3, 0.7, 0),
				"_lift": Vector3(0, -0.34, 0), "_scale": Vector3(1.04, 0.93, 1.03), "_smear": Vector3.ZERO}.merged(LUNGE).merged(FLING),
				[Vector3(0.32, -0.42, 0.0), Vector3(0.65, -0.3, 0.7), Vector3(0.6, 0, -0.8), -1.0])
			var strike := _k({"pivot": Vector3(-0.15, 0, 0), "hips": Vector3(0, 0.45, 0), "torso": Vector3(-0.3, 0.5, 0), "head": Vector3(0.25, -0.6, 0),
				"_lift": Vector3(0, -0.4, 0), "_scale": Vector3(1.03, 0.95, 1.06), "_smear": Vector3(0.1, 0, 0)}.merged(LUNGE).merged(PULL),
				[Vector3(0.05, -0.34, -0.6), Vector3(-0.15, -0.12, -0.98), Vector3(-1, 0, 0.1), -1.0])
			var mid := _mid(drag, strike, Vector3(1.06, 0.97, 1.04), 0.14,
				[Vector3(0.38, -0.36, -0.35), Vector3(0.97, -0.15, -0.2), Vector3(-0.2, 0, -0.98), -1.0])
			return [_arc(h, u, [[0.0, from], [0.16, drag, "out"], [0.3, drag], [0.37, mid, "in"], [0.44, strike, "linear"], [0.58, _left_out(), "out"],
				[0.74, _left_out()], [0.86, _ahead(g)], [1.0, g]]), "full", Vector3.ZERO]
		"gs_dive":
			# Falling Cleave: knees tucked with the blade heaved up overhead, held there the whole way down
			var raise := _raised(TUCK)
			var fall := _raised({"torso": Vector3(0.15, 0, 0), "leg_l": Vector3(0.6, 0, -0.15), "shin_l": Vector3(-1.0, 0, 0),
				"leg_r": Vector3(0.2, 0, 0.15), "shin_r": Vector3(-0.8, 0, 0), "_scale": Vector3(0.97, 1.05, 1.0)})
			var up := raise.merged(_k({}, [Vector3(0.15, 0.0, -0.4), Vector3(-0.05, 0.95, -0.3), Vector3(0, 0.3, 0.95), 0.2]), true)
			return [_arc(h, u, [[0.0, g], [0.15, up], [0.3, raise, "out"], [0.55, raise], [0.75, fall], [1.0, fall]]), "full", Vector3.ZERO]
		"gs_land":
			# Falling Cleave's landing: the blade driven down into the ground on impact, crouched deep over it
			var hit := _cleaved(SQUAT)
			return [_arc(h, u, [[0.0, hit], [0.55, hit.merged({"_scale": Vector3.ONE}, true)], [1.0, g]]), "full", Vector3.ZERO]
		# --- the techniques (GreatswordArts; keyed in seconds of the length they're played at) ---
		"gs_guardbreak":
			# Guardbreaker: a short rising cut that knocks their guard up, the blade wheeled on up and over overhead, then
			# brought over the top and straight down on them
			var T: float = float(h._action.get("dur", 0.95))
			var load := _c1().merged({"hips": Vector3(0, 0.45, 0), "torso": Vector3(-0.2, 0.5, 0), "head": Vector3(0.15, -0.5, 0), "_lift": Vector3(0, -0.22, 0),
				"pivot": Vector3.ZERO, "_gr": Vector3(-0.22, -0.4, -0.36), "_gd": Vector3(-0.72, -0.25, 0.64)}, true).merged(SET, true)
			var rise := _k({"pivot": Vector3(-0.02, 0, 0), "hips": Vector3(0, -0.2, 0), "torso": Vector3(0.0, -0.25, 0), "head": Vector3(0.0, 0.25, 0),
				"_lift": Vector3(0, -0.12, 0), "_scale": Vector3(0.96, 1.06, 1.0), "_smear": Vector3(0.12, 0, 0)}.merged(STEP_R),
				[Vector3(0.05, -0.15, -0.5), Vector3(0.15, 0.6, -0.79), Vector3(0.2, 0.75, 0.6), 0.2])
			var up := _raised(SET)
			var over := _mid(rise, up, Vector3(0.97, 1.05, 1.0), 0.06, [Vector3(0.1, 0.3, -0.3), Vector3(0.1, 0.97, 0.2), Vector3(0, -0.2, 0.98), 0.2])
			# (driven down on them from standing, not sprawled over it: 2026-10-22, the full cleave overshot near prone)
			var crush := _cleaved(BREAK_CRUSH.merged({"_smear": Vector3(0.14, 0, 0)}))
			var top := _mid(up, crush, Vector3(0.95, 1.05, 1.08), 0.16, TOP_GRIP)
			var held := _cleaved(BREAK_CRUSH)
			return [_arc(h, u, [[0.0, g], [0.06 / T, _lift(g, load)], [0.13 / T, load, "out"], [0.22 / T, rise, "out"], [0.29 / T, over], [0.36 / T, up, "out"], [0.47 / T, up],
				[0.52 / T, top, "in"], [0.57 / T, crush, "out"], [0.75 / T, held], [1.0, g]]), "full", Vector3.ZERO]
		"gs_updraft":
			# Updraft: low and wound to the right, a short rising cut that tears up under them, then up after them with the
			# knees tucked and the blade heaved overhead, over the top and down in a cleave at the top of the leap (the
			# landing plays gs_land)
			var T: float = float(h._action.get("dur", 1.0))
			var load := _c1().merged({"hips": Vector3(0, 0.45, 0), "torso": Vector3(-0.2, 0.5, 0), "head": Vector3(0.15, -0.5, 0), "_lift": Vector3(0, -0.3, 0),
				"pivot": Vector3.ZERO, "_gr": Vector3(-0.22, -0.4, -0.36), "_gd": Vector3(-0.72, -0.25, 0.64)}, true).merged(SQUAT, true)
			var rise := _rising()
			var up := _raised(TUCK)
			var over := _mid(rise, up, Vector3(0.97, 1.05, 1.0), 0.06, [Vector3(0.1, 0.3, -0.3), Vector3(0.1, 0.97, 0.2), Vector3(0, -0.2, 0.98), 0.2])
			var crush := _cleaved(TUCK.merged({"pivot": Vector3(-0.15, 0, 0), "_lift": Vector3(0, -0.15, 0), "_smear": Vector3(0.14, 0, 0)}))
			var top := _mid(up, crush, Vector3(0.95, 1.05, 1.08), 0.16, TOP_GRIP)
			var held := _cleaved(TUCK.merged({"pivot": Vector3(-0.15, 0, 0), "_lift": Vector3(0, -0.15, 0)}))
			return [_arc(h, u, [[0.0, g], [0.06 / T, _lift(g, load)], [0.14 / T, load, "out"], [0.22 / T, rise, "out"], [0.3 / T, over], [0.42 / T, up, "out"],
				[0.58 / T, up], [0.64 / T, top, "in"], [0.7 / T, crush, "out"], [0.82 / T, held], [1.0, held]]), "full", Vector3.ZERO]
		"gs_gate":
			# Gatekeeper, held: the blade driven point-down into the ground before you, both hands on the pommel, its flat to
			# them, braced wide behind it (played at the hold's longest; the release plays gs_gate_rise)
			var T: float = float(h._action.get("dur", 1.5))
			var gate := _gate(false)
			return [_arc(h, u, [[0.0, g], [0.08 / T, _ahead(g)], [0.18 / T, gate, "out"], [0.24 / T, _gate(true)], [0.32 / T, gate], [1.0, gate]]), "full", Vector3.ZERO]
		"gs_gate_rise":
			# Gatekeeper's release: sunk on it a moment, then wrenched up out of the ground in a rising cut carried on overhead
			var T: float = float(h._action.get("dur", 0.6))
			var gate := _gate(false)
			var up := _raised(SET)
			return [_arc(h, u, [[0.0, gate], [0.07 / T, _gate(true)], [0.16 / T, _rising(), "out"], [0.28 / T, up, "out"], [0.42 / T, up], [1.0, g]]), "full", Vector3.ZERO]
		"gs_crescent":
			# Crescent Gale: the left hand lets go, the blade levelled behind on the left, then one huge flat backhand at
			# arm's length through the front that flings a crescent of air off its edge, carried out past the right
			var T: float = float(h._action.get("dur", 0.8))
			var drop := _backhand_load(-0.28)
			var strike := _backhand_hit(-0.34, 0.16)
			var mid := _mid(drop, strike, Vector3(1.08, 0.97, 1.0), 0.16, BACKHAND_MID)
			return [_arc(h, u, [[0.0, g], [0.06 / T, _lift(g, drop)], [0.16 / T, drop, "out"], [0.21 / T, drop], [0.27 / T, mid, "in"], [0.31 / T, strike, "linear"],
				[0.45 / T, _c4(), "out"], [0.58 / T, _c4()], [0.7 / T, _lowering(g)], [1.0, g]]), "full", Vector3.ZERO]
		"gs_tempest":
			# Tempest Turns: the blade let out at arm's length in the right hand and the body turned round after it three
			# times, each turn quicker than the last, then brought through level, lowered and taken in both hands
			var T: float = float(h._action.get("dur", 1.7))
			var s := u * T
			var turn := _turn()
			var finish := _turn_finish(turn)
			var pz: Dictionary = _arc(h, u, [[0.0, g], [0.2 / T, turn, "out"], [1.35 / T, turn, "linear"], [1.45 / T, finish, "out"], [1.56 / T, finish],
				[1.64 / T, _lowering(g)], [1.0, g]])
			pz["pivot"] = (pz["pivot"] as Vector3) + Vector3(0, -TAU * 3.0 * tempest_k(s), 0)
			return [pz, "full", Vector3.ZERO]
		"gs_sky":
			# Skysplitter, the way up: a deep crouch, then up with the knees tucked and the blade heaved overhead, held
			# there (the landing plays gs_land)
			var crouch := _k({"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, -0.1, 0), "torso": Vector3(-0.3, -0.1, 0), "head": Vector3(0.25, 0.1, 0),
				"_lift": Vector3(0, -0.38, 0), "_scale": Vector3(1.07, 0.88, 1.0), "_smear": Vector3.ZERO}.merged(SQUAT), GUARD_GRIP)
			var raise := _raised(TUCK)
			var up := raise.merged(_k({}, [Vector3(0.15, 0.0, -0.4), Vector3(-0.05, 0.95, -0.3), Vector3(0, 0.3, 0.95), 0.2]), true)
			return [_arc(h, u, [[0.0, g], [0.15, crouch, "out"], [0.2, crouch], [0.27, up, "out"], [0.34, raise, "out"], [1.0, raise]]), "full", Vector3.ZERO]
		# --- the guard: the flat of the blade as a shield ---
		"gs_block":
			return [_k(PoleMoves._p([BLOCK, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.2, 0)}]), BLOCK_GRIP), "full", Vector3.ZERO]
		"gs_parry":
			# the blade snapped up in front, its flat to them, braced, then back
			var blk := _k(PoleMoves._p([BLOCK, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.02, 0.97, 1.0), "_smear": Vector3.ZERO}]), BLOCK_GRIP)
			return [_arc(h, u, [[0.0, g], [0.12, blk, "out"], [0.6, blk], [1.0, g]]), "full", Vector3.ZERO]
		"gs_deflect":
			# the blow taken on the flat, then the blade shoved out into them with a step, turning it aside
			var blk := _k(PoleMoves._p([BLOCK, SET, {"pivot": Vector3.ZERO, "_lift": Vector3(0, -0.22, 0), "_scale": Vector3.ONE, "_smear": Vector3.ZERO}]), BLOCK_GRIP)
			var shove := _k({"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, 0.2, 0), "torso": Vector3(-0.22, 0.25, 0), "head": Vector3(0.2, -0.25, 0),
				"_lift": Vector3(0, -0.26, 0), "_scale": Vector3(0.97, 1.0, 1.07), "_smear": Vector3.ZERO}.merged(LUNGE),
				[Vector3(0.0, -0.36, -0.52), Vector3(-0.6, 0.75, -0.28), Vector3(0.5, 0.2, -0.85), 0.18])
			return [_arc(h, u, [[0.0, blk], [0.3, shove, "out"], [0.6, shove], [1.0, g]]), "full", Vector3.ZERO]
	push_error("GreatswordMoves: no pose for \"%s\"" % n)
	return [g, "full", Vector3.ZERO]
