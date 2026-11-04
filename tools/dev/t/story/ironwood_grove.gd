extends SceneTree
## 1.30 Tackett's grove on the real Brinehollow: the marked ironwoods stand in a clearing off the forest path (not on
## any path, well clear of the cave's mouth, no forest trunk inside the clearing, a trail in from the path), and F next
## to one on the forest step fells it: a length of timber, the trunk goes over (its standing shape off, the log's on)
## and the stump stays. Off the step the blaze says it's Tackett's.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var isl
var story
var dlg
var tree0
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
			story = root.get_node("Story")
			dlg = root.get_node("Dialogue")
			isl = load("res://scripts/island/starter_island.gd").new()
			isl.name = "Brinehollow"
			isl.position = Vector3(0, 0, 9000)
			stage.add_child(isl)
			isl.build(42)
			var trees: Array = isl.grove.trees
			check("three marked ironwoods", trees.size() == 3)
			var off_paths := true
			var in_grove := true
			var clear_of_cave := true
			for t in trees:
				var l: Vector3 = isl.to_local(t.global_position)
				var q := Vector2(l.x, l.z)
				off_paths = off_paths and isl._path_dist(q, isl.paths.size(), 0, true) > 3.0
				in_grove = in_grove and q.distance_to(isl.GROVE) < isl.GROVE_R
				clear_of_cave = clear_of_cave and q.distance_to(isl.CAVE) > 40.0
			check("...none on a path", off_paths)
			check("...all in the clearing", in_grove)
			check("...well clear of the cave's mouth", clear_of_cave)
			var trail_end: Vector2 = isl.paths[isl._grove_trail][isl.paths[isl._grove_trail].size() - 1]
			check("a trail runs from the forest path into the grove (%.1f m short)" % (trail_end.distance_to(isl.GROVE) - isl.GROVE_R), trail_end.distance_to(isl.GROVE) < isl.GROVE_R)
			var trunks := 0
			for cs in isl.get_node("VegetationColliders").get_children():
				var c: Vector3 = cs.position
				if Vector2(c.x, c.z).distance_to(isl.GROVE) < isl.GROVE_R - 1.0:
					trunks += 1
			check("no forest trunks inside the clearing (%d)" % trunks, trunks == 0)
			story.begin()
			story.step = "forest"
			tree0 = trees[0]
			var dir: Vector3 = (isl.to_global(Vector3(isl.GROVE.x, tree0.global_position.y - isl.global_position.y, isl.GROVE.y)) - tree0.global_position)
			dir.y = 0.0
			p.global_position = tree0.global_position + dir.normalized() * 1.7 + Vector3.UP * 0.6
			p.reset_physics_interpolation()
			until = TK.wait_ticks(30)
		1:
			TK.act("interact")
			until = TK.wait_secs(3.6)
		2:
			check("F at a marked tree fells it: a length of timber (%d)" % p.inventory_component.count("timber"), p.inventory_component.count("timber") == 1)
			var hinge: Node3D = tree0.get_node("Hinge")
			check("...the trunk went over (%.2f rad)" % hinge.rotation.z, hinge.rotation.z < -1.3)
			check("...its log shape on, the standing one off", not tree0.get_node("Log").disabled and tree0.get_node("Trunk").disabled)
			check("...the stump's still there", tree0.get_node("Stump").visible)
			story.step = "queen"
			isl.grove.fell(p, 1)
			check("off the step a marked tree stays up", not dlg.has_flag(isl.grove.flag(1)))
			story.reset()
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
