class_name Stealth
extends RefCounted
## How close an enemy lets a sneaking captain (CrouchState, "Crouch") get before it
## notices them: its notice ranges shrink to CROUCH_K, and from behind (outside
## its view cone) to BEHIND_K, close enough for a backstab. Works for a guest's
## puppet on the host (the state name rides the snapshot).

const CROUCH_K := 0.5
const BEHIND_K := 0.3
## The view cone: in front when the captain's direction dotted with its facing is above this.
const AHEAD_DOT := -0.2


static func sneaking(p: Node) -> bool:
	return p != null and p.has_method("current_state_name") and str(p.call("current_state_name")) == "Crouch"


## `r` (an enemy's notice range) for captain `p`, seen from `from` facing `fwd`
## (flat; ZERO = it sees all round).
static func range_for(p: Node3D, from: Vector3, fwd: Vector3, r: float) -> float:
	# (1.28) inside a smoke pellet's cloud, or (1.30) behind one: not seen at all
	if not GadgetVeil.clouds.is_empty() and (GadgetVeil.veiled(p) or GadgetVeil.blocks(from, p.global_position)):
		return 0.0
	if not sneaking(p):
		return r
	return r * (BEHIND_K if behind(p, from, fwd) else CROUCH_K)


## (1.30) Can a foe at `from` see captain `p` at all: not in or behind a smoke cloud.
static func sight_clear(from: Vector3, p: Node3D) -> bool:
	return GadgetVeil.clouds.is_empty() or not (GadgetVeil.veiled(p) or GadgetVeil.blocks(from, p.global_position))


## (1.30) A foe dazed by a flash pellet or a smoke cloud (PirateGrunt.is_stunned): a silent takedown lands on it
## from any side.
static func stunned(foe: Node) -> bool:
	return foe != null and foe.has_method("is_stunned") and bool(foe.call("is_stunned"))


static func behind(p: Node3D, from: Vector3, fwd: Vector3) -> bool:
	if fwd == Vector3.ZERO:
		return false
	var to := p.global_position - from
	to.y = 0.0
	return to.length() > 0.01 and fwd.dot(to.normalized()) <= AHEAD_DOT
