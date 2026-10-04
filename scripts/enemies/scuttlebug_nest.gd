class_name ScuttlebugNest
extends Node3D
## Keeps a few scuttlebugs around their burrows. A bug that dies crawls back
## out after a while - but never while you're standing there watching.

@export var respawn_time: float = 45.0
## The player must be at least this far from a burrow for it to respawn.
@export var respawn_clearance: float = 24.0

var spots: Array = []  # {pos: Vector3 (local), big: bool, bug: Scuttlebug, timer: float}


func add_spot(local_pos: Vector3, big: bool = false) -> void:
	spots.append({"pos": local_pos, "big": big, "bug": null, "timer": 0.0, "gen": 0})


func _ready() -> void:
	add_to_group("net_spawner")
	_spawn_all.call_deferred()


func _spawn_all() -> void:
	for s in spots:
		_spawn(s)


func _spawn(s: Dictionary) -> void:
	var gp := to_global(s["pos"] as Vector3)
	var bug := Scuttlebug.new()
	bug.name = "B%d_%d" % [spots.find(s), int(s["gen"])]
	bug.setup(bool(s["big"]), gp)
	add_child(bug)
	bug.global_position = gp + Vector3.UP * 0.3
	bug.reset_physics_interpolation()
	s["bug"] = bug
	s["timer"] = 0.0


func _process(delta: float) -> void:
	if Net.is_client():
		return  # the host decides when bugs come back
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
		var watched := false
		for player in Net.all_players():
			if (player as Node3D).global_position.distance_to(gp) < respawn_clearance:
				watched = true
		if watched:
			continue
		s["gen"] = int(s["gen"]) + 1
		_spawn(s)
		Net.spawned(self, net_gen())


func net_gen():
	var g: Array = []
	for s in spots:
		g.append(int(s["gen"]))
	return g


## Co-op client: catch up with the host's burrows.
func net_set_gen(g) -> void:
	var arr: Array = g
	for i in range(mini(arr.size(), spots.size())):
		var s: Dictionary = spots[i]
		if int(arr[i]) == int(s["gen"]):
			continue
		s["gen"] = int(arr[i])
		var old = s["bug"]
		if old != null and is_instance_valid(old) and (old as Scuttlebug).state != Scuttlebug.S.DEAD:
			(old as Node).queue_free()
		_spawn(s)


func alive_count() -> int:
	var n := 0
	for s in spots:
		var bug = s["bug"]
		if bug != null and is_instance_valid(bug) and (bug as Scuttlebug).state != Scuttlebug.S.DEAD:
			n += 1
	return n
