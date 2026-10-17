extends SceneTree
## The desert's town models (DesertTown through the style's village_models and item_models): every kind
## builds with a collider and stands on a footing below the ground; the rooms you walk into have the kit's
## markers (Door outside the doorway, Inside, and the kind's own) and their doorway is open; the workshop,
## shrine and ruin carry theirs; a lit dressing item has its Flame; the same seed builds the same; the desert
## rolls no stilt village.
const TK := preload("res://tools/dev/test_kit.gd")
const MARKERS := {"home": ["Door", "Inside", "Bed", "Table", "Hearth"], "elder": ["Door", "Inside", "Bed", "Table", "Hearth"],
	"trade": ["Door", "Inside", "Vendor", "Customer"], "cook": ["Door", "Inside", "Vendor", "Customer"], "workshop": ["Worker", "Bench"],
	"shrine": ["Keeper", "Pray"], "ruin": ["Cache"]}
var stage
var step := 0
var until := 0
var fails := 0
var built := {}
var bad: Array = []


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
	var KS = load("res://scripts/island/kit/kit_style.gd")
	var VL = load("res://scripts/island/village_layouts.gd")
	var st: Dictionary = KS.of("desert")
	var models: Dictionary = st["village_models"]
	match step:
		0:
			# every kind, side by side 30 m apart, out of the stage's way
			var x := 0.0
			for kind in models.keys():
				var sz: Array = VL.SIZE[kind]
				var rng := RandomNumberGenerator.new()
				rng.seed = 31
				var n: Node3D = KS.model(models[kind], rng, maxf(sz[0], sz[1]))
				root.add_child(n)
				n.global_position = Vector3(x, 0.0, 200.0)
				x += 30.0
				built[kind] = n
			until = TK.wait_ticks(3)
		1:
			for kind in built.keys():
				var n: Node3D = built[kind]
				var cols := n.find_children("*", "CollisionShape3D", true, false)
				var meshes := n.find_children("*", "MeshInstance3D", true, false)
				if cols.is_empty() or meshes.is_empty():
					bad.append("%s: %d colliders, %d meshes" % [kind, cols.size(), meshes.size()])
				var low := INF
				for mi in meshes:
					low = minf(low, ((mi as MeshInstance3D).transform * (mi as MeshInstance3D).get_aabb()).position.y)
				if kind != "storehouse" and kind != "ruin" and low > -1.0:
					bad.append("%s: no footing below the ground (%.2f)" % [kind, low])
				for m in MARKERS.get(kind, []):
					if n.get_node_or_null(m) == null:
						bad.append("%s: no %s" % [kind, m])
				if MARKERS.get(kind, []).has("Door"):
					# the doorway's open: nothing solid on the line from outside the door in to the room, at chest height
					var a: Vector3 = (n.get_node("Door") as Node3D).global_position + Vector3(0, 1.3, 0)
					var b: Vector3 = (n.get_node("Inside") as Node3D).global_position + Vector3(0, 1.0, 0)
					var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b))
					if not hit.is_empty():
						bad.append("%s: its doorway is blocked at %s" % [kind, hit["position"]])
				n.queue_free()
			check("every village kind builds, a collider, a footing, its markers, an open doorway %s" % [bad], bad.is_empty())
			var r1 := RandomNumberGenerator.new()
			r1.seed = 5
			var r2 := RandomNumberGenerator.new()
			r2.seed = 5
			var h1: Node3D = KS.model(models["tall"], r1, 5.4)
			var h2: Node3D = KS.model(models["tall"], r2, 5.4)
			var m1: Mesh = (h1.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
			var m2: Mesh = (h2.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
			check("the same seed builds the same house", m1.get_faces() == m2.get_faces())
			h1.free()
			h2.free()
			var items: Dictionary = st["item_models"]
			var torch: Node3D = KS.model(items["torch"], RandomNumberGenerator.new(), 1.0)
			var well: Node3D = KS.model(items["well"], RandomNumberGenerator.new(), 1.0)
			check("the desert's torch is a brazier with a Flame, its well has a collider",
				torch.get_node_or_null("Flame") != null and well.find_children("*", "CollisionShape3D", true, false).size() > 0)
			torch.free()
			well.free()
			check("the desert rolls medinas, towns, hamlets and buried ruins, never a stilt village (%s)" % [st["village_layouts"]],
				int(st["village_layouts"]["stilts"]) == 0 and int(st["village_layouts"]["ruins"]) > 0 and int(st["village_layouts"]["medina"]) > 0
				and KS.of("jungle")["village_layouts"] == VL.POOL)
			# its own lookout and camp house, not the kit's timber ones; its planters and garden walls
			var tw: Node3D = KS.lookout(st, 9.0, 3)
			root.add_child(tw)
			tw.global_position = Vector3(0, 0, 240.0)
			built["tower"] = tw
			var hut: Node3D = KS.model(st["camp_shack"], RandomNumberGenerator.new(), 5.5)
			root.add_child(hut)
			hut.global_position = Vector3(30, 0, 240.0)
			built["hut"] = hut
			var bits := ["planter", "fence"].map(func(k): return KS.model(items[k], RandomNumberGenerator.new(), 1.0))
			check("a planter and a garden wall, each with a collider", bits.all(func(x): return x.find_children("*", "CollisionShape3D", true, false).size() > 0))
			for x in bits:
				x.free()
			until = TK.wait_ticks(3)
		2:
			var tw: Node3D = built["tower"]
			var lads: Array = tw.get_children().filter(func(x): return x.get("deck_depth") != null)
			var lad: Node3D = lads[0] if lads.size() > 0 else null
			var space := root.world_3d.direct_space_state
			var deck := space.intersect_ray(PhysicsRayQueryParameters3D.create(tw.global_position + Vector3(0.3, 12.0, -0.6), tw.global_position + Vector3(0.3, 5.0, -0.6)))
			check("the desert's lookout: not the timber one, a platform at its height, a ladder from it to the ground on +Z",
				tw.find_children("WatchtowerMesh", "", true, false).size() == 1 and not deck.is_empty() and absf(deck["position"].y - 9.09) < 0.05
				and lad != null and absf(lad.position.y - 9.09) < 0.05 and lad.position.z > 1.5 and absf(float(lad.get("length")) - lad.position.y) < 0.05)
			var hut: Node3D = built["hut"]
			check("the bandits' hideout: mud brick with a collider, not a timber shack", hut.find_children("ShackMesh", "", true, false).size() == 1
				and hut.find_children("*", "CollisionShape3D", true, false).size() > 0)
			tw.queue_free()
			hut.queue_free()
			return TK.done(fails)
	step += 1
	return false
