extends SceneTree
## Cloth on the hips layered as worn (1.24 clothing fixes): under a long coat a skirt or a tunic's hem hangs only in the
## coat's opening (none under the frock, buttoned closed), under a jacket it's cut inside the tails; every panel stands
## clear of the seat behind.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	for body in ["fem", "masc"]:
		for coat in ["longcoat", "duster", "frock", "jacket", "none"]:
			for under in [{"legs": "skirt"}, {"top": "tunic"}]:
				var lk: Dictionary = CharacterLook.default_look()
				lk.merge({"body": body, "build": "stout", "coat": coat}, true)
				lk.merge(under, true)
				var h = Humanoid.new()
				h.setup(lk)
				root.add_child(h)
				var tag := "%s %s over %s" % [body, coat, under.values()[0]]
				var sim = null
				for s in h._sims:
					if s.get_parent() == h.hips:
						sim = s
				var coat_n: int = {"longcoat": 4, "duster": 4, "frock": 6, "jacket": 4, "none": 0}[coat]
				var n_under: int = sim.chain_count() - coat_n if sim else 0
				var want: int = {"frock": 0, "longcoat": 2, "duster": 2}.get(coat, 6)
				check("%s: %d panels underneath (want %d)" % [tag, n_under, want], n_under == want)

				var worst := INF
				if sim:
					for ci in range(sim.chain_count()):
						var p: PackedVector3Array = sim.chain(ci)["p"]
						for i in range(1, p.size()):
							if p[i].z > 0.0 and absf(p[i].x) < 0.13:
								worst = minf(worst, p[i].z - _seat(h, p[i].x))
				check("%s: the panels behind clear the seat (by %.1f cm)" % [tag, worst * 100.0], worst > 0.01)
				h.free()
	return TK.done(fails)


## How far back the seat's mesh reaches within 3 cm of x, from the hips down to the crotch (hips space).
func _seat(h, x: float) -> float:
	var inv: Transform3D = h.hips.global_transform.affine_inverse()
	var z := -INF
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		if mi.get_parent().name != "LowerBody" and mi.name != "LowerBody":
			continue
		var t: Transform3D = inv * mi.global_transform
		var m: Mesh = mi.mesh
		for s in range(m.get_surface_count()):
			for v in (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var q: Vector3 = t * v
				if q.y < 0.0 and q.y > -0.2 and absf(q.x - x) < 0.03:
					z = maxf(z, q.z)
	return z
