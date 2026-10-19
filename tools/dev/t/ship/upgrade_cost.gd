extends SceneTree
## What a fully upgraded sloop costs to draw (she's in every frame at sea): the parts are a few folded
## meshes (draw surfaces capped), no new lights, no per-frame work while nobody steers (prints the counts).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## [mesh instances, draw surfaces, vertices, lights, collision shapes] on her.
func counts(ship) -> Array:
	var mis := 0
	var surf := 0
	var verts := 0
	for mi in ship.ship_model.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null or not (mi as MeshInstance3D).is_visible_in_tree() or m.get_surface_count() == 0:
			continue
		mis += 1
		surf += m.get_surface_count()
		for s in range(m.get_surface_count()):
			verts += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var lights: int = ship.find_children("*", "Light3D", true, false).size()
	var shapes: int = ship.find_children("*", "CollisionShape3D", false, false).size()
	return [mis, surf, verts, lights, shapes]


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var ship = stage.ship
			var lines = load("res://scripts/ship/ship_lines.gd")
			ship.sail_shown = 1.0
			ship._show_sail(0.0)
			var plain := counts(ship)
			var full := {}
			for id in lines.ORDER:
				full[id] = lines.max_level(id)
			ship.apply_kit(full)
			ship._show_sail(0.0)
			var maxed := counts(ship)
			print("   plain: %d meshes, %d surfaces, %d verts, %d lights, %d shapes" % plain)
			print("   maxed: %d meshes, %d surfaces, %d verts, %d lights, %d shapes" % maxed)
			print("   parts: UpgradeMesh %d surfaces, UpgradeFine %d" % [ship.parts._mesh.mesh.get_surface_count(), ship.parts._fine.mesh.get_surface_count()])
			# (the extra guns, the chaser and their fittings are most of the meshes; the parts are two folded meshes)
			# (52 plus the yard ropes' 3: they used to hang on the plain sloop too)
			check("a maxed sloop adds at most 55 draw surfaces (%d)" % (maxed[1] - plain[1]), maxed[1] - plain[1] <= 55)
			check("...and no lights", maxed[3] == plain[3])
			check("...the parts fold to one surface per texture (%d)" % ship.parts._mesh.mesh.get_surface_count(), ship.parts._mesh.mesh.get_surface_count() <= 16)
			ship.apply_kit({})
			check("a plain sloop draws no upgrade parts", ship.parts._mesh.mesh.get_surface_count() == 0 and ship.parts._fine.mesh.get_surface_count() == 0)
			return TK.done(fails)
	step += 1
	return false
