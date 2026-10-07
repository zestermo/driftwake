extends SceneTree
## Knocked down on a ship under way: the body keeps the ship's speed (a light
## knockdown stays aboard), the root (and camera) never falls behind the body,
## and thrown over the rail you come up in the sea where the body went - not
## back on deck.
var t := 0.0
var step := 0
var wait := 0.0
var p
var ship
var fails := 0
var max_gap := 0.0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func gap() -> float:
	var h: Vector3 = p.body_model.hips.global_position
	return Vector2(h.x - p.global_position.x, h.z - p.global_position.z).length()
func _process(d: float) -> bool:
	t += d
	if t > 60.0:
		check("timed out at step %d" % step, false)
		print("RESULT FAILED (%d)" % fails)
		quit()
		return true
	if p and p.current_state_name() == "Downed" and p.body_model.ragdoll != null:
		max_gap = maxf(max_gap, gap())
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 2.0: return false
			for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
			p = get_first_node_in_group("player")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			ship = get_first_node_in_group("ship")
			for s in get_nodes_in_group("enemy_ships"):
				s.queue_free()
			# out to open water, under full sail
			var wg = root.get_node("World/Islands")
			var sc: Vector2 = wg.starter_center
			for k in range(32):
				var a := k * TAU / 32.0
				var c := sc + Vector2(cos(a), sin(a)) * 380.0
				if wg._deep_enough(c, 120.0):
					ship.place(Vector3(c.x, 0, c.y), a)
					break
			ship.set_anchored(false)
			ship.sail = 1.0
			wait = 6.0
			step += 1
		1:
			check("under way (%.1f m/s)" % ship.speed, ship.speed > 6.0)
			p.global_position = ship.global_transform * Vector3(0, 0.6, 1.0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Idle", {})
			wait = 0.8
			step += 1
		2:
			# a light knockdown (an enemy's heavy) on the moving deck
			max_gap = 0.0
			p.knock_down(ship.global_basis.x * 2.0 + Vector3.UP * 2.0)
			wait = 2.5
			step += 1
		3:
			var hips: Vector3 = p.body_model.hips.global_position
			check("a light knockdown keeps the body aboard (moving with her)", ship.aboard(hips))
			check("...the root stays with the body (max gap %.2f m)" % max_gap, max_gap < 1.3)
			step += 1
			wait = 2.5
		4:
			check("...and gets up on deck", p.current_state_name() != "Downed" and ship.aboard(p.global_position))
			p.state_machine.force_state("Idle", {})
			p.global_position = ship.global_transform * Vector3(1.5, 0.6, 1.0)
			p.reset_physics_interpolation()
			wait = 0.6
			step += 1
		5:
			# a cannon-ball blast throws you over the rail
			max_gap = 0.0
			p.knock_down(ship.global_basis.x * 12.0 + Vector3.UP * 5.0)
			wait = 3.0
			step += 1
		6:
			var hips: Vector3 = p.body_model.hips.global_position
			print("   thrown: hips %s aboard %s, root aboard %s, state %s" % [hips, ship.aboard(hips), ship.aboard(p.global_position), p.current_state_name()])
			check("thrown over the rail the root follows the body overboard (max gap %.2f m)" % max_gap, max_gap < 2.5 and not ship.aboard(p.global_position))
			wait = 4.0
			step += 1
		7:
			check("...and comes up in the sea where it landed, not back on deck (%s)" % p.current_state_name(),
				not ship.aboard(p.global_position) and p.current_state_name() in ["Swim", "Downed"])
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit()
	return false
