extends SceneTree
## 1.30 the chapel close's walk-in houses on the real Brinehollow: each one's doorway is open (rays from its door
## marker into the room at knee, chest and head height meet nothing until the back wall), a captain dropped inside
## stands on its floor (not through it, not on the roof), its keeper is inside with their tips (a dialogue), and the
## tinker's has a working gadget bench. The chapel faces the close.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var isl
var kinds: Array = []
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			load("res://scripts/world/actor_sleep.gd").enabled = false
			p = stage.player
			isl = load("res://scripts/island/starter_island.gd").new()
			isl.name = "Brinehollow"
			isl.position = Vector3(0, 0, 9000)
			stage.add_child(isl)
			isl.build(42)
			kinds = isl.close_rooms.keys()
			check("three walk-in houses on the close (%s)" % str(kinds), kinds.size() == 3)
			var space: PhysicsDirectSpaceState3D = isl.get_world_3d().direct_space_state
			for k in kinds:
				var r: Node3D = isl.close_rooms[k]
				var door: Vector3 = (r.get_node("Door") as Node3D).position
				var open := true
				for y: float in [0.7, 1.3, 1.9]:
					var q := PhysicsRayQueryParameters3D.create(r.to_global(Vector3(door.x, y, door.z)), r.to_global(Vector3(door.x, y, 0.0)), 1)
					open = open and space.intersect_ray(q).is_empty()
				check("%s: the doorway's open into the room" % k, open)
				var inside: Vector3 = r.to_global((r.get_node("Inside") as Node3D).position)
				var keeper: Vector3 = r.to_global((r.get_node("Keeper") as Node3D).position)
				var who = null
				for n in root.get_tree().get_nodes_in_group("npcs"):
					if n.global_position.distance_to(keeper) < 0.6:
						who = n
				check("%s: its keeper stands inside with something to say" % k, who != null and str(who.dialogue_id) != "" and FileAccess.file_exists("res://data/dialogue/%s.json" % who.dialogue_id))
				check("%s: the keeper's spot is on the floor (%.2f over it)" % [k, keeper.y - inside.y], absf(keeper.y - inside.y) < 0.05)
			var bench = isl.close_rooms["tinker"].find_children("*", "Workbench", true, false)
			check("the tinker's shop has a gadget bench", bench.size() == 1 and bench[0].is_in_group("workbenches"))
			var chapel: Node3D = isl.get_node("Chapel")
			var cface := Vector2(chapel.global_transform.basis.z.x, chapel.global_transform.basis.z.z)
			check("the chapel faces the close", cface.dot(Vector2(0, -1)) > 0.95)
			_drop(kinds[0])
		1, 3, 5:
			var r: Node3D = isl.close_rooms[kinds[(step - 1) / 2]]
			var floor_y: float = r.to_global((r.get_node("Inside") as Node3D).position).y
			check("%s: a captain dropped inside stands on its floor (%.2f over it)" % [kinds[(step - 1) / 2], p.global_position.y - floor_y], p.is_on_floor() and absf(p.global_position.y - floor_y) < 0.25)
			if step < 5:
				_drop(kinds[(step + 1) / 2])
			else:
				isl.queue_free()
				return TK.done(fails)
		2, 4:
			pass
	step += 1
	return false


func _drop(k: String) -> void:
	var r: Node3D = isl.close_rooms[k]
	p.global_position = r.to_global((r.get_node("Inside") as Node3D).position + Vector3(0, 0.9, 0.3))
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	until = TK.wait_ticks(45)
