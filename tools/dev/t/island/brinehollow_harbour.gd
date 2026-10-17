extends SceneTree
## Brinehollow's busier harbour (BrinehollowHarbour): five smacks at the quay wall, none in the sloop's berth lane
## nor on top of the piers' hulls and the longboats; the two that fish are out on their grounds at 10:00 (their
## courses never entering the berth lane) and home at 18:00; at 7:00 the fishers sit on the piers' edges with their
## rods out, at 12:00 they're off the piers; the dockers carry their loads out along the merchant's pier.
const TK := preload("res://tools/dev/test_kit.gd")
var HARBOUR
var stage
var step := 0
var until := 0
var fails := 0
var isl
var boats: Array = []
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


func _flat(n: Node3D) -> Vector2:
	var l: Vector3 = isl.to_local(n.global_position)
	return Vector2(l.x, l.z)


func _on_pier(f) -> bool:
	return f.visible and f.humanoid.seated and f.rod_node.visible


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			load("res://scripts/world/actor_sleep.gd").enabled = false
			HARBOUR = load("res://scripts/island/brinehollow_harbour.gd")
			isl = load("res://scripts/island/starter_island.gd").new()
			isl.name = "Brinehollow"
			isl.position = Vector3(0, 0, 9000)
			stage.add_child(isl)
			isl.build(42)
			var cam := Camera3D.new()
			root.add_child(cam)
			cam.global_position = isl.to_global(Vector3(5, 80, -125))
			cam.make_current()
			var smacks: Array = isl.get_children().filter(func(n): return str(n.name).begins_with("Smack"))
			boats = smacks.filter(func(n): return n.get("route") != null)
			check("five smacks at the quay, two of them fishing (%d, %d)" % [smacks.size(), boats.size()], smacks.size() == 5 and boats.size() == 2)
			var others: Array = isl.get_children().filter(func(n): return str(n.name).begins_with("Longboat") or str(n.name).begins_with("Moored_"))
			var clash: Array = []
			for s in smacks:
				if HARBOUR.berth_lane(isl, _flat(s)):
					clash.append("%s in the berth lane" % s.name)
				for o in others:
					if _flat(s).distance_to(_flat(o)) < (6.0 if str(o.name).begins_with("Moored_") else 3.0):
						clash.append("%s on %s" % [s.name, o.name])
			check("none in the sloop's lane or on another boat %s" % str(clash), clash.is_empty())
			var lane_hits := 0
			for b in boats:
				for k in range(41):
					var smp: Array = load("res://scripts/island/kit/kit_life.gd").sample(b.route, b.cum, b.cum[b.cum.size() - 1] * k / 40.0)
					if HARBOUR.berth_lane(isl, smp[0]):
						lane_hits += 1
			check("their courses keep out of the berth lane", lane_hits == 0)
			var names: Array = load("res://scripts/island/brinehollow_cast.gd").harbourfolk().map(func(e): return str(e["cfg"]["name"]))
			for n in isl.get_children():
				if n.get("stays") != null and names.has(n.npc_name):
					folk[n.npc_name] = n
			check("the harbour's people made (%d of %d)" % [folk.size(), names.size()], folk.size() == names.size())
			_at(7.0)
			until = TK.wait_secs(1.5)
		1:
			var fishing: Array = ["Sully Penhallow", "Kit Garrow", "Fen Doyle"].filter(func(n): return _on_pier(folk[n]))
			check("at 7:00 the fishers sit on the piers' edges, rods out (%s)" % str(fishing), fishing.size() == 3)
			_at(10.0)
			until = TK.wait_secs(1.5)
		2:
			var out: Array = boats.filter(func(b): return _flat(b).distance_to(b.home) > 120.0 and b.sail.visible and b.crew.visible)
			check("at 10:00 both smacks are out on their grounds, sail set, crew aboard (%d)" % out.size(), out.size() == 2)
			var carrying: Array = []
			for k in range(80):
				var h := 9.0 + k * 0.1
				for who in ["Docker Abby", "Docker Thom"]:
					var f = folk[who]
					var w: Array = f.spot_at(h)
					if w[2] == "walk" and f.stays[f.scheduled(h)[0]].get("carry", false):
						carrying.append(who)
			check("the dockers carry loads out to the merchantman", carrying.has("Docker Abby") and carrying.has("Docker Thom"))
			_at(12.0)
			until = TK.wait_secs(1.5)
		3:
			check("at 12:00 the fishers are off the piers", ["Sully Penhallow", "Kit Garrow", "Fen Doyle"].all(func(n): return not _on_pier(folk[n])))
			_at(18.0)
			until = TK.wait_secs(1.5)
		4:
			check("at 18:00 the smacks are home, sails furled", boats.all(func(b): return _flat(b).distance_to(b.home) < 0.5 and not b.sail.visible))
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
