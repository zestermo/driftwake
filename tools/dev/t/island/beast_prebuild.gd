extends SceneTree
## A beast's model built ahead (QuadBeast.prebuild on a worker, GenIsland.start_beasts) is the model it builds in the
## world: every kind that can, both ways, the same rig, parts, vertices and colours, its coat on its own material copy
## (the hit flash), the shared one untouched. One made ahead and never put in the world frees its model with it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var kinds: Array = []


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _cfg(at: Vector3) -> Dictionary:
	return {"post": at, "yaw": 0.4, "level": 6, "variant": 1, "name": "Probe"}


var verts := 0


func _model(b: Node) -> Array:
	var out: Array = []
	var model: Node = b.get("model")
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh as ArrayMesh
		var line := str(model.get_path_to(mi))
		for i in range(m.get_surface_count()):
			var arr := m.surface_get_arrays(i)
			var mat := m.surface_get_material(i) as ShaderMaterial
			verts += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			line += " %d:%d:%d:%s" % [i, hash(arr[Mesh.ARRAY_VERTEX]), hash(arr[Mesh.ARRAY_COLOR]), str(mat.get_shader_parameter("albedo_color")) + str(mat.get_shader_parameter("albedo_tex"))]
		out.append(line)
	for n in model.find_children("*", "Node3D", true, false):
		out.append("%s %s" % [model.get_path_to(n), (n as Node3D).transform])
	return out


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			for th in load("res://scripts/island/themes/island_themes.gd").all():
				for k in th.beasts.keys():
					var info: Dictionary = th.beasts[k]
					if info.has("script") and not info.has("stock") and not info.get("camp", false) and not kinds.has(info["script"]):
						var probe: Node = load(info["script"]).new()
						if probe.has_method("prebuild"):
							kinds.append(info["script"])
						probe.free()
			check("kinds that build ahead: %d" % kinds.size(), kinds.size() >= 10)
			var x := 0.0
			for path in kinds:
				var a: Node = load(path).new()
				a.setup(_cfg(Vector3(x, 0.4, 30.0)))
				stage.add_child(a)
				var b: Node = load(path).new()
				b.set("variant", 1)
				var task := WorkerThreadPool.add_task(b.prebuild)
				WorkerThreadPool.wait_for_task_completion(task)
				b.setup(_cfg(Vector3(x, 0.4, 40.0)))
				stage.add_child(b)
				x += 12.0
				verts = 0
				var same: bool = _model(a) == _model(b)
				check("%s: built ahead = built in the world (%d pieces, %d vertices)" % [path.get_file(), _model(a).size(), verts], same and verts > 1000)
				var coat: Material = b.get("spec")["coat_mat"]
				var body_mat := ((b.get("rig")["Body"] as Node).get_node("Mesh") as MeshInstance3D).mesh.surface_get_material(0)
				check("%s: its coat is its own copy" % path.get_file(), (b.get("_mats") as Array).has(coat) and coat != PSXMat.lit(str(b.get("spec")["tex"]), Color(1.15, 1.15, 1.15))
					and (b.get("_mats") as Array).has(body_mat))
				a.queue_free()
				b.queue_free()
			var c: Node = load(kinds[0]).new()
			c.prebuild()
			var model: Node = c.get("model")
			c.free()
			check("made ahead, never in the world: its model goes with it", not is_instance_valid(model))
			return TK.done(fails)
	step += 1
	return false
