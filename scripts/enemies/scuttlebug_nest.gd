class_name ScuttlebugNest
extends Node3D
## Keeps a few scuttlebugs around their burrows. A bug that dies crawls back
## out after a while - but never while you're standing there watching.

@export var respawn_time: float = 45.0
## The player must be at least this far from a burrow for it to respawn.
@export var respawn_clearance: float = 24.0

var spots: Array = []  # {pos: Vector3 (local), big: bool, bug: Scuttlebug, timer: float}


func add_spot(local_pos: Vector3, big: bool = false) -> void:
	spots.append({"pos": local_pos, "big": big, "bug": null, "timer": 0.0})


func _ready() -> void:
	_spawn_all.call_deferred()


func _spawn_all() -> void:
	for s in spots:
		_spawn(s)


func _spawn(s: Dictionary) -> void:
	var gp := to_global(s["pos"] as Vector3)
	var bug := Scuttlebug.new()
	bug.name = "Scuttlebug"
	bug.setup(bool(s["big"]), gp)
	add_child(bug)
	bug.global_position = gp + Vector3.UP * 0.3
	bug.reset_physics_interpolation()
	s["bug"] = bug
	s["timer"] = 0.0


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	for s in spots:
		var bug = s["bug"]
		var alive: bool = bug != null and is_instance_valid(bug) and (bug as Scuttlebug).state != Scuttlebug.S.DEAD
		if alive:
			continue
		s["timer"] = float(s["timer"]) + delta
		if float(s["timer"]) < respawn_time:
			continue
		if bug != null and is_instance_valid(bug):
			continue  # still sinking away
		var gp := to_global(s["pos"] as Vector3)
		if player and player.global_position.distance_to(gp) < respawn_clearance:
			continue
		_spawn(s)


func alive_count() -> int:
	var n := 0
	for s in spots:
		var bug = s["bug"]
		if bug != null and is_instance_valid(bug) and (bug as Scuttlebug).state != Scuttlebug.S.DEAD:
			n += 1
	return n
