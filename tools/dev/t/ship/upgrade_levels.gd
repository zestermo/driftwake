extends SceneTree
## Every level of every upgrade line changes how the sloop looks (more geometry, or a bigger sail) and does
## what it says: hull plating +8% hull a level (topped up), gun deck damage / reload / the third pair at 2 /
## brass bands, shields and long barrels on the guns, sails +3% speed, rudder +6% turning, the rudder turning
## with the helm and the jib furling with the sail.
const TK := preload("res://tools/dev/test_kit.gd")
var LINES
var stage
var ship
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## How she looks, as a number: every vertex on her and her rig's scale.
func look() -> float:
	var n := 0
	for mi in ship.ship_model.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null or not (mi as MeshInstance3D).is_visible_in_tree():
			continue
		for s in range(m.get_surface_count()):
			n += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n + ship.rig_scale.x * 1000.0


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			LINES = load("res://scripts/ship/ship_lines.gd")
			ship = stage.ship
			check("a plain sloop: nothing fitted, 400 hull, 4 guns", ship.parts.pieces("armour") + ship.parts.pieces("guns") + ship.parts.pieces("sails") + ship.parts.pieces("rudder") == 0
				and ship.max_hull == 400.0 and ship.cannons.size() == 4)
			for id in LINES.ORDER:
				var prev := look()
				var shows := true
				for lv in range(1, LINES.max_level(id) + 1):
					ship.apply_kit({id: lv})
					var now := look()
					if now <= prev or ship.parts.pieces(id) != lv:
						shows = false
						print("   %s %d: look %.0f -> %.0f, pieces %d" % [id, lv, prev, now, ship.parts.pieces(id)])
					prev = now
				check("every %s level shows on her (%d levels)" % [id, LINES.max_level(id)], shows)
				ship.apply_kit({})
			ship.apply_kit({"armour": 3})
			check("hull plating 3: +24%% hull, topped up (%.0f / %.0f)" % [ship.hull, ship.max_hull], is_equal_approx(ship.max_hull, 496.0) and is_equal_approx(ship.hull, 496.0))
			ship.apply_kit({"guns": 1})
			var gun = ship.cannons[0]
			check("gun deck 1: +5% damage, still two pairs", is_equal_approx(gun.hull_damage, 31.5) and ship.cannons.size() == 4)
			ship.apply_kit({"guns": 5})
			gun = ship.cannons[0]
			print("   guns 5: %.1f hull dmg, %.2f s reload, %.1f m/s, fitted %d" % [gun.hull_damage, gun.reload_time, gun.muzzle_speed, gun.fitted])
			check("gun deck 5: three pairs, +15% damage, 10% faster reload, longer reach", ship.cannons.size() == 6 and ship.side_cannons(-1.0).size() == 3
				and is_equal_approx(gun.hull_damage, 34.5) and is_equal_approx(gun.reload_time, 2.88) and gun.muzzle_speed > 46.0 * 1.03)
			check("...every gun banded, shielded and long", ship.cannons.all(func(c): return c.fitted == 5 and c.get_node_or_null("Yaw/Shield") != null))
			ship.apply_kit({"sails": 5, "rudder": 5})
			check("sails 5: +15%% speed (%.2f), the old larger sail" % ship._top_k, is_equal_approx(ship._top_k, 1.15) and is_equal_approx(ship.rig_scale.x, 1.18))
			check("rudder 5: +30%% turning (%.2f)" % ship._turn_k, is_equal_approx(ship._turn_k, 1.3))
			ship.rudder = 1.0
			until = TK.wait_ticks(3)
		1:
			check("the rudder swings with the helm", ship.parts.rudder_node.rotation.y > 0.3)
			ship.sail = 0.0
			ship.sail_shown = 0.0
			until = TK.wait_ticks(3)
		2:
			check("the jib comes down with the main sail", not ship.parts.jib.visible)
			ship.sail_shown = 1.0
			ship.sail = 1.0
			until = TK.wait_ticks(3)
		3:
			check("...and goes up with it", ship.parts.jib.visible and ship.parts.jib.scale.x > 0.95)
			return TK.done(fails)
	step += 1
	return false
