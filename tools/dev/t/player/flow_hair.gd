extends SceneTree
## The long lock hairstyles (HairFlow): each builds a skinned hair mesh on spring chains within its
## budget, also under a hat. (No physics checks: hair/cloth motion is judged by hand.)
const TK := preload("res://tools/dev/test_kit.gd")
const MAX_TRIS := 11000
const MAX_BONES := 100
var stage
var bodies: Array = []
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var i := 0
			for st in HairFlow.STYLES:
				for hat in ["none", "tricorn"]:
					var lk := CharacterLook.base_look()
					lk["hair"] = st
					lk["hat"] = hat
					lk["body"] = "fem" if st != "mane" else "masc"
					lk["hair_tip"] = Color(0.8, 0.2, 0.2)
					var h := Humanoid.new()
					h.setup(lk)
					root.add_child(h)
					h.position = Vector3(i * 2.0 - 16.0, 0, 8.0)
					bodies.append([st + "/" + hat, h])
					i += 1
			until = TK.wait_ticks(2)
		1:
			for e in bodies:
				var name_: String = e[0]
				var h = e[1]
				var sims: Array = h.head.find_children("*", "SpringChains", true, false)
				check("%s: one set of chains on the head" % name_, sims.size() == 1)
				if sims.is_empty():
					continue
				var sc = sims[0]
				var mi := sc.find_child("Mesh", true, false) as MeshInstance3D
				check("%s: the hair mesh is committed" % name_, mi != null and mi.mesh != null)
				if mi == null:
					continue
				var tris := 0
				for si in range(mi.mesh.get_surface_count()):
					tris += (mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
				check("%s: %d triangles, 1500..%d" % [name_, tris, MAX_TRIS], tris >= 1500 and tris <= MAX_TRIS)
				check("%s: %d bones <= %d" % [name_, sc.skel.get_bone_count(), MAX_BONES], sc.skel.get_bone_count() <= MAX_BONES)
			return TK.done(fails)
	step += 1
	return false
