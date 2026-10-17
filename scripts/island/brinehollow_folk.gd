extends Villager
## A Brinehollow townsperson on a routine (BrinehollowLife): a Villager whose stays may be seated ("sit", at the
## stay's "seat_y"), whose walk to a stay with "carry" has a load on the shoulder, and who walks on the town's
## floors (the long stair's treads, the tavern's boards) rather than the ground under them (`town.y_at`).

const RAMP := 2.5

## BrinehollowLife's walk graph: y_at(p, ground) -> the floor's height there
var town: RefCounted
var load_node: Node3D
var rod_node: Node3D


func _process(delta: float) -> void:
	super._process(delta)
	# (only on the frames the routine moved it: far off that's a few times a second)
	if not visible or _k < 0 or _acc > 0.0:
		return
	var w := _where(_k, _d)
	var s: Dictionary = stays[_k]
	var arrived: bool = w[3]
	if not (arrived and s.has("y")):
		position.y = town.y_at(Vector2(position.x, position.z), position.y)
		# (up or down to a stay's own floor over the last or first RAMP m: a shrine's steps, a teahouse's boards)
		var cum: PackedFloat32Array = cums[_k]
		var prev: Dictionary = stays[_k - 1]
		if s.has("y") and cum[cum.size() - 1] - _d < RAMP:
			position.y = lerpf(float(s.get("walk_y", s["y"])), position.y, (cum[cum.size() - 1] - _d) / RAMP)
		elif prev.has("y") and _d < RAMP:
			position.y = lerpf(float(prev.get("walk_y", prev["y"])), position.y, _d / RAMP)
	var sit: bool = arrived and s["act"] == "sit"
	if humanoid.seated != sit:
		humanoid.seated = sit
		humanoid.seat_y = float(s.get("seat_y", 0.47))
	if load_node:
		load_node.visible = bool(s.get("carry", false)) and not arrived
	if rod_node:
		rod_node.visible = arrived and s.has("rod")
