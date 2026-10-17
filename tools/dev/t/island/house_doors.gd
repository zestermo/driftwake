extends SceneTree
## Every Buildings.house kind (plain, porch, stilts, stilts with a porch, two storeys, a tall one with a
## fanlight, a barn-tall one with a pair of leaves) and the tavern: a closed panelled door (door_panel) with a
## "Door" marker at the foot of its steps, and steps you can walk: from the marker to the sill the floor rises
## with no wall in the way and never steeper than 40 degrees, ending at the door's sill. The tavern's doorway is
## open into its room. With "steps": false there are none.
const TK := preload("res://tools/dev/test_kit.gd")
const SPECS := [
	{"seed": 3},
	{"porch": 1.6, "door_x": -1.2, "seed": 4},
	{"stilts": 1.4, "foundation": 0.6, "seed": 5},
	{"stilts": 1.1, "foundation": 0.6, "porch": 1.4, "seed": 6},
	{"floors": 2, "roof": "gable_front", "w": 5.5, "seed": 7},
	{"h": 3.0, "w": 7.0, "roof": "shed", "seed": 8},
	{"h": 3.6, "w": 9.0, "d": 6.0, "door_x": -2.2, "seed": 9},
	{"w": 4.0, "d": 4.5, "seed": 10},
]
var stage
var step := 0
var until := 0
var fails := 0
var houses: Array = []
var bare: Node3D
var tavern: Node3D


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _has_tex(n: Node, tex: String) -> bool:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for s in range(m.get_surface_count()):
			var mat := m.surface_get_material(s) as ShaderMaterial
			var t = mat.get_shader_parameter("albedo_tex") if mat else null
			if t is Texture2D and (t as Texture2D).resource_path.get_file().get_basename() == tex:
				return true
	return false


func _down(space: PhysicsDirectSpaceState3D, at: Vector3) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 2, 0), at - Vector3(0, 2, 0)))
	return (hit["position"] as Vector3).y if hit else -INF


## From the Door marker in to the sill: floor heights every 5 cm, rising, never steeper than 40 deg; nothing
## at knee to chest height in the way. Returns "" or what's wrong.
func _walk(n: Node3D, sill: Vector3) -> String:
	var space := n.get_world_3d().direct_space_state
	var a: Vector3 = (n.get_node("Door") as Node3D).global_position
	var b: Vector3 = n.to_global(sill)
	var dist := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	var k := int(dist / 0.05)
	var prev := _down(space, a)
	for i in range(1, k + 1):
		var p := a.lerp(b, float(i) / k)
		var y := _down(space, p)
		if y == -INF:
			return "no floor at %.2f m" % (i * 0.05)
		if y - prev > tan(deg_to_rad(40.0)) * 0.05 + 0.002:
			return "a %.2f m step at %.2f m (from %.2f to %.2f)" % [y - prev, i * 0.05, prev, y]
		prev = y
	if absf(prev - b.y) > 0.05:
		return "ends at %.2f, the sill is at %.2f" % [prev, b.y]
	for hh in [0.5, 1.3]:
		var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, hh, 0), b + Vector3(0, hh, 0) - (b - a).normalized() * 0.12)
		var hit := space.intersect_ray(q)
		if hit:
			return "blocked at %s (h %.1f)" % [hit["position"], hh]
	return ""


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var B = load("res://scripts/props/buildings.gd")
			for i in range(SPECS.size()):
				var h: Node3D = B.house(SPECS[i].duplicate())
				h.position = Vector3(-45.0 + (i % 4) * 28.0, stage.GROUND_Y, -38.0 + (i / 4) * 22.0)
				stage.add_child(h)
				houses.append(h)
			bare = B.house({"stilts": 1.4, "foundation": 0.6, "steps": false, "seed": 11})
			bare.position = Vector3(25.0, stage.GROUND_Y, 25.0)
			stage.add_child(bare)
			tavern = B.tavern_hall()
			tavern.position = Vector3(-30.0, stage.GROUND_Y, 25.0)
			stage.add_child(tavern)
			until = TK.wait_ticks(3)
		1:
			var bad: Array = []
			for i in range(SPECS.size()):
				var spec: Dictionary = SPECS[i]
				var h: Node3D = houses[i]
				if h.get_node_or_null("Door") == null or not _has_tex(h, "door_panel") or _has_tex(h, "door"):
					bad.append("%d: no Door marker or no panelled door" % i)
					continue
				var fl := 0.3 + float(spec.get("stilts", 0.0))
				var dz := float(spec.get("d", 5.0)) * 0.5 + 0.2
				var why := _walk(h, Vector3(float(spec.get("door_x", 0.0)), fl, dz))
				if why != "":
					bad.append("%d %s: %s" % [i, spec, why])
			check("every house kind has a panelled door and steps you walk up from its Door marker to the sill %s" % [bad], bad.is_empty())
			var convex := bare.find_children("*", "CollisionShape3D", false, false).filter(func(c): return c.shape is ConvexPolygonShape3D)
			check("with steps false a stilted house has none", convex.is_empty())
			var why := _walk(tavern, Vector3(-1.6, 0.3, 9.0 * 0.5 + 0.1))
			check("the tavern: steps up to its doorway (%s)" % why, why == "")
			var space := tavern.get_world_3d().direct_space_state
			var a: Vector3 = (tavern.get_node("Door") as Node3D).global_position + Vector3(0, 1.3, 0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + Vector3(0, 0.3, -5.0)))
			check("and in through it nothing in the way for 5 m (%s)" % [hit.get("position", "-")], hit.is_empty() and _has_tex(tavern, "door_panel"))
			return TK.done(fails)
	step += 1
	return false
