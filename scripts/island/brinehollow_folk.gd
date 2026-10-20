extends Villager
## A Brinehollow townsperson on a routine (BrinehollowLife): a Villager whose stays may be seated ("sit", at the
## stay's "seat_y"), whose walk to a stay with "carry" has a load on the shoulder, and who walks on the town's
## floors (the long stair's treads, the tavern's boards) rather than the ground under them (`town.y_at`).

const RAMP := 2.5
const STEADY_R := 15.0
const EASY_R := 35.0
## Hidden past this (Villager's SHOW_R is 150): a small figure that far is a draw call for a few pixels.
const SHOW_FAR := 100.0

## BrinehollowLife's walk graph: y_at(p, ground) -> the floor's height there
var town: RefCounted
var load_node: Node3D
var rod_node: Node3D
var _skip := 0.0
var _beat := 0
var _walking := false
@onready var _body: StaticBody3D = get_node("Body")


func _process(delta: float) -> void:
	# (the routine every frame within STEADY_R of the camera, every other one to EASY_R, every fourth past it)
	_skip += delta
	_beat += 1
	var cam := humanoid._camera()
	var d2 := cam.global_position.distance_squared_to(global_position) if cam else 0.0
	var every := 1 if d2 < STEADY_R * STEADY_R else (2 if d2 < EASY_R * EASY_R else 4)
	if (_beat + get_instance_id()) % every != 0:
		return
	var dt := _skip
	_skip = 0.0
	super._process(dt)
	if visible and d2 > SHOW_FAR * SHOW_FAR:
		visible = false
	# (only on the frames the routine moved it: far off that's a few times a second)
	if not visible or _k < 0 or _acc > 0.0:
		return
	var w := _where(_k, _d)
	var s: Dictionary = stays[_k]
	var arrived: bool = w[3]
	# out of the physics while walking (a body dragged round every frame costs Jolt); solid when stopped
	var walking: bool = w[2] == "walk"
	if walking != _walking:
		_walking = walking
		_body.process_mode = Node.PROCESS_MODE_DISABLED if walking else Node.PROCESS_MODE_INHERIT
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
