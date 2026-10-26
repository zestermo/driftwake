class_name Juggle
extends RefCounted
## Juggling (1.23, docs/v1_23_plan.md "Preview answers"): a launcher (HitData.launch > 0) throws a light foe up (grunts,
## elites, a rival's crewmen: every time; a camp captain or a miniboss only when the blow breaks its poise; beast
## bosses never). Anything hit up there stays up, each hit lifting it less (LIFT x DECAY^hits), and after AIR_MAX s
## hits no longer lift it: it drops and goes down (Poise.IMMUNE then). A spike (HitData.launch < 0) drives it down.
## Juggled foes are in the "juggled" group: the air step chases them (JumpState) and an air attack near one is an air
## combo (PlungeState "air_combo").

const GROUP := "juggled"
## Gravity on a juggled body (lighter than a fall: hang time to chase).
const GRAVITY := 15.0
## Past AIR_MAX it falls this much harder (it drops, it doesn't float down).
const DROP_K := 1.8
const LIFT := 4.5
const DECAY := 0.75
const AIR_MAX := 3.0
## A launch's throw along the blow (m/s), and the most a hit in the air shoves it.
const CARRY := 1.2
## The air step reaches for a juggled foe within this far (and this much ahead of the camera).
const CHASE_REACH := 9.0
const CHASE_DOT := 0.35
## An air attack within this far of a juggled foe is an air combo.
const COMBO_REACH := 3.4


## The lift a hit in the air gives after `hits` earlier ones, `up_for` s up there.
static func lift(hits: int, up_for: float) -> float:
	return 0.0 if up_for > AIR_MAX else LIFT * pow(DECAY, hits)


## The nearest juggled foe within `reach` of `from` (ahead along `fwd` when it's given), else null.
static func near(tree: SceneTree, from: Vector3, reach: float, fwd: Vector3 = Vector3.ZERO) -> Node3D:
	var best: Node3D = null
	var bd := reach
	for e in tree.get_nodes_in_group(GROUP):
		var to: Vector3 = (e as Node3D).global_position - from
		var d := to.length()
		if d > bd:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		if fwd != Vector3.ZERO and flat.length() > 1.0 and flat.normalized().dot(fwd) < CHASE_DOT:
			continue
		bd = d
		best = e
	return best


## Where a juggled foe's chest is.
static func chest(e: Node3D) -> Vector3:
	return e.global_position + Vector3(0, 1.1, 0)
