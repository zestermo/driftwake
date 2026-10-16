extends SceneTree
## Music by place and time: the theme at the title, Brinehollow's square and harbour
## play the village theme and its wilds the island's, a chain island's village vs its
## wilds the same, the night arrangement at 22:00 (in step with the day one), a calm
## track left for a while resumes at the bar it was in, and out at sea aboard under
## sail the sea theme (its night one too).
const TK = preload("res://tools/dev/test_kit.gd")
var t := 0.0
var step := 0
var until := 0
var fails := 0
var p
var w
var wx
var ship
var isl
var m
var keep := {}


func _initialize():
	TK.seed_of(self)
	change_scene_to_file("res://scenes/ui/title_screen.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func finish() -> void:
	print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
	quit()


func wait(secs: float) -> void:
	until = TK.wait_secs(secs)
	step += 1


func set_hour(h: float) -> void:
	wx.skip_to(h)


func put(at: Vector3) -> void:
	p.state_machine.force_state("Idle", {})
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 300.0, at + Vector3.DOWN * 60.0, 1)
	q.exclude = [ship.get_rid()]
	var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	p.global_position = ((hit["position"] as Vector3) if not hit.is_empty() else at) + Vector3.UP * 0.2
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


## Brinehollow's village square (world).
func square() -> Vector3:
	var home = w.starter_island
	return home.to_global(Vector3(home.VILLAGE.x, 0, home.VILLAGE.y))


func pos() -> float:
	return m._active.get_playback_position()


func _process(d: float) -> bool:
	t += d
	if t > 240.0:
		check("timed out at step %d" % step, false)
		finish()
		return true
	if TK.ticking(until):
		return false
	match step:
		0:
			m = root.get_node("Music")
			wait(1.5)
		1:
			check("the title screen plays the theme (%s)" % m.current, m.current == "title")
			change_scene_to_file("res://scenes/world/world.tscn")
			wait(2.0)
		2:
			w = root.get_node_or_null("World/Islands")
			p = get_first_node_in_group("player")
			if w == null or p == null:
				return false
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			ship = get_first_node_in_group("ship")
			wx = root.get_node("Weather")
			wx.force(0)
			set_hour(11.0)
			put(square())
			wait(3.0)
		3:
			check("Brinehollow's square: the village theme (%s)" % m.current, m.current == "village")
			var home = w.starter_island
			var dp: Vector2 = home._dock_point(home.DOCK_LENGTH)
			put(home.to_global(Vector3(dp.x, home.DOCK_DECK_Y, dp.y)))
			wait(10.0)
		4:
			check("...and out at the end of its pier still the town (%s)" % m.current, m.current == "village")
			# (the lighthouse hill: no burrows or camps near it)
			var home = w.starter_island
			put(home.to_global(Vector3(home.HILL.x, 0, home.HILL.y)))
			wait(4.0)
		5:
			check("Brinehollow's wilds: the island theme (%s)" % m.current, m.current == "island")
			keep["left"] = float(m._left["village"][0])
			check("the village theme was playing a while before we left (%.1f s in)" % keep["left"], keep["left"] > 5.0)
			keep["day_pos"] = pos()
			keep["day_at"] = t
			set_hour(22.0)
			wait(1.5)
		6:
			check("22:00: the night arrangement (%s)" % m.current, m.current == "island_night")
			var expect: float = fmod(float(keep["day_pos"]) + t - float(keep["day_at"]), m._stream("island").get_length())
			print("   day at %.2f s, night now at %.2f s (in step: %.2f s)" % [keep["day_pos"], pos(), expect])
			check("...carried on from the same moment of the piece", absf(pos() - expect) < 1.0)
			set_hour(11.0)
			put(square())
			keep["back_at"] = t
			wait(4.0)
		7:
			check("back in the square by day: the village theme (%s)" % m.current, m.current == "village")
			var bar: float = m.bar_len("village")
			var floor_at: float = floorf(float(keep["left"]) / bar) * bar
			print("   left at %.2f s, bar %.2f s, now %.2f s, %.2f s since we came back" % [keep["left"], bar, pos(), t - float(keep["back_at"])])
			check("...resumed at the bar it was left in, not from the top", pos() >= floor_at - 0.2 and pos() < floor_at + t - float(keep["back_at"]) + 0.5)
			step += 1
		8:
			if not w.chain_ready():
				return false
			isl = w.chain_islands[int(w.chain().start_next[0])]
			var c: Vector2 = isl.village_plan["c"]
			put(isl.to_global(Vector3(c.x, 0, c.y)))
			wait(4.0)
		9:
			var town: String = load("res://scripts/island/kit/kit_style.gd").of(isl.theme)["music_town"]
			check("%s's village: its style's town track, %s (%s)" % [isl.name, town, m.current], m.current == town)
			var top: Vector2 = isl.sites["summit"]
			put(isl.to_global(Vector3(top.x, 0, top.y)))
			wait(4.0)
		10:
			var l: Vector3 = isl.to_local(p.global_position)
			print("   at %s on %s, %.0f m from its village's heart" % [str(l), isl.name, Vector2(l.x, l.z).distance_to(isl.village_plan["c"])])
			var wild: String = load("res://scripts/island/kit/kit_style.gd").of(isl.theme)["music"]
			check("%s's wilds: its style's track, %s (%s)" % [isl.name, wild, m.current], m.current == wild)
			var sea := Vector3.INF
			for k in range(32):
				var a := k * TAU / 32.0
				var c: Vector2 = w.starter_center + Vector2(cos(a), sin(a)) * 380.0
				var clear := true
				for es in get_nodes_in_group("enemy_ships"):
					if Vector2((es as Node3D).global_position.x, (es as Node3D).global_position.z).distance_to(c) < 400.0:
						clear = false
				if clear and w._deep_enough(c, 140.0):
					sea = Vector3(c.x, 0, c.y)
					break
			check("found open sea", sea != Vector3.INF)
			ship.place(sea, 0.0)
			ship.set_anchored(false)
			wait(0.3)
		11:
			p.state_machine.force_state("Idle", {})
			p.global_position = ship.global_transform * Vector3(0.0, HullBuilder.DECK_Y + 0.3, -2.0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			ship.sail = 1.0
			wait(8.0)
		12:
			for e in get_nodes_in_group("enemies"):
				if e.has_method("in_combat") and e.in_combat():
					print("   enemy in combat: %s %.0f m" % [e.get_path(), (e as Node3D).global_position.distance_to(p.global_position)])
			for s in get_nodes_in_group("enemy_ships"):
				if s.in_combat():
					print("   ship in combat: %s %.0f m" % [s.get_path(), (s as Node3D).global_position.distance_to(p.global_position)])
			check("aboard under sail out at sea: the sea theme (%s, %.1f m/s)" % [m.current, ship.speed], m.current == "sea")
			set_hour(22.0)
			wait(1.5)
		13:
			check("...and the sea at night (%s)" % m.current, m.current == "sea_night")
			finish()
	return false
