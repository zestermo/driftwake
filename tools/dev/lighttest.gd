extends SceneTree
## v1.12 light: readable nights (the ambient and the moon over a floor at 21:00 and
## 2:00, and in a storm, below the day's), the belt lantern (lit at night, out by day,
## the key flips it, its bit in the co-op snapshot, out in the water and back on
## climbing out, kept through a rebuilt body), the ship's lanterns
## (there, lit at night, dark by day; the pirates' too).
const TK := preload("res://tools/dev/test_kit.gd")

var step := 0
var until := 0
var fails := 0
var p
var w
var ship
var day := {}


func _initialize():
	TK.seed_of(self)
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func set_hour(h: float) -> void:
	w.skip_to(h)


func force(s: int) -> void:
	w.forced = s
	w.forced_at = w.world_time() - 100.0


func ship_lights() -> Array:
	return ship.ship_model.find_children("*", "NightLight", true, false)


func all_visible(lights: Array) -> bool:
	return lights.all(func(l): return (l as Node3D).visible)


func none_visible(lights: Array) -> bool:
	return lights.all(func(l): return not (l as Node3D).visible)


func _process(_d: float) -> bool:
	if TK.ticking(until):
		return false
	match step:
		0:
			until = TK.wait_secs(2.0)
			step = 1
		1:
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			p = get_first_node_in_group("player")
			w = root.get_node("Weather")
			ship = get_first_node_in_group("ship")
			force(0)
			set_hour(12.0)
			# (lamps look at the hour once a second)
			until = TK.wait_secs(1.5)
			step = 2
		2:
			day = {"amb": w.ambient_level(), "sky": w.sky_light_level()}
			print("   noon: ambient %.3f, sun %.3f" % [day["amb"], day["sky"]])
			check("by day the belt lantern is out", not p.body_model.lantern.lit)
			check("...and its light is off", not p.body_model.lantern._light.visible)
			check("...and the co-op snapshot says so", int(p.net_pack()[8]) & p.NF_LANTERN == 0)
			check("the ship has its lanterns (%d lights)" % ship_lights().size(), ship_lights().size() >= 6)
			check("...dark by day", none_visible(ship_lights()))
			set_hour(21.0)
			until = TK.wait_secs(1.5)
			step = 3
		3:
			var amb: float = w.ambient_level()
			var sky: float = w.sky_light_level()
			print("   21:00: ambient %.3f, moon %.3f" % [amb, sky])
			check("21:00: the ambient is over the floor (%.3f >= %.3f)" % [amb, w.AMBIENT_FLOOR], amb >= w.AMBIENT_FLOOR - 0.001)
			check("...and below the day's", amb < float(day["amb"]) * 0.8)
			check("...the moon lights the ground (%.3f)" % sky, sky > 0.18)
			check("...less than the sun", sky < float(day["sky"]) * 0.5)
			check("...the ship's lanterns are lit", all_visible(ship_lights()))
			var es := get_nodes_in_group("enemy_ships")
			for e in es:
				var el: Array = (e as Node).find_children("*", "NightLight", true, false)
				check("...a pirate ship shows %d lit lanterns" % el.size(), el.size() >= 2 and all_visible(el))
			var isl: Node3D = current_scene.find_child("Brinehollow", true, false)
			var nls: Array = isl.find_children("*", "NightLight", true, false)
			check("Brinehollow's lamps within its budget (%d of %d)" % [nls.size(), isl.LIGHTS], nls.size() > 11 and nls.size() <= isl.LIGHTS)
			var den: Vector3 = isl.to_global(Vector3(isl.DEN.x, 0, isl.DEN.y))
			var den_lit := nls.filter(func(n): return Vector2(n.global_position.x - den.x, n.global_position.z - den.z).length() < 30.0 and n.visible)
			check("...the pirates' den has lit lanterns (%d)" % den_lit.size(), den_lit.size() >= 2)
			check("...the belt lantern lit itself", p.body_model.lantern.lit and p.body_model.lantern._light.visible)
			check("...in the co-op snapshot", int(p.net_pack()[8]) & p.NF_LANTERN != 0)
			check("...a warm light without shadows, 8-10 m", not p.body_model.lantern._light.shadow_enabled and p.body_model.lantern._light.omni_range >= 8.0 and p.body_model.lantern._light.omni_range <= 10.0)
			p.toggle_lantern()
			until = TK.wait_ticks(3)
			step = 4
		4:
			check("the lantern key puts it out at night", not p.body_model.lantern.lit)
			check("...and the snapshot follows", int(p.net_pack()[8]) & p.NF_LANTERN == 0)
			p.toggle_lantern()
			until = TK.wait_ticks(3)
			step = 5
		5:
			check("...and lights it again", p.body_model.lantern.lit)
			# into the water and out again (the swim state sets these on the body)
			p.body_model.swimming = true
			p._lantern_tick()
			check("swimming puts it out", not p.body_model.lantern.lit)
			p.toggle_lantern()
			p._lantern_tick()
			check("...and it can't be lit in the water", not p.body_model.lantern.lit)
			p.body_model.swimming = false
			p.body_model.diving = true
			p._lantern_tick()
			check("diving keeps it out", not p.body_model.lantern.lit)
			p.body_model.diving = false
			p._lantern_tick()
			check("climbing out at night lights it again", p.body_model.lantern.lit)
			# a rebuilt body (new gear, the creator) keeps it lit
			p.refresh_look()
			check("a rebuilt body still wears it, lit", is_instance_valid(p.body_model.lantern) and p.body_model.lantern.is_inside_tree() and p.body_model.lantern.lit)
			check("...hung from the torso", p.body_model.lantern.get_parent() == p.body_model.torso)
			set_hour(2.0)
			until = TK.wait_secs(1.5)
			step = 6
		6:
			var amb: float = w.ambient_level()
			print("   02:00: ambient %.3f, moon %.3f" % [amb, w.sky_light_level()])
			check("2:00: the ambient is over the floor", amb >= w.AMBIENT_FLOOR - 0.001)
			check("...and below the day's", amb < float(day["amb"]) * 0.8)
			check("...the moon still lights the ground", w.sky_light_level() > 0.18)
			check("...the lantern is still lit", p.body_model.lantern.lit)
			force(3)
			until = TK.wait_ticks(10)
			step = 7
		7:
			print("   02:00 storm: ambient %.3f" % w.ambient_level())
			check("a storm at night keeps the ambient over the floor", w.ambient_level() >= w.AMBIENT_FLOOR - 0.001)
			force(0)
			set_hour(7.0)
			until = TK.wait_secs(1.5)
			step = 8
		8:
			check("at dawn the lantern goes out", not p.body_model.lantern.lit)
			check("...and the ship's lanterns", none_visible(ship_lights()))
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
	return false
