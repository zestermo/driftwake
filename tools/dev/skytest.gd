extends SceneTree
## The living sea and sky (v1.12): birds over Brinehollow by day (high flocks, the
## harbour's gulls), a perched gull scattering from a captain running at it, none
## at night and back at dawn, gulls coming out to the ship near land, everything
## freed far out at sea under the cap; the ship's spray (ShipSpray) quiet at rest,
## the bow wave, slaps and sheets of spray under full sail in a storm, asleep
## with the camera far; foam patches on the swell and waves breaking on the coast.
const TK := preload("res://tools/dev/test_kit.gd")
var t := 0.0
var step := 0
var until := 0
var fails := 0
var p
var ship
var wx
var sky
## SkyBirds' script, for its constants (it can't be named before the autoloads are up).
var SB
var sp
var amb
var gull: Dictionary
var saw := {}
var cam: Camera3D


func _initialize():
	TK.seed_of(self)
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func set_hour(h: float) -> void:
	wx.skip_to(h)


func weather(s: int) -> void:
	wx.forced = s
	wx.forced_at = wx.world_time() - 100.0


func put(at: Vector3) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func board() -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = ship.global_transform * Vector3(0.0, HullBuilder.DECK_Y + 0.3, -2.0)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func mine(owner: String, kind := -1) -> Array:
	return sky.birds.filter(func(b): return b["owner"] == owner and not b["dead"] and (kind < 0 or b["kind"] == kind))


## Deep water `r` m from Brinehollow's middle.
func sea_at(r: float) -> Vector3:
	var wg = root.get_node("World/Islands")
	for k in range(32):
		var a := k * TAU / 32.0
		var c: Vector2 = wg.starter_center + Vector2(cos(a), sin(a)) * r
		if wg._deep_enough(c, 140.0):
			return Vector3(c.x, 0, c.y)
	return Vector3.INF


func _process(d: float) -> bool:
	t += d
	if t > 240.0:
		check("timed out at step %d" % step, false)
		print("RESULT FAILED (%d)" % fails)
		quit()
		return true
	if TK.ticking(until):
		return false
	match step:
		0:
			if t < 2.0:
				return false
			for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
			p = get_first_node_in_group("player")
			ship = get_first_node_in_group("ship")
			wx = root.get_node("Weather")
			amb = root.get_node("Weather/Ambience")
			sky = root.get_node("Weather/Ambience/SkyBirds")
			SB = sky.get_script()
			sp = ship.get_node("ShipSpray")
			check("the birds and the ship's spray are made", sky != null and sp != null)
			set_hour(12.0)
			weather(0)
			var isl = root.get_node("World/Islands/Brinehollow")
			var dp: Vector2 = isl._dock_point(isl.DOCK_LENGTH)
			put(isl.to_global(Vector3(dp.x, isl.DOCK_DECK_Y + 0.2, dp.y)))
			until = TK.wait_secs(4.0)
			step += 1
		1:
			var all := mine("brinehollow")
			var dark := mine("brinehollow", SB.DARK)
			var gulls := mine("brinehollow", SB.GULL)
			var high := dark.filter(func(b): return float(b["pos"].y) > 30.0)
			print("   Brinehollow at noon: %d birds (%d high flock, %d gulls, %d parrots), %d drawn, %d perched, day %.2f" % [all.size(), dark.size(), gulls.size(),
				mine("brinehollow", SB.PARROT).size(), sky.shown(), gulls.filter(func(b): return b["mode"] == SB.PERCH).size(), sky.day])
			check("birds over Brinehollow by day: a flock wheeling high", dark.size() >= 5 and high.size() >= 5)
			check("...gulls round the harbour", gulls.size() >= 4)
			check("...and they're drawn", sky.shown() >= 8)
			check("never more than the cap (%d of %d)" % [sky.birds.size(), SB.MAX], sky.birds.size() <= SB.MAX)
			# a gull sitting on the dock; a captain runs at it
			gull = gulls[0]
			gull["perch"] = p.global_position + Vector3(0.0, -0.2, 0.0) + (p.global_basis.x * 0.0)
			var dock_dir: Vector3 = (gull["perch"] - root.get_node("World/Islands/Brinehollow").global_position)
			dock_dir.y = 0.0
			saw["run_from"] = gull["perch"] - dock_dir.normalized() * 8.0
			gull["mode"] = SB.PERCH
			gull["perch_ship"] = false
			gull["spot"] = -1
			gull["t"] = 600.0
			gull["pos"] = gull["perch"]
			put(saw["run_from"] + Vector3.UP * 0.3)
			saw["scattered"] = sky.scattered
			saw["run"] = 0
			until = TK.wait_secs(1.0)
			step += 1
		2:
			check("a gull sat on the dock stays put while you stand 8 m off", gull["mode"] == SB.PERCH)
			saw["y"] = float(gull["pos"].y)
			step += 1
		3:
			# running at it: 9 m/s along the dock
			var to: Vector3 = gull["perch"] - p.global_position
			to.y = 0.0
			if to.length() > 1.0 and int(saw["run"]) < 120:
				saw["run"] = int(saw["run"]) + 1
				p.global_position += to.normalized() * minf(9.0 * d, to.length())
				p.velocity = Vector3.ZERO
				return false
			until = TK.wait_secs(1.5)
			step += 1
		4:
			check("...and goes up when you run at it", sky.scattered > int(saw["scattered"]) and float(gull["pos"].y) > float(saw["y"]) + 2.0)
			set_hour(0.5)
			until = TK.wait_secs(16.0)
			step += 1
		5:
			print("   midnight: day %.2f, %d drawn" % [sky.day, sky.shown()])
			check("none at night", sky.day == 0.0 and sky.shown() == 0)
			set_hour(12.0)
			until = TK.wait_secs(6.0)
			step += 1
		6:
			print("   noon again: %d drawn" % sky.shown())
			check("back in the morning", sky.shown() >= 8)
			# the ship near land: gulls come out to her
			var sea := sea_at(380.0)
			check("found sea near Brinehollow", sea != Vector3.INF)
			ship.place(sea, 0.0)
			ship.set_anchored(false)
			until = TK.wait_ticks(20)
			step += 1
		7:
			board()
			until = TK.wait_secs(22.0)
			step += 1
		8:
			var near: Array = mine("ship").filter(func(b): return (b["pos"] as Vector3).distance_to(ship.global_position) < 45.0)
			print("   ship %.0f m off: %d gulls of hers, %d within 45 m (%s)" % [ship.global_position.distance_to(root.get_node("World/Islands/Brinehollow").global_position),
				mine("ship").size(), near.size(), str(mine("ship").map(func(b): return b["mode"]))])
			check("near land gulls come out to the ship", mine("ship").size() == SB.SHIP_GULLS and near.size() >= 2)
			check("...one trailing her", mine("ship").any(func(b): return b["mode"] == SB.TRAIL))
			# the ship at rest: no spray
			check("at rest: no bow wave, no spray (%.2f)" % sp.spray, not sp._bow[0].emitting and not sp._bow[1].emitting and sp.spray < 0.05)
			# far out at sea: everything freed
			var far := sea_at(1500.0)
			check("found open sea far out", far != Vector3.INF)
			ship.place(far, 0.0)
			until = TK.wait_ticks(20)
			step += 1
		9:
			board()
			until = TK.wait_secs(5.0)
			step += 1
		10:
			print("   far out: %d birds (%d of Brinehollow's), %d drawn" % [sky.birds.size(), mine("brinehollow").size(), sky.shown()])
			check("far out at sea the island's birds are freed", mine("brinehollow").is_empty())
			check("...and the ship's gulls go home", mine("ship").is_empty())
			# full sail into a storm
			weather(3)
			ship.sail = 1.0
			saw["on"] = 0
			saw["n"] = 0
			saw["rise"] = 0.0
			saw["slams"] = sp.slams
			saw["slaps"] = sp.slaps
			saw["spray"] = 0.0
			saw["t0"] = t
			step += 1
		11:
			if t - float(saw["t0"]) < 16.0:
				if ship.speed > 5.0:
					saw["n"] = int(saw["n"]) + 1
					if sp._bow[0].emitting or sp._bow[1].emitting:
						saw["on"] = int(saw["on"]) + 1
					saw["rise"] = maxf(float(saw["rise"]), sp.rise)
					saw["spray"] = maxf(float(saw["spray"]), sp.spray)
				return false
			var on := float(saw["on"]) / maxf(float(saw["n"]), 1.0)
			print("   storm, %.1f m/s: bow wave on %.0f%% of frames (v %.1f), stem rise up to %.1f m/s, %d slaps, %d sheets, spray up to %.2f, foam patches %d, hiss %.1f dB" % [ship.speed,
				on * 100.0, sp._bow[0].initial_velocity_max, float(saw["rise"]), sp.slaps - int(saw["slaps"]), sp.slams - int(saw["slams"]), float(saw["spray"]),
				amb.get_parent().get_node("SeaSpray")._foam.size(), amb._players["spray"].volume_db])
			check("under way the bow wave flies, faster with her speed", on > 0.4 and sp._bow[0].initial_velocity_max > 3.5)
			check("...every wave she meets slaps her hull", sp.slaps - int(saw["slaps"]) >= 3)
			check("...a steep one throws a sheet of spray over the bow", sp.slams - int(saw["slams"]) >= 1)
			check("...and in a blow spray streams across her deck (and hisses)", float(saw["spray"]) > 0.2 and amb._players["spray"].volume_db > -40.0)
			check("foam patches drift on the swell", amb.get_parent().get_node("SeaSpray")._foam.size() >= 10)
			cam = Camera3D.new()
			root.add_child(cam)
			cam.global_position = ship.global_position + Vector3(0, 30, 400)
			cam.current = true
			until = TK.wait_ticks(10)
			step += 1
		12:
			check("the ship's spray sleeps with the camera far", not sp.awake and not sp.visible and not sp._bow[0].emitting)
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit()
	return false
