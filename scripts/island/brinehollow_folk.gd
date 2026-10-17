extends Villager
## A Brinehollow townsperson on a routine (BrinehollowLife): a Villager whose stays may be seated ("sit", at the
## stay's "seat_y"), whose walk to a stay with "carry" has a load on the shoulder, and who walks on the town's
## floors (the long stair's treads, the tavern's boards) rather than the ground under them (`town.y_at`).

## BrinehollowLife's walk graph: y_at(p, ground) -> the floor's height there
var town: RefCounted
var load_node: Node3D
var rod_node: Node3D


func _process(delta: float) -> void:
	super._process(delta)
	if not visible or _k < 0:
		return
	var w := _where(_k, _d)
	var s: Dictionary = stays[_k]
	var arrived: bool = w[3]
	if not (arrived and s.has("y")):
		position.y = town.y_at(Vector2(position.x, position.z), position.y)
	var sit: bool = arrived and s["act"] == "sit"
	if humanoid.seated != sit:
		humanoid.seated = sit
		humanoid.seat_y = float(s.get("seat_y", 0.47))
	if load_node:
		load_node.visible = bool(s.get("carry", false)) and not arrived
	if rod_node:
		rod_node.visible = arrived and s.has("rod")
