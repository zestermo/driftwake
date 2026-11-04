extends SceneTree
## 1.30 the lighthouse hill on the real Brinehollow: the road up from the town path climbs the hill by its switchbacks
## at no more than a 1-in-2 grade anywhere on its line; F at the tower's door puts a captain on the gallery, standing on
## its deck with Ambrose at his telescope there; a step outward meets the rail, not the drop; F at the watch room's door
## brings them down by the steps; the keeper's cottage has a floor you stand on.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var isl
var lh
var gy := 0.0
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
			lh = isl.lighthouse
			var steep := 0.0
			var at := Vector2.ZERO
			var keys: Array = isl.HILL_ROAD
			for i in range(keys.size() - 1):
				var a := Vector2(keys[i].x, keys[i].z)
				var b := Vector2(keys[i + 1].x, keys[i + 1].z)
				var n := int(a.distance_to(b))
				for k in range(n):
					var q0 := a.lerp(b, float(k) / n)
					var q1 := a.lerp(b, float(k + 1) / n)
					var g: float = absf(isl.hv(q1) - isl.hv(q0)) / q0.distance_to(q1)
					if g > steep:
						steep = g
						at = q0
			check("the hill road's steepest metre is a 1-in-%.1f grade (at %s)" % [1.0 / maxf(steep, 0.001), str(at)], steep < 0.5)
			var top: float = isl.to_local(lh.global_position).y
			var foot: float = isl.hv(Vector2(keys[0].x, keys[0].z))
			check("...and it climbs %.1f m to the tower" % (top - foot), top - foot > 9.0)
			var door: Vector3 = lh.to_global((lh.get_node("Door") as Node3D).position)
			p.global_position = door + Vector3.UP * 0.3 + (lh.global_position - door).normalized() * 2.4
			p.reset_physics_interpolation()
			gy = lh.to_global(Vector3(0, load("res://scripts/island/brinehollow_lighthouse.gd").gallery_y(), 0)).y
			until = TK.wait_ticks(30)
		1:
			TK.act("interact")
			until = TK.wait_ticks(40)
		2:
			check("F at the door: up on the gallery (%.2f over its deck)" % (p.global_position.y - gy), p.is_on_floor() and absf(p.global_position.y - gy) < 0.3)
			var amb = null
			for n in root.get_tree().get_nodes_in_group("npcs"):
				if n.npc_name == "Keeper Ambrose":
					amb = n
			check("Ambrose keeps watch up there", amb != null and absf(amb.global_position.y - gy) < 0.3 and Vector2(amb.global_position.x - lh.global_position.x, amb.global_position.z - lh.global_position.z).length() < 2.9)
			var out: Vector3 = (p.global_position - lh.global_position)
			out.y = 0.0
			var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * 0.6, p.global_position + Vector3.UP * 0.6 + out.normalized() * 3.0, 1)
			check("a step outward meets the rail", not lh.get_world_3d().direct_space_state.intersect_ray(q).is_empty())
			TK.act("interact")
			until = TK.wait_ticks(60)
		3:
			var ground: float = isl.to_global(Vector3(0, isl.hv(Vector2(isl.to_local(p.global_position).x, isl.to_local(p.global_position).z)), 0)).y
			check("F at the watch room's door: back down on the ground (%.2f over it)" % (p.global_position.y - ground), p.is_on_floor() and absf(p.global_position.y - ground) < 0.4)
			var hut: Node3D = isl._keeper_hut
			p.global_position = hut.to_global((hut.get_node("Inside") as Node3D).position + Vector3(0, 0.9, 0.3))
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			until = TK.wait_ticks(45)
		4:
			var hut: Node3D = isl._keeper_hut
			var fy: float = hut.to_global((hut.get_node("Inside") as Node3D).position).y
			check("the keeper's cottage: standing on its floor (%.2f over it)" % (p.global_position.y - fy), p.is_on_floor() and absf(p.global_position.y - fy) < 0.25)
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
