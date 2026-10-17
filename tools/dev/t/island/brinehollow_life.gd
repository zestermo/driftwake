extends SceneTree
## Brinehollow's townsfolk on their routines (BrinehollowLife, the town's walk graph): everyone in
## BrinehollowCast.townsfolk is made once, by name; at 10:00 the shopkeepers are behind their counters on the
## market street (Corin at his, trading); at 21:00 the Salted Gull is busy (Corin by its fire, still trading);
## at 2:00 everyone's indoors. No one stops in a doorway or on the long stair, and every walk keeps clear of
## the buildings, stalls and walls (rays along each leg at waist height).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var isl
var folk := {}


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


func _local(n: Node3D) -> Vector2:
	var l: Vector3 = isl.to_local(n.global_position)
	return Vector2(l.x, l.z)


func _in_tavern(n: Node3D) -> bool:
	var l: Vector3 = isl._tavern.to_local(n.global_position)
	return absf(l.x) < 5.8 and absf(l.z) < 4.3


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			# (the captain stays on the stage, 9 km off: keep the town awake)
			load("res://scripts/world/actor_sleep.gd").enabled = false
			isl = load("res://scripts/island/starter_island.gd").new()
			isl.name = "Brinehollow"
			isl.position = Vector3(0, 0, 9000)
			stage.add_child(isl)
			isl.build(42)
			print("   life built in %s ms (%s)" % [str(isl.build_ms.get("life", "?")), str(isl.build_ms)])
			# a camera 110-125 m over the town: everyone shown, and on their schedule to the letter (past NEAR_R)
			var cam := Camera3D.new()
			root.add_child(cam)
			cam.global_position = isl.to_global(Vector3(0, 110, -60))
			cam.make_current()
			_at(10.0)
			until = TK.wait_ticks(30)
		1:
			var names: Array = load("res://scripts/island/brinehollow_cast.gd").townsfolk().map(func(e): return str(e["cfg"]["name"]))
			for n in isl.get_children():
				if n.get("stays") != null and names.has(n.npc_name):
					folk[n.npc_name] = n
			check("every townsperson made once (%d of %d)" % [folk.size(), names.size()], folk.size() == names.size() and names.size() >= 16)
			var keepers := {"Corin": "Shop4", "Hester Quill": "Shop0", "Abel Marsh": "Shop1", "Rosa Tamm": "Shop2",
				"Pip Calloway": "Shop3", "Mags Ferrow": "Shop5", "Jory Lusk": "StreetStall0"}
			var at_work := 0
			for who in keepers:
				var where: Node3D = null
				for s in isl.town_spots["shops"] + isl.town_spots["stalls"]:
					if s.name == keepers[who]:
						where = s
				if folk.has(who) and _local(folk[who]).distance_to(isl.kit.marker_point(where, "Vendor")) < 0.8 and folk[who].visible:
					at_work += 1
				else:
					print("   %s at %s, %s's Vendor at %s" % [who, str(_local(folk[who])) if folk.has(who) else "-", keepers[who], str(isl.kit.marker_point(where, "Vendor"))])
			check("at 10:00 the shopkeepers keep their counters (%d of %d)" % [at_work, keepers.size()], at_work == keepers.size())
			check("Corin trades there", folk.has("Corin") and folk["Corin"].shop_id == "corin")
			# stops: never in a doorway or on the stair
			var doors: Array = []
			for n in isl.find_children("Door", "Marker3D", true, false):
				doors.append(_local(n))
			var bad: Array = []
			for f in folk.values():
				for s in f.stays:
					var p: Vector2 = s["at"]
					if s["act"] != "home" and doors.any(func(d): return d.distance_to(p) < 1.1):
						bad.append("%s %s by a door" % [f.npc_name, s["kind"]])
					if absf(p.x - isl.UP_X) < 1.7 and p.y > isl.UP_Z0 and p.y < isl.UP_Z1:
						bad.append("%s %s on the stair" % [f.npc_name, s["kind"]])
			check("no one stops in a doorway or on the stair %s" % str(bad.slice(0, 6)), bad.is_empty())
			# the walks: a ray along each leg at waist height
			var space: PhysicsDirectSpaceState3D = isl.get_world_3d().direct_space_state
			var skip: Array = []
			for f in get_nodes_in_group("npcs"):
				skip.append(f.get_node("Body").get_rid())
			var blocked: Array = []
			var legs := 0
			for f in folk.values():
				for w in f.walks:
					for i in range(w.size() - 1):
						var a: Vector2 = w[i]
						var b: Vector2 = w[i + 1]
						if a.distance_to(b) < 0.05:
							continue
						legs += 1
						var ya: float = f.town.y_at(a, isl.hv(a)) + 0.9
						var yb: float = f.town.y_at(b, isl.hv(b)) + 0.9
						var q := PhysicsRayQueryParameters3D.create(isl.to_global(Vector3(a.x, ya, a.y)), isl.to_global(Vector3(b.x, yb, b.y)))
						q.exclude = skip
						var hit := space.intersect_ray(q)
						if hit and not blocked.has(str(hit["collider"].name)):
							blocked.append(str(hit["collider"].name))
							print("   %s: %s -> %s hits %s" % [f.npc_name, str(a), str(b), str(hit["collider"].get_path())])
			check("every walk keeps clear of what's built (%d legs; hit %s)" % [legs, str(blocked)], blocked.is_empty())
			_at(21.0)
			until = TK.wait_ticks(30)
		2:
			var inside := folk.values().filter(func(f): return f.visible and _in_tavern(f))
			check("at 21:00 the Salted Gull is busy (%d inside)" % inside.size(), inside.size() >= 8)
			check("Corin's in by the fire, still trading", folk.has("Corin") and _in_tavern(folk["Corin"]) and folk["Corin"].visible)
			_at(2.0)
			until = TK.wait_ticks(30)
		3:
			var out := folk.values().filter(func(f): return f.visible)
			check("at 2:00 everyone's indoors (%s out)" % str(out.map(func(f): return f.npc_name)), out.is_empty())
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
