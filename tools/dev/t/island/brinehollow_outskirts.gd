extends SceneTree
## Brinehollow's outskirts' people (BrinehollowCast.outskirts): at 8:36 the shrine's keeper stands before its
## doors, the tea-mistress behind her counter, the miller at his mill, the two farmhands at work among a field's
## rows (inside its fence), the cove's fisher sat on his jetty with his rod out; every one of their walks keeps
## clear of what's built (fences included); at 2:00 they're all indoors.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var isl
var folk := {}
var cam: Camera3D


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _at(h: float) -> void:
	var wx = root.get_node("Weather")
	wx.set_world_time(wx.time_at(h))


func _flat(n: Node3D) -> Vector2:
	var l: Vector3 = isl.to_local(n.global_position)
	return Vector2(l.x, l.z)


func _near_mark(who: String, node: Node3D, marker: String) -> bool:
	return _flat(folk[who]).distance_to(_flat(node.get_node(marker))) < 1.0


func _in_field(who: String) -> bool:
	var p := _flat(folk[who])
	for f in isl.FIELDS:
		var l: Vector2 = (p - f[0]).rotated(float(f[2]))
		if absf(l.x) < f[1].x and absf(l.y) < f[1].y:
			return true
	return false


## The height a walker is at walk k's point j (BrinehollowFolk's: the floor, ramping to a stay's own over RAMP m).
func _walk_y(f, k: int, j: int) -> float:
	var p: Vector2 = f.walks[k][j]
	var y: float = f.town.y_at(p, isl.hv(p))
	var cum: PackedFloat32Array = f.cums[k]
	var left: float = cum[cum.size() - 1] - cum[j]
	var s0: Dictionary = f.stays[k - 1]
	var s1: Dictionary = f.stays[k]
	if s1.has("y") and left < f.RAMP:
		return lerpf(float(s1.get("walk_y", s1["y"])), y, left / f.RAMP)
	if s0.has("y") and cum[j] < f.RAMP:
		return lerpf(float(s0.get("walk_y", s0["y"])), y, cum[j] / f.RAMP)
	return y


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			load("res://scripts/world/actor_sleep.gd").enabled = false
			isl = load("res://scripts/island/starter_island.gd").new()
			isl.name = "Brinehollow"
			isl.position = Vector3(0, 0, 9000)
			stage.add_child(isl)
			isl.build(42)
			# (a camera 80-140 m off whoever's looked at: on schedule to the letter, and shown)
			cam = Camera3D.new()
			root.add_child(cam)
			cam.global_position = isl.to_global(Vector3(0, 100, 30))
			cam.make_current()
			var names: Array = load("res://scripts/island/brinehollow_cast.gd").outskirts().map(func(e): return str(e["cfg"]["name"]))
			for n in isl.get_children():
				if n.get("stays") != null and names.has(n.npc_name):
					folk[n.npc_name] = n
			check("the outskirts' people made (%d of %d)" % [folk.size(), names.size()], folk.size() == names.size())
			var space: PhysicsDirectSpaceState3D = isl.get_world_3d().direct_space_state
			var skip: Array = get_nodes_in_group("npcs").map(func(f): return f.get_node("Body").get_rid())
			var blocked: Array = []
			for f in folk.values():
				for k in range(f.walks.size()):
					var w: PackedVector2Array = f.walks[k]
					for i in range(w.size() - 1):
						var a: Vector2 = w[i]
						var b: Vector2 = w[i + 1]
						if a.distance_to(b) < 0.05:
							continue
						var q := PhysicsRayQueryParameters3D.create(isl.to_global(Vector3(a.x, _walk_y(f, k, i) + 0.9, a.y)), isl.to_global(Vector3(b.x, _walk_y(f, k, i + 1) + 0.9, b.y)))
						q.exclude = skip
						var hit := space.intersect_ray(q)
						if hit:
							blocked.append("%s %s->%s %s" % [f.npc_name, str(a), str(b), str(hit["collider"].name)])
			check("their walks keep clear of what's built %s" % str(blocked.slice(0, 4)), blocked.is_empty())
			_at(8.6)
			until = TK.wait_secs(1.5)
		1:
			var ts: Dictionary = isl.town_spots
			check("the shrine's keeper before its doors", _near_mark("Keeper Sanae", ts["shrine"], "Priest"))
			check("the tea-mistress behind her counter", _near_mark("Hana Teal", ts["teahouse"], "Vendor"))
			check("the miller at his mill", _near_mark("Miller Brann", ts["windmill"], "Miller"))
			check("the farmhands are in the fields", _in_field("Farmhand Joss") and _in_field("Farmhand Wynn"))
			cam.global_position = isl.to_global(Vector3(isl.FARM.x, 75, isl.FARM.y))
			until = TK.wait_secs(1.0)
		2:
			check("...on their knees among the rows", folk["Farmhand Joss"].humanoid.kneeling and folk["Farmhand Wynn"].humanoid.kneeling)
			var c: Vector2 = isl.town_spots["cove2"]["beach"]
			cam.global_position = isl.to_global(Vector3(c.x, 80, c.y))
			until = TK.wait_secs(1.0)
		3:
			check("the cove's fisher sat on his jetty, rod out", folk["Old Gannet"].humanoid.seated and folk["Old Gannet"].rod_node.visible)
			_at(2.0)
			until = TK.wait_secs(1.5)
		4:
			var out: Array = folk.values().filter(func(f): return f._home == false)
			check("at 2:00 they're all indoors (%s)" % str(out.map(func(f): return f.npc_name)), out.is_empty())
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
