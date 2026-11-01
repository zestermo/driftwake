class_name RapierMoves
## The rapier (stance "rapier": one hand on the sword, the free hand up behind for balance). A fencer's guard, side on
## with the right foot and the point at the foe, and moves built from footwork: every blow is the arm extending first
## and the feet carrying it (an advance, a lunge, a fleche), the chest staying upright, the blade always on the line.
## Every "rp_*" move is keyed here (reached from Humanoid._action_pose). Poses are written with directions instead of
## arm angles: "arm" (where the sword arm points), "fore" (the elbow's bend) and "blade" (where the point goes), all in
## the root's frame (x right, y up, z back), turned into the chest's frame and solved into shoulder and wrist angles
## (`_aim`): the point stays on the line whatever the chest does. "off" / "fore_l" do the same for the free arm.

## The fencer's guard: side on (the hips turned right-hip forward: StanceLife.HIPS, HIPS here), the chest upright, the
## sword arm out in front with the elbow a little bent, the point at the foe's eyes; the free arm raised behind, the hand
## up by the head. (Solved over the turned hips, which StanceLife adds standing and takes out walking.)
const HIPS := Vector3(0, 0.75, 0)
static var GUARD := _guard_pose()
const LEGS := {"leg_l": Vector3(-0.32, 0, -0.18), "leg_r": Vector3(0.5, 0, 0.14), "shin_l": Vector3(-0.62, 0, 0), "shin_r": Vector3(-0.72, 0, 0),
	"_lift": Vector3(0, -0.15, 0)}


static func _guard_pose() -> Dictionary:
	var g := _aim({"hips": HIPS, "torso": Vector3(0.02, 0.22, 0.0), "head": Vector3(0.0, -0.92, 0),
		"arm": Vector3(0.1, -0.55, -0.85), "fore": 0.55, "blade": Vector3(0.02, 0.12, -1.0),
		"off": Vector3(-0.1, 0.1, 1.0), "fore_l": 1.6})
	g.erase("hips")
	return g
## The held block: the blade stood up across the front, the point high, the hand out at the right.
static var BLOCK := _aim({"torso": Vector3(-0.05, 0.25, 0.0), "head": Vector3(0.05, -0.3, 0),
	"arm": Vector3(0.45, -0.35, -0.85), "fore": 0.9, "blade": Vector3(-0.35, 0.92, -0.2),
	"off": Vector3(-0.2, 0.2, 1.0), "fore_l": 1.5})

## The feet: the guard's spread, an advance (the front foot a step on), a lunge (the back leg straight, the front knee
## deep) and a recover.
const ADVANCE := {"leg_l": Vector3(-0.25, 0, -0.18), "shin_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(0.85, 0, 0.14), "shin_r": Vector3(-0.85, 0, 0)}
const LUNGE := {"leg_l": Vector3(-0.85, 0, -0.2), "shin_l": Vector3(-0.08, 0, 0), "leg_r": Vector3(1.3, 0, 0.14), "shin_r": Vector3(-1.25, 0, 0)}
const SINK := {"leg_l": Vector3(-0.2, 0, -0.2), "shin_l": Vector3(-0.95, 0, 0), "leg_r": Vector3(0.45, 0, 0.14), "shin_r": Vector3(-0.95, 0, 0)}

## The phantom double thrust (the combo's third): the first (the mirror's) at PHANTOM_AT[0] of the move, the real one
## at [1] (u).
const PHANTOM_AT := [0.3, 0.6]
## The riposte's thrust out of a landed parry (u of rp_deflect).
const RIPOSTE_AT := 0.32


static func guard(_h) -> Dictionary:
	return GUARD


## A pose written with directions turned into joint angles: "arm" / "fore" / "blade" for the sword arm, "off" /
## "fore_l" for the free arm (root frame), solved in the chest's frame (pivot, hips, torso).
static func _aim(p: Dictionary) -> Dictionary:
	var out := p.duplicate()
	var chest := (Basis.from_euler(p.get("pivot", Vector3.ZERO)) * Basis.from_euler(p.get("hips", Vector3.ZERO))
		* Basis.from_euler(p.get("torso", Vector3.ZERO))).inverse()
	if p.has("arm"):
		var arm := _arm_to(chest * (p["arm"] as Vector3))
		var fore := float(p["fore"])
		out["arm_r"] = arm
		out["fore_r"] = Vector3(fore, 0, 0)
		out["hand_r"] = _wrist(arm, fore, chest * (p["blade"] as Vector3))
	if p.has("off"):
		# (the free arm points back: its swing kept on one side of the turn, or keys either side of straight back blend
		# the long way round)
		var off := _arm_to(chest * (p["off"] as Vector3))
		out["arm_l"] = Vector3(off.x, wrapf(off.y, -PI * 0.5, PI * 1.5), 0.0)
		out["fore_l"] = Vector3(float(p["fore_l"]), 0, 0)
		out["hand_l"] = Vector3.ZERO
	for k in ["arm", "fore", "blade", "off"]:
		out.erase(k)
	return out


## The shoulder angles (x pitched up from hanging, y swung round) that point an arm along `d` (the chest's frame).
static func _arm_to(d: Vector3) -> Vector3:
	var n := d.normalized()
	return Vector3(acos(clampf(-n.y, -1.0, 1.0)), atan2(-n.x, -n.z), 0.0)


## The wrist that points the blade along `dir` (the chest's frame), as DaggerMoves.wrist_to, but steady where the blade
## runs along the forearm (a thrust): there the turn about the forearm only rolls the blade and its angle is undefined,
## so it eases to none instead of flipping between keys. A blade pointing back off a bent forearm is written the other
## way round (the turn under a quarter, the wrist past straight down: the same direction, rolled), so every key blends
## through the forearm's line rather than round the side.
static func _wrist(arm: Vector3, fore: float, dir: Vector3) -> Vector3:
	var d := (Basis.from_euler(arm) * Basis(Vector3.RIGHT, fore)).inverse() * dir.normalized()
	var flat := Vector2(d.x, d.z).length()
	var x := asin(clampf(d.y, -1.0, 1.0))
	var y := atan2(-d.x, -d.z)
	if absf(y) > PI * 0.5:
		y -= signf(y) * PI
		x = -PI - x
	return Vector3(x, y * clampf(flat / 0.15, 0.0, 1.0), 0.0)


static func _p(parts: Array) -> Dictionary:
	var out := {}
	for d in parts:
		out.merge(d, true)
	return _aim(out)


## The strike: the pose at full extension stretched along the thrust, the blade smeared.
static func _whip(p: Dictionary, sc: Vector3, smear: float = 0.8) -> Dictionary:
	return p.merged({"_scale": sc, "_smear": Vector3(smear, 0, 0)}, true)


## [pose, mask, lift] for a rapier move.
static func pose(h, n: String, u: float) -> Array:
	var g: Dictionary = h._guard().merged({"hips": HIPS}).merged(LEGS)
	var lift := Vector3.ZERO
	match n:
		"rp_1":
			# the straight thrust: the hand drawn in a hair and the wrist set, then the arm shot out ahead of the feet and
			# an advance carrying it in
			var set := _p([{"hips": Vector3(0, 0.8, 0), "torso": Vector3(0.04, 0.2, 0), "head": Vector3(0.0, -0.95, 0),
				"arm": Vector3(0.15, -0.45, -0.8), "fore": 0.95, "blade": Vector3(0.0, 0.18, -1.0),
				"off": Vector3(-0.1, 0.15, 1.0), "fore_l": 1.7, "_lift": Vector3(0, -0.17, 0), "_scale": Vector3(1.02, 0.97, 0.98)}, LEGS])
			var hit := _p([{"pivot": Vector3(-0.08, 0, 0), "hips": Vector3(0, 0.85, 0), "torso": Vector3(-0.06, 0.25, 0), "head": Vector3(0.1, -1.0, 0),
				"arm": Vector3(0.05, 0.02, -1.0), "fore": 0.08, "blade": Vector3(0.0, 0.03, -1.0),
				"off": Vector3(-0.15, -0.1, 1.0), "fore_l": 0.9, "_lift": Vector3(0, -0.2, 0)}, ADVANCE])
			return [h._keys(u, [[0.0, g], [0.2, set, "out"], [0.3, _whip(hit, Vector3(0.97, 1.0, 1.08)), "out"], [0.42, hit],
				[0.62, hit], [1.0, g]]), "full", lift]
		"rp_2":
			# the disengage: the point dipped under their blade and round, then the thrust into the high line from the
			# other side, the chest turned further and the arm higher
			var dip := _p([{"hips": Vector3(0, 0.7, 0), "torso": Vector3(0.02, 0.1, 0), "head": Vector3(0.0, -0.8, 0),
				"arm": Vector3(-0.15, -0.55, -0.85), "fore": 0.85, "blade": Vector3(-0.35, -0.35, -0.85),
				"off": Vector3(-0.15, 0.2, 1.0), "fore_l": 1.6, "_lift": Vector3(0, -0.16, 0), "_scale": Vector3(1.03, 0.96, 1.0)}, LEGS])
			var hit := _p([{"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, 0.95, 0), "torso": Vector3(-0.05, 0.35, 0), "head": Vector3(0.12, -1.2, 0),
				"arm": Vector3(0.12, 0.22, -1.0), "fore": 0.1, "blade": Vector3(0.02, 0.16, -1.0),
				"off": Vector3(-0.2, -0.15, 1.0), "fore_l": 0.8, "_lift": Vector3(0, -0.22, 0)}, ADVANCE])
			return [h._keys(u, [[0.0, g], [0.22, dip, "out"], [0.32, _whip(hit, Vector3(0.97, 1.02, 1.08)), "in"], [0.44, hit],
				[0.62, hit], [1.0, g]]), "full", lift]
		"rp_3":
			# the phantom double: a first thrust out (the mirror's: a silver ghost of it carries on), a snap back, and the
			# real one a beat later from lower and further, the back foot driving it
			var set := _p([{"hips": Vector3(0, 0.8, 0), "torso": Vector3(0.04, 0.2, 0), "head": Vector3(0.0, -0.95, 0),
				"arm": Vector3(0.12, -0.5, -0.85), "fore": 1.0, "blade": Vector3(0.0, 0.2, -1.0),
				"off": Vector3(-0.1, 0.15, 1.0), "fore_l": 1.7, "_lift": Vector3(0, -0.17, 0), "_scale": Vector3(1.02, 0.97, 0.98)}, LEGS])
			var one := _p([{"pivot": Vector3(-0.06, 0, 0), "hips": Vector3(0, 0.82, 0), "torso": Vector3(-0.04, 0.24, 0), "head": Vector3(0.08, -1.0, 0),
				"arm": Vector3(0.05, 0.08, -1.0), "fore": 0.12, "blade": Vector3(0.0, 0.1, -1.0),
				"off": Vector3(-0.15, 0.0, 1.0), "fore_l": 1.1, "_lift": Vector3(0, -0.19, 0)}, ADVANCE])
			var back := _p([{"hips": Vector3(0, 0.78, 0), "torso": Vector3(0.0, 0.2, 0), "head": Vector3(0.04, -0.95, 0),
				"arm": Vector3(0.12, -0.35, -0.9), "fore": 0.85, "blade": Vector3(0.0, 0.05, -1.0),
				"off": Vector3(-0.1, 0.15, 1.0), "fore_l": 1.5, "_lift": Vector3(0, -0.22, 0), "_scale": Vector3(1.03, 0.95, 1.0)}, SINK])
			var two := _p([{"pivot": Vector3(-0.18, 0, 0), "hips": Vector3(0, 0.9, 0), "torso": Vector3(-0.08, 0.3, 0), "head": Vector3(0.2, -1.1, 0),
				"arm": Vector3(0.04, 0.0, -1.0), "fore": 0.05, "blade": Vector3(0.0, -0.02, -1.0),
				"off": Vector3(-0.1, -0.35, 1.0), "fore_l": 0.4, "_lift": Vector3(0, -0.34, 0)}, LUNGE])
			var a := float(PHANTOM_AT[0])
			var b := float(PHANTOM_AT[1])
			return [h._keys(u, [[0.0, g], [a - 0.12, set, "out"], [a, _whip(one, Vector3(0.97, 1.0, 1.08)), "out"], [a + 0.06, one],
				[b - 0.1, back, "out"], [b, _whip(two, Vector3(0.96, 0.98, 1.12), 1.0), "out"], [b + 0.08, two], [b + 0.24, two], [1.0, g]]), "full", lift]
		"rp_heavy":
			# the lunge: sunk back over the rear foot with the point held on them, a breath, then everything at once: the
			# arm straight, the back leg kicked long, the front foot thrown a stride on, the body low behind the point
			var coil := _p([{"pivot": Vector3(0.06, 0, 0), "hips": Vector3(0, 0.82, 0), "torso": Vector3(0.08, 0.2, 0), "head": Vector3(-0.04, -0.95, 0),
				"arm": Vector3(0.1, -0.5, -0.85), "fore": 1.1, "blade": Vector3(0.0, 0.1, -1.0),
				"off": Vector3(-0.05, 0.4, 1.0), "fore_l": 1.9, "_lift": Vector3(0, -0.26, 0), "_scale": Vector3(1.04, 0.93, 0.97)}, SINK])
			var held := coil.merged({"_scale": Vector3(1.05, 0.92, 0.96)}, true)
			var lunge := _p([{"pivot": Vector3(-0.22, 0, 0), "hips": Vector3(0, 0.95, 0), "torso": Vector3(-0.1, 0.3, 0), "head": Vector3(0.25, -1.15, 0),
				"arm": Vector3(0.04, 0.0, -1.0), "fore": 0.04, "blade": Vector3(0.0, -0.03, -1.0),
				"off": Vector3(-0.05, -0.45, 1.0), "fore_l": 0.25, "_lift": Vector3(0, -0.42, 0)}, LUNGE])
			var recover := _p([{"hips": Vector3(0, 0.8, 0), "torso": Vector3(0.02, 0.22, 0), "head": Vector3(0.02, -0.95, 0),
				"arm": Vector3(0.1, -0.45, -0.85), "fore": 0.6, "blade": Vector3(0.02, 0.1, -1.0),
				"off": Vector3(-0.1, 0.1, 1.0), "fore_l": 1.6, "_lift": Vector3(0, -0.18, 0)}, LEGS])
			return [h._keys(u, [[0.0, g], [0.26, coil, "out"], [0.38, held], [0.46, _whip(lunge, Vector3(0.94, 0.98, 1.16), 1.2), "out"],
				[0.56, lunge], [0.74, lunge], [0.9, recover], [1.0, g]]), "full", lift]
		"rp_dash":
			# the fleche: out of the run, the arm thrown out first, then a running leap behind it, the point arriving
			# before the feet, the back leg crossing past the front
			var gather := _p([{"pivot": Vector3(-0.15, 0, 0), "hips": Vector3(0, 0.6, 0), "torso": Vector3(-0.1, 0.25, 0), "head": Vector3(0.15, -0.85, 0),
				"arm": Vector3(0.1, -0.2, -1.0), "fore": 0.6, "blade": Vector3(0.0, 0.08, -1.0),
				"off": Vector3(-0.2, 0.1, 1.0), "fore_l": 1.4, "_lift": Vector3(0, -0.2, 0), "_scale": Vector3(1.03, 0.95, 1.0)},
				ADVANCE])
			var fly := _p([{"pivot": Vector3(-0.38, 0, 0), "hips": Vector3(0, 0.7, 0), "torso": Vector3(-0.08, 0.3, 0), "head": Vector3(0.35, -1.0, 0),
				"arm": Vector3(0.04, 0.0, -1.0), "fore": 0.04, "blade": Vector3(0.0, -0.05, -1.0),
				"off": Vector3(-0.1, -0.4, 1.0), "fore_l": 0.3,
				"leg_l": Vector3(0.9, 0, -0.14), "shin_l": Vector3(-1.2, 0, 0), "leg_r": Vector3(-0.6, 0, 0.14), "shin_r": Vector3(-0.4, 0, 0),
				"_lift": Vector3(0, -0.05, 0)}])
			var land := _p([{"pivot": Vector3(-0.1, 0, 0), "hips": Vector3(0, 0.8, 0), "torso": Vector3(-0.02, 0.25, 0), "head": Vector3(0.1, -0.95, 0),
				"arm": Vector3(0.08, -0.15, -1.0), "fore": 0.3, "blade": Vector3(0.0, 0.05, -1.0),
				"off": Vector3(-0.1, 0.0, 1.0), "fore_l": 1.2, "_lift": Vector3(0, -0.24, 0), "_scale": Vector3(1.04, 0.94, 1.02)}, ADVANCE])
			return [h._keys(u, [[0.0, gather], [0.2, gather], [0.34, _whip(fly, Vector3(0.95, 1.0, 1.14), 1.0), "out"], [0.56, fly],
				[0.72, land, "in"], [0.84, land], [1.0, g]]), "full", lift]
		"rp_parry":
			# a turn of the wrist: the blade swung across to the outside, point up, their blade carried off the line;
			# the weight eased back onto the rear foot
			var turn := _p([{"pivot": Vector3(0.05, 0, 0), "hips": Vector3(0, 0.72, 0), "torso": Vector3(0.06, 0.18, 0), "head": Vector3(-0.02, -0.9, 0),
				"arm": Vector3(0.35, -0.35, -0.85), "fore": 0.85, "blade": Vector3(0.45, 0.85, -0.25),
				"off": Vector3(-0.1, 0.25, 1.0), "fore_l": 1.7, "_lift": Vector3(0, -0.2, 0), "_scale": Vector3(1.02, 0.97, 0.98)}, SINK])
			var held := turn.merged({"_scale": Vector3.ONE}, true)
			return [h._keys(u, [[0.0, g], [0.12, turn, "out"], [0.2, held], [0.6, held], [1.0, g]]), "full", lift]
		"rp_deflect":
			# the riposte: off the parry, the blade comes straight down the line they left open, an advance behind it,
			# and back to the guard
			var turn := _p([{"pivot": Vector3(0.05, 0, 0), "hips": Vector3(0, 0.72, 0), "torso": Vector3(0.06, 0.18, 0), "head": Vector3(-0.02, -0.9, 0),
				"arm": Vector3(0.35, -0.35, -0.85), "fore": 0.85, "blade": Vector3(0.45, 0.85, -0.25),
				"off": Vector3(-0.1, 0.25, 1.0), "fore_l": 1.7, "_lift": Vector3(0, -0.2, 0)}, SINK])
			var hit := _p([{"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, 0.88, 0), "torso": Vector3(-0.06, 0.28, 0), "head": Vector3(0.14, -1.05, 0),
				"arm": Vector3(0.05, 0.05, -1.0), "fore": 0.06, "blade": Vector3(0.0, 0.04, -1.0),
				"off": Vector3(-0.15, -0.2, 1.0), "fore_l": 0.7, "_lift": Vector3(0, -0.26, 0)}, ADVANCE])
			return [h._keys(u, [[0.0, turn], [RIPOSTE_AT - 0.1, turn], [RIPOSTE_AT, _whip(hit, Vector3(0.96, 1.0, 1.1), 1.0), "out"],
				[RIPOSTE_AT + 0.1, hit], [0.66, hit], [1.0, g]]), "full", lift]
		"rp_stance":
			return [g, "full", lift]
	push_error("RapierMoves: no pose for \"%s\"" % n)
	return [g, "full", lift]
