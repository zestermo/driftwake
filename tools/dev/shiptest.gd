extends SceneTree
## Ship: gentle swell, helm (visible captain), sails set in steps that stay set (furled canvas rolls down), turning, riding the deck, keeps sailing with nobody at the wheel, jumping on the moving deck, shore collision.
var t := 0.0
var step := 0
var wait := 0.0
var p
var ship
var fails := 0
var ys: Array = []
var pitches: Array = []
var h0 := 0.0
var maxdev := 0.0
var t0 := 0.0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
## The heading that puts the wind `rel` radians off the bow (0 = running before it, PI = head to wind).
func heading_for(rel: float) -> float:
	var wd: Vector2 = root.get_node("Weather").wind_dir()
	var f := wd.rotated(-rel)
	return atan2(-f.x, -f.y)
func act(a: String) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = true; Input.parse_input_event(e)
	var e2 := InputEventAction.new(); e2.action = a; e2.pressed = false; Input.parse_input_event(e2)
func _process(d: float) -> bool:
	t += d
	if step == 1 or step == 10:
		ys.append(ship.global_position.y)
		pitches.append(absf(ship.rotation.x) + absf(ship.rotation.z))
	if step == 6:
		var loc: Vector3 = ship.to_local(p.global_position)
		maxdev = maxf(maxdev, Vector2(loc.x - 0.0, loc.z - 1.0).length())
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			p = root.get_tree().get_first_node_in_group("player")
			ship = root.get_tree().get_first_node_in_group("ship")
			wait = 6.0
		1:
			var lo: float = ys.min(); var hi: float = ys.max()
			print("   moored heave range ", snappedf(hi - lo, 0.01), " max tilt ", snappedf(pitches.max(), 0.001))
			check("gentle heave at the dock (< 0.8 m)", hi - lo < 0.8)
			check("gentle tilt (< 0.1 rad)", pitches.max() < 0.1)
			var deck_y: float = ship.global_position.y + 0.32
			check("deck sits ~1.8 m above sea, level with the dock (%.2f)" % deck_y, deck_y > 1.4 and deck_y < 2.2)
			check("moored with the sail furled on the yard", ship.sail == 0.0 and ship._furl_node.visible and not ship._sail_node.visible)
			set_meta("dock", ship.global_position)
			# out to open water (clear of land, reefs and whirlpools), the wind on the beam
			var es0 = get_nodes_in_group("enemy_ships")[0]
			var wg = root.get_node("World/Islands")
			var sc: Vector2 = wg.starter_center
			for k in range(32):
				var a := k * TAU / 32.0
				var c := sc + Vector2(cos(a), sin(a)) * 380.0
				if wg._deep_enough(c, 120.0) and es0.huntable_at(Vector3(c.x, 0, c.y)):
					set_meta("sea", Vector3(c.x, 0, c.y))
					break
			ship.place(get_meta("sea"), heading_for(PI * 0.5))
			# (no pirates: this is about sailing)
			for s in get_nodes_in_group("enemy_ships"):
				s.queue_free()
			# board at the helm
			p.current_ship = ship
			p.state_machine.force_state("Helm", {})
			wait = 0.5
		2:
			check("helm state", p.current_state_name() == "Helm")
			check("captain visible at the wheel", p.player_model.visible and p.body_model.at_helm)
			var hl: Vector3 = ship.helm_position.global_position
			check("standing at the helm", p.global_position.distance_to(hl) < 0.2)
			h0 = ship.global_position.distance_to(Vector3.ZERO)
			set_meta("start", ship.global_position)
			Input.action_press("move_forward")
			wait = 0.3
		3:
			print("   sail after a W press ", snappedf(ship.sail, 0.01))
			check("W lets out a third of sail (held, not more)", is_equal_approx(ship.sail, 1.0 / 3.0))
			ship.sail = 1.0
			wait = 5.0
		4:
			print("   speed after 5 s ", snappedf(ship.speed, 0.01), " canvas ", snappedf(ship._sail_node.scale.y, 0.01))
			check("sails build speed", ship.speed > 8.0)
			check("the canvas is let down", ship._sail_node.scale.y > 0.95 and not ship._furl_node.visible)
			var moved: float = (ship.global_position - (get_meta("start") as Vector3)).length()
			print("   moved ", snappedf(moved, 0.1), " m")
			check("ship moves forward", moved > 20.0)
			check("still at the helm while sailing", p.global_position.distance_to(ship.helm_position.global_position) < 0.3)
			set_meta("yaw", ship.global_rotation.y)
			Input.action_press("move_right")
			wait = 2.0
		5:
			var dy: float = wrapf(ship.global_rotation.y - float(get_meta("yaw")), -PI, PI)
			print("   turned ", snappedf(dy, 0.01), " rad, rudder ", snappedf(ship.rudder, 0.01))
			check("D turns to starboard (yaw decreases)", dy < -0.3)
			check("wheel turns", absf(ship.wheel.rotation.z) > 1.0)
			Input.action_release("move_right")
			# leave the wheel while under way and stand on the deck
			act("interact")
			wait = 0.2
		6:
			check("left the helm, on foot", p.current_state_name() != "Helm" and p.context == 0)
			p.global_position = ship.global_transform * Vector3(0, 0.5, 1.0)
			p.reset_physics_interpolation()
			maxdev = 0.0
			Input.action_release("move_forward")
			wait = 3.0
		7:
			print("   drift on deck while sailing: ", snappedf(maxdev, 0.01), " m, on floor ", p.is_on_floor(), " speed ", snappedf(ship.speed, 0.1))
			check("deck carries the player (no sliding off)", maxdev < 0.6 and p.is_on_floor())
			check("she keeps sailing with nobody at the wheel (sails stay set)", ship.sail == 1.0 and ship.speed > 8.0)
			check("the rudder comes back to centre", absf(ship.rudder) < 0.1)
			var loc: Vector3 = ship.to_local(p.global_position)
			check("feet on the visible deck (~0.32)", absf(loc.y - 0.32) < 0.15)
			print("   player local y ", snappedf(loc.y, 0.01))
			# jump straight up on the moving deck
			set_meta("jump_from", loc)
			act("jump")
			wait = 0.2
		8:
			check("in the air", not p.is_on_floor())
			wait = 1.3
		9:
			var loc: Vector3 = ship.to_local(p.global_position)
			var drift: float = Vector2(loc.x - (get_meta("jump_from") as Vector3).x, loc.z - (get_meta("jump_from") as Vector3).z).length()
			print("   jumped at speed ", snappedf(ship.speed, 0.1), ": landed ", snappedf(drift, 0.01), " m from where it took off (on floor ", p.is_on_floor(), ")")
			check("a jump on the moving deck comes down where it went up (< 0.3 m)", drift < 0.3 and p.is_on_floor())
			ys.clear(); pitches.clear()
			wait = 4.0
		10:
			print("   under way heave ", snappedf(ys.max() - ys.min(), 0.01))
			check("gentle while sailing too (< 0.9 m)", ys.max() - ys.min() < 0.9)
			# sail straight at the island and make sure we stop at the shore
			p.state_machine.force_state("Helm", {})
			var isl = root.get_node("World/Islands/Brinehollow")
			var c: Vector3 = isl.global_position
			var dock: Vector3 = get_meta("dock")
			var to: Vector3 = c - dock
			ship.place(dock, atan2(-to.x, -to.z))
			ship.sail = 1.0
			t0 = t
			step += 1
			return false
		11:
			if t - t0 > 40.0 or (t - t0 > 3.0 and ship.speed < 1.0):
				var isl = root.get_node("World/Islands/Brinehollow")
				var lp: Vector3 = isl.to_local(ship.global_position)
				var ground: float = isl.height_at(lp.x, lp.z)
				print("   stopped after ", snappedf(t - t0, 0.1), " s, ground under hull ", snappedf(ground, 0.1), " speed ", snappedf(ship.speed, 0.1))
				check("runs aground instead of sailing through the island", ground < 3.0 and ship.speed < 2.0)
				# --- the wind: head to wind, full sail, she won't go
				ship.place(get_meta("sea"), heading_for(PI))
				ship.sail = 1.0
				p.state_machine.force_state("Helm", {})
				# (re-taking the wheel left it a moment by Brinehollow's dock: the anchor went down)
				ship.set_anchored(false)
				wait = 6.0
				step = 12
			return false
		12:
			print("   head to wind: %.1f m/s, sail belly %.2f, wind effect %.2f" % [ship.speed, ship._sail_node.scale.z, ship.wind_effect()])
			check("head to wind she still sails at her own speed (the wind never holds her back)", ship.speed > 6.0 and is_equal_approx(ship.wind_effect(), 1.0))
			check("...the sail draws", ship._sail_node.scale.z >= 0.75)
			ship.place(get_meta("sea"), heading_for(PI * 0.5))
			ship.sail = 1.0
			wait = 7.0
			step = 13
			return false
		13:
			print("   beam reach: %.1f m/s, yard braced %.2f rad, effect %.2f, sail %.2f/%.2f, anchored %s, hull %.0f, at %s" % [ship.speed, ship._brace, ship.wind_effect(), ship.sail, ship.sail_shown, ship.anchored, ship.hull, ship.global_position])
			check("wind on the beam she flies (a reach)", ship.speed > 9.0)
			check("...a fair wind: faster than her own top speed", ship.wind_effect() > 1.05 and ship.speed > ship.MAX_SPEED * 0.85)
			check("...the yard braced round to the wind", absf(ship._brace) > 0.5)
			check("the sailing gauge shows at the helm", get_first_node_in_group("hud")._sail_gauge.visible)
			# --- the anchor: Space at the wheel
			act("jump")
			wait = 6.0
			step = 14
			return false
		14:
			print("   anchored: %s, %.2f m/s, anchor %.2f m down" % [ship.anchored, ship.speed, -ship._anchor.position.y + ship.ANCHOR_AT.y])
			check("Space lets go the anchor: she stops under full sail", ship.anchored and absf(ship.speed) < 0.6)
			check("...the anchor's gone down on its cable", ship._anchor.position.y < ship.ANCHOR_AT.y - 3.0)
			act("jump")
			wait = 3.0
			step = 15
			return false
		15:
			check("Space again weighs it: under way", not ship.anchored and ship.speed > 2.0)
			print("RESULT ", "OK" if fails == 0 else "%d FAILED" % fails)
			return true
	step += 1
	return false
