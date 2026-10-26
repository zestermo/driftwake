extends SceneTree
## A chain island put in the world on the frame budget (as WorldGenerator does: each step budgeted, a step that
## breathes resumed a slice a frame) is the same island, node for node, as one built straight through (finish), and
## its slices keep to the budget where the steps breathe.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var node: Dictionary
var isl
var steps: Array = []
var si := 0
var waiting := false
var frames := 0
var straight: PackedStringArray
var worst := {}


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _island():
	var gi = load("res://scripts/island/gen_island.gd").new()
	gi.name = "Isle7"
	gi.prepare(node.duplicate(true))
	gi.position = Vector3(node["pos"].x, 0.0, node["pos"].y)
	stage.add_child(gi)
	gi.start_beasts()
	seed(4242)
	return gi


## What the build made (geometry, colliders, lights) under the island: its path (auto-name digits dropped), class,
## transform in the island's space to the mm, meshes by surfaces and vertices. Not what lives (anything under a
## body that moves: the bugs a nest hatches, a camp's crew, villagers walk off and turn up a frame at a time).
const BUILT := ["MeshInstance3D", "MultiMeshInstance3D", "CollisionShape3D", "StaticBody3D", "OmniLight3D", "SpotLight3D"]
func _dump(gi: Node3D) -> PackedStringArray:
	var out := PackedStringArray()
	var inv: Transform3D = gi.global_transform.affine_inverse()
	var auto := RegEx.create_from_string("@[^/@]*@\\d+")
	for n in gi.find_children("*", "", true, false):
		if not BUILT.has(n.get_class()) or _lives(n, gi):
			continue
		var line := "%s %s" % [auto.sub(str(gi.get_path_to(n)), "@auto", true), n.get_class()]
		if n is Node3D:
			var t: Transform3D = inv * (n as Node3D).global_transform
			line += " %.3f,%.3f,%.3f %.3f,%.3f,%.3f" % [t.origin.x, t.origin.y, t.origin.z, t.basis.x.x, t.basis.y.y, t.basis.z.z]
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var m: Mesh = (n as MeshInstance3D).mesh
			var v := 0
			for s in range(m.get_surface_count()):
				v += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() if m is ArrayMesh else 0
			line += " mesh %d/%d" % [m.get_surface_count(), v]
		out.append(line)
	out.sort()
	return out


func _lives(n: Node, gi: Node) -> bool:
	var a := n
	while a != gi:
		if a is CharacterBody3D or a is RigidBody3D or a is AnimatableBody3D:
			return true
		a = a.get_parent()
	return false


func _run(s: Array) -> void:
	isl.budget()
	var w: int = await isl.run_step(s)
	isl.unbudget()
	worst[s[0]] = maxi(int(worst.get(s[0], 0)), w)
	waiting = false
	si += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			# (the village's elder talks of the islands ahead: a stand-in WorldGenerator with the chain)
			var c = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242).c
			node = c.node(int(c.start_next[0]))
			load("res://scripts/island/island_theme.gd").meshes(str(node["theme"]))
			isl = _island()
			isl.finish()
			straight = _dump(isl)
			print("straight through: %d nodes" % straight.size())
			isl.free()
			load("res://scripts/psx/mesh_builder.gd").forget()
		1:
			isl = _island()
			steps = isl.finish_steps()
		2:
			frames += 1
			if waiting:
				isl.resume.emit()
			while not waiting and si < steps.size():
				waiting = true
				_run(steps[si])
			if si < steps.size():
				return false
			isl.building = false
			load("res://scripts/psx/mesh_builder.gd").forget()
			var budgeted := _dump(isl)
			var first := ""
			for i in range(mini(straight.size(), budgeted.size())):
				if straight[i] != budgeted[i]:
					first = "%s  vs  %s" % [straight[i], budgeted[i]]
					break
			check("budgeted over %d frames: the same island, node for node (%d vs %d nodes)%s" % [frames, budgeted.size(), straight.size(), ("; first difference: " + first) if first != "" else ""],
				budgeted == straight)
			print("worst slice by step (ms): %s" % str(worst))
			check("the wayside's slices keep near the budget (%d ms)" % int(worst.get("wayside", 0)), int(worst.get("wayside", 0)) <= 8)
			return TK.done(fails)
	step += 1
	return false
