extends SceneTree
## (1.30) The galleon (HullLayout._galleon): 2.2x the sloop's length, three masts, two gun decks (five pairs on the main
## deck, five below), three times the sloop's hull, slow to turn. Down the hatch's stair you stand on the gun deck, and
## a gun there answers F; up the stairs onto the quarterdeck and on up onto the poop; in at the stateroom's door under
## the poop; in at the cabin door onto the lounge's floor, through the partition into the bunk room; the bunk, galley
## and chest answer F there.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var L
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


func local() -> Vector3:
	return ship.to_local(p.global_position)


func put(v: Vector3, yaw: float) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = ship.global_transform * v
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	stage.camera_rig.global_rotation.y = ship.global_rotation.y + yaw
	p.player_model.global_rotation.y = ship.global_rotation.y + yaw


func prompt() -> String:
	var ic = p.interaction_component
	return ic.current_interactable.prompt_text if ic.current_interactable else ""


func standing(y: float) -> bool:
	return absf(local().y - y) < 0.15 and p.is_on_floor() and ship.aboard(p.global_position)


func walk(secs: float) -> void:
	Input.action_press("move_forward")
	until = TK.wait_secs(secs)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			var SC = load("res://scripts/ship/ship_classes.gd")
			var sloop = ship.layout
			root.get_node("Net").set_ship_kit(SC.switch_to(ship.kit, "galleon"))
			L = ship.layout
			var len_k: float = (float(L.rings[0][0]) - float(L.rings[L.rings.size() - 1][0])) / (float(sloop.rings[0][0]) - float(sloop.rings[sloop.rings.size() - 1][0]))
			check("the galleon: her own layout, 2.2x the sloop's length (x%.2f)" % len_k, L.cls == "galleon" and absf(len_k - 2.2) < 0.01 and L.has_lower() and L.has_poop())
			check("three masts, each its own rig", L.masts.size() == 2 and ship.get_node_or_null("ShipModel/Rig1") != null and ship.get_node_or_null("ShipModel/Rig2") != null)
			var below: Array = ship.side_cannons(1.0).filter(func(c): return absf(c.position.y - L.lower_y) < 0.01)
			check("ten guns a side, five of them on the gun deck below (%d, %d)" % [ship.side_cannons(1.0).size(), below.size()], ship.side_cannons(1.0).size() == 10 and below.size() == 5)
			check("three times the sloop's hull (%.0f), a bow chaser" % ship.max_hull, absf(ship.max_hull - 1200.0) < 1.0 and ship.get_node_or_null("ShipModel/CannonBow") != null)
			check("slow (%.1f m/s), slow to turn (%.3f rad/s)" % [ship.MAX_SPEED * ship._top_k, ship.MAX_TURN * ship._turn_k], ship.MAX_SPEED * ship._top_k < 9.5 and ship.MAX_TURN * ship._turn_k < 0.3)
			put(Vector3(0, L.deck_y + 0.1, float(L.hatch[0]) - 1.5), PI)
			walk(1.3)
		1:
			Input.action_release("move_forward")
			until = TK.wait_ticks(25)
		2:
			check("down the hatch's stair onto the gun deck (z %.1f, y %.2f)" % [local().z, local().y], L.in_hold(local()) and standing(L.lower_y))
			var g = ship.side_cannons(1.0).filter(func(c): return absf(c.position.y - L.lower_y) < 0.01)[1]
			p.state_machine.force_state("Idle", {})
			p.global_position = g.global_transform * Vector3(0, 0.1, 1.1)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(15)
		3:
			check("by a gun below: F mans it (%s)" % prompt(), prompt().to_lower().contains("cannon"))
			check("...standing on the gun deck (y %.2f)" % local().y, standing(L.lower_y))
			put(Vector3((L.stair_x0 + L.cabin_hw) * 0.5, L.qd_y + 0.1, L.poop_front - 4.6), PI)
			walk(1.3)
		4:
			Input.action_release("move_forward")
			until = TK.wait_ticks(25)
		5:
			check("up the stairs from the quarterdeck onto the poop (z %.1f, y %.2f)" % [local().z, local().y], standing(L.poop_y) and local().z > L.poop_front)
			put(Vector3(0, L.qd_y + 0.1, L.poop_front - 1.5), PI)
			walk(0.6)
		6:
			Input.action_release("move_forward")
			until = TK.wait_ticks(20)
		7:
			check("in at the stateroom's door under the poop (z %.1f, y %.2f)" % [local().z, local().y], local().z > L.poop_front + 0.3 and L.in_cabin(local()) and standing(L.qd_y))
			put(Vector3(0, L.deck_y + 0.1, L.qd_front - 2.0), PI)
			walk(0.8)
		8:
			Input.action_release("move_forward")
			until = TK.wait_ticks(20)
		9:
			check("in at the cabin door, on the lounge's floor (z %.1f, y %.2f)" % [local().z, local().y], L.in_cabin(local()) and standing(L.cabin_y))
			walk(1.1)
		10:
			Input.action_release("move_forward")
			until = TK.wait_ticks(20)
		11:
			var pz: float = load("res://scripts/ship/ship_rooms.gd").part_z(L)
			check("through the partition into the bunk room (z %.1f > %.1f)" % [local().z, pz], local().z > pz + 0.3 and L.in_cabin(local()) and standing(L.cabin_y))
			put(L.bed_at + Vector3(0.85, 0.1, 0.0), -PI * 0.5)
			until = TK.wait_ticks(12)
		12:
			check("by the bunk: F rests (%s)" % prompt(), prompt().to_lower().contains("bunk"))
			put(L.counter_at + Vector3(-0.85, 0.1, 0.3), PI * 0.5)
			until = TK.wait_ticks(12)
		13:
			check("by the galley: F cooks (%s)" % prompt(), prompt().to_lower().contains("galley"))
			put(L.storage_at + Vector3(0.6, 0.1, 0.7), PI)
			until = TK.wait_ticks(12)
		14:
			check("by the chest: F opens the storage (%s)" % prompt(), prompt().to_lower().contains("storage"))
			return TK.done(fails)
	step += 1
	return false
