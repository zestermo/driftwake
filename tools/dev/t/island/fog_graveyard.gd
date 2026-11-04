extends SceneTree
## A fog isle's graveyard (fog_places.gd, 1.30): planned near the village, built bigger - a railing round it, the gate,
## the crypt and two mausoleums, rows of graves, solid to walk into - and 4-6 zombies buried under its fresh graves,
## kept by the island's FaunaSpawner. (Its haunt of a drowned man and a ghost: t/island/fog_isle.)
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var gi
var pl: Dictionary


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
			var Chain = load("res://scripts/world/chain.gd")
			var found := {}
			for s in range(1, 41):
				var c = Chain.make(s, Vector2.ZERO, Vector2(0, -1))
				for n in c.nodes:
					if str(n["theme"]) == "fog" and str(n["role"]) == "regular":
						found = (n as Dictionary).duplicate(true)
						break
				if not found.is_empty():
					break
			load("res://scripts/island/island_theme.gd").meshes("fog")
			gi = load("res://scripts/island/gen_island.gd").new()
			gi.prepare(found)
			stage.add_child(gi)
			var graves := (gi.places as Array).filter(func(e): return str(e.get("kind", "")) == "fog_graveyard")
			check("its graveyard is planned (%d), %.0f m across" % [graves.size(), float(graves[0]["r"]) * 2.0 if graves.size() > 0 else 0.0],
				graves.size() == 1 and float(graves[0]["r"]) >= 11.0)
			if graves.is_empty():
				return TK.done(fails)
			pl = graves[0]
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			load("res://scripts/island/fauna_spawner.gd")._plan_on(gi, rng)
			var node := Node3D.new()
			node.name = "Place_fog_graveyard"
			gi.add_child(node)
			node.position = Vector3((pl["at"] as Vector2).x, float(pl["y"]), (pl["at"] as Vector2).y)
			node.rotation.y = float(pl.get("yaw", 0.0))
			load("res://scripts/island/themes/fog_places.gd").graveyard(gi, pl, node)
			until = TK.wait_ticks(4)
		1:
			var node = gi.get_node("Place_fog_graveyard")
			var walls = node.get_node("Walls")
			var mi = node.get_node("Stones")
			var tris := 0
			for s in range(mi.mesh.get_surface_count()):
				tris += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			check("built big: %d colliders, %d triangles in %d surfaces" % [walls.get_child_count(), tris, mi.mesh.get_surface_count()],
				walls.get_child_count() >= 60 and tris > 4000 and mi.mesh.get_surface_count() <= 8)
			check("...seen from afar, not forever (%.0f m)" % mi.visibility_range_end, mi.visibility_range_end > 150.0 and mi.visibility_range_end < 400.0)
			var fauna = gi.get_node("Fauna")
			var zs: Array = fauna.groups_of("zombie")
			var n: int = zs[0]["spots"].size() if zs.size() > 0 else 0
			check("%d zombies are buried under its fresh graves" % n, zs.size() == 1 and n >= 4 and n <= 6)
			var c: Vector3 = gi.to_global(Vector3((pl["at"] as Vector2).x, 0, (pl["at"] as Vector2).y))
			var all_in := true
			var all_buried := true
			for si in zs[0]["spots"]:
				var zn = fauna.spots[si]["node"]
				all_in = all_in and Vector2(zn.global_position.x - c.x, zn.global_position.z - c.z).length() < float(pl["r"])
				all_buried = all_buried and zn.buried()
			check("...inside its railing, all asleep in the ground", all_in and all_buried)
			return TK.done(fails)
	step += 1
	return false
