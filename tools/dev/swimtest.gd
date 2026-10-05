extends SceneTree
## Swimming: fall in, float, swim, stamina, dive, exhaustion, ladder, ledge, wade out.
var t := 0.0
var step := 0
var wait := 0.0
var p
var ship
var isl
var fails := 0
var st0 := 0.0
var hp0 := 0.0
var y0 := 0.0
var t0 := 0.0
var box: StaticBody3D
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func st() -> String: return p.current_state_name()
func head_above() -> float:
	return p.body_model.head.global_position.y - p.water_surface()
func tap(a: String) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = true; Input.parse_input_event(e)
	var e2 := InputEventAction.new(); e2.action = a; e2.pressed = false; Input.parse_input_event(e2)
func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			p = root.get_tree().get_first_node_in_group("player")
			ship = root.get_tree().get_first_node_in_group("ship")
			isl = root.get_node("World/Islands/Brinehollow")
			# drop into the sea off the starboard side
			p.global_position = ship.global_transform * Vector3(6.0, 3.0, 0.6)
			p.reset_physics_interpolation()
			wait = 2.0
		1:
			check("falls in -> Swim", st() == "Swim")
			print("   head above water ", snappedf(head_above(), 0.01))
			check("head above the water", head_above() > -0.05 and head_above() < 0.8)
			check("not standing on the seabed", not p.is_on_floor())
			st0 = p.stamina
			for n in root.get_node("World").get_children():
				if n.has_method("shake"): n.rotation.y = ship.global_rotation.y
			Input.action_press("move_right")
			t0 = t
			wait = 2.0
		2:
			var v: Vector3 = p.velocity
			print("   swim speed ", snappedf(Vector2(v.x, v.z).length(), 0.01), " stamina ", snappedf(st0, 0.1), " -> ", snappedf(p.stamina, 0.1))
			check("swims (~3 m/s)", Vector2(v.x, v.z).length() > 2.5 and Vector2(v.x, v.z).length() < 3.6)
			check("swimming drains stamina", p.stamina < st0 - 3.0)
			check("head still above water while swimming", head_above() > -0.05)
			Input.action_release("move_right")
			st0 = p.stamina
			wait = 3.0
		3:
			print("   treading: stamina ", snappedf(st0, 0.1), " -> ", snappedf(p.stamina, 0.1))
			check("treading water recovers slowly", p.stamina > st0 and p.stamina < st0 + 25.0)
			# (measured against the waves, which rise and fall ~1 m)
			y0 = p.water_depth()
			Input.action_press("dodge")
			wait = 1.0
		4:
			print("   dive depth ", snappedf(p.water_depth() - y0, 0.01))
			check("Ctrl ducks under", p.water_depth() > y0 + 0.8 and head_above() < 0.0)
			Input.action_release("dodge")
			wait = 1.5
		5:
			check("bobs back up", head_above() > -0.05)
			p.stamina = 0.0
			hp0 = p.health_component.current_health
			wait = 2.2
		6:
			print("   exhausted hp ", hp0, " -> ", p.health_component.current_health)
			check("exhausted: losing health", p.health_component.current_health < hp0)
			p.stamina = 100.0
			p.health_component.current_health = p.health_component.max_health
			# swim to the starboard ladder and climb
			var lad = ship.get_node("ShipModel/LadderStarboard")
			p.global_position = lad.global_transform * Vector3(0, -1.6, 0.6)
			p.reset_physics_interpolation()
			wait = 0.6
		7:
			check("still swimming by the ladder", st() == "Swim")
			tap("jump")
			wait = 0.2
		8:
			check("Space at the ladder -> Climb", st() == "Climb")
			t0 = t
			step += 1
			return false
		9:
			if st() != "Climb" or t - t0 > 6.0:
				var loc: Vector3 = ship.to_local(p.global_position)
				print("   climbed in ", snappedf(t - t0, 0.01), " s, deck local ", loc)
				check("climbed aboard (on deck)", st() == "Idle" and absf(loc.x) < 2.6 and absf(loc.y - 0.32) < 0.3)
				wait = 0.5
				step += 1
			return false
		10:
			check("standing on deck afterwards", p.is_on_floor() and st() in ["Idle", "Move"])
			# a low ledge: a crate-like block in open water, top 0.8 above the waves
			var spot: Vector3 = ship.global_transform * Vector3(-14.0, 0, -6.0)
			box = StaticBody3D.new()
			var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(3, 6, 3); cs.shape = bs
			box.add_child(cs)
			root.get_tree().current_scene.add_child(box)
			box.global_position = Vector3(spot.x, p.water_surface(spot) + 0.8 - 3.0, spot.z)
			p.global_position = Vector3(spot.x + 2.2, 0.5, spot.z)
			p.reset_physics_interpolation()
			wait = 1.5
		11:
			check("in the water by the block", st() == "Swim")
			p.player_model.rotation.y = PI * 0.5  # face -X (toward the block)
			var bp: Vector3 = box.global_position
			box.global_position = Vector3(bp.x, p.water_surface(Vector3(bp.x + 1.4, 0, bp.z)) + 0.8 - 3.0, bp.z)
			print("   dist to block edge ", snappedf(p.global_position.x - (bp.x + 1.5), 0.01))
			tap("jump")
			wait = 0.15
		12:
			check("Space at a low ledge -> Climb (mantle)", st() == "Climb")
			wait = 1.2
		13:
			print("   after mantle y ", snappedf(p.global_position.y, 0.01), " state ", st())
			var top_y: float = box.global_position.y + 3.0
			print("   block top ", snappedf(top_y, 0.01))
			check("pulled up onto the ledge", absf(p.global_position.y - top_y) < 0.15 and st() in ["Idle", "Fall", "Move"])
			box.queue_free()
			# walk out at a beach: find shallow sea near the island
			var found := Vector3.INF
			for a in range(0, 360, 10):
				for r in range(60, 260, 4):
					var lx := cos(deg_to_rad(a)) * r; var lz := sin(deg_to_rad(a)) * r
					var h: float = isl.height_at(lx, lz)
					# deep enough to swim even in a wave trough (swell ~1.1 m)
					if h < -2.5 and h > -2.9:
						found = isl.to_global(Vector3(lx, h, lz)); break
				if found != Vector3.INF: break
			set_meta("beach", found)
			p.global_position = found + Vector3(0, 1.5, 0)
			p.reset_physics_interpolation()
			wait = 1.0
		14:
			check("swimming over chest-deep water", st() == "Swim")
			# swim toward the island center (shore)
			var c: Vector3 = isl.global_position
			var dirv: Vector3 = (c - p.global_position); dirv.y = 0
			p.player_model.rotation.y = atan2(-dirv.x, -dirv.z)
			# point the camera that way and push forward
			for n in root.get_node("World").get_children():
				if n.has_method("shake"): n.rotation.y = atan2(-dirv.x, -dirv.z)
			Input.action_press("move_forward")
			t0 = t
			step += 1
			return false
		15:
			if st() != "Swim" or t - t0 > 15.0:
				print("   left the water after ", snappedf(t - t0, 0.1), " s, depth ", snappedf(p.water_depth(), 0.01), " wade ", snappedf(p.wade_mult(), 0.01))
				check("walks out onto the beach", st() in ["Move", "Idle"])
				Input.action_release("move_forward")
				print("RESULT ", "OK" if fails == 0 else "%d FAILED" % fails)
				return true
			return false
	step += 1
	return false
