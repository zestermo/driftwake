extends SceneTree
## Buildings.house's roofs sit over everything under them: on every roof kind, one and two storeys, a shallow
## and a steep pitch, no timber (the wall plate, the posts) inside the walls' footprint rises through the roof
## (the plate's top used to show as a dark line along every eave), a chimney stands at least 0.5 m clear of it, and the
## roof has its own collider from the wall tops up to the ridge (houses had none: 2026-10-22).
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


func _tex(mat: Material) -> String:
	var t = (mat as ShaderMaterial).get_shader_parameter("albedo_tex") if mat is ShaderMaterial else null
	return (t as Texture2D).resource_path.get_file().get_basename() if t is Texture2D else ""


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var B = load("res://scripts/props/buildings.gd")
	var bad: Array = []
	for kind in ["gable", "gable_front", "hip", "shed"]:
		for pitch in [0.45, 0.8]:
			for floors in [1, 2]:
				var w := 5.0
				var d := 4.5
				var spec := {"w": w, "d": d, "roof": kind, "pitch": pitch, "floors": floors, "chimney": true, "smoke": false, "seed": 5, "clutter": false}
				var n: Node3D = B.house(spec)
				var h := 2.6
				var uw := w + (0.7 if floors > 1 else 0.0)
				var ud := d + (0.7 if floors > 1 else 0.0)
				var top := 0.3 + h + (2.3 + 0.1 if floors > 1 else 0.0)
				var ev := 0.45 if kind == "hip" else 0.5
				var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", false, false)[0]
				var mesh := mi.mesh as ArrayMesh
				var chimney_top := -INF
				for s in range(mesh.get_surface_count()):
					var tex := _tex(mesh.surface_get_material(s))
					var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
					for v in verts:
						var inside := absf(v.x) <= uw * 0.5 + 0.12 and absf(v.z) <= ud * 0.5 + 0.12
						if tex == "stone_brick" and v.y > top:
							chimney_top = maxf(chimney_top, v.y)
						if tex == "planks_dark" and inside and v.y > top - 0.3:
							var ry: float = B._roof_y(kind, uw, ud, top + 0.09, top, pitch, ev, v.x, v.z)
							if v.y > ry + 0.005:
								bad.append("%s %.2f %d: timber at %s over the roof (%.2f)" % [kind, pitch, floors, v, ry])
								break
				var cx := -uw * 0.3
				var cz := -ud * 0.15
				var need := -INF
				for k in range(4):
					need = maxf(need, B._roof_y(kind, uw, ud, top + 0.09, top, pitch, ev, cx + (0.35 if k % 2 == 0 else -0.35), cz + (0.35 if k < 2 else -0.35)) + 0.5)
				if chimney_top < need:
					bad.append("%s %.2f %d: the chimney tops out at %.2f, under %.2f" % [kind, pitch, floors, chimney_top, need])
				# (something to stand on: the roof's own collider, up to the ridge and down to the wall tops)
				var rc := n.get_node_or_null("RoofCol") as CollisionShape3D
				var hi := -INF
				var lo := INF
				if rc and rc.shape is ConvexPolygonShape3D:
					for q in (rc.shape as ConvexPolygonShape3D).points:
						hi = maxf(hi, q.y)
						lo = minf(lo, q.y)
				var ridge: float = B._roof_y(kind, uw, ud, top + 0.09, top, pitch, ev, 0.0, 0.0)
				if not (hi >= ridge - 0.01 and lo <= top + 0.01):
					bad.append("%s %.2f %d: the roof collider spans %.2f..%.2f, not the wall tops %.2f to the ridge %.2f" % [kind, pitch, floors, lo, hi, top, ridge])
				n.free()
	check("no timber pokes through any roof, every chimney clears it, every roof can be stood on %s" % [bad], bad.is_empty())
	return TK.done(fails)
