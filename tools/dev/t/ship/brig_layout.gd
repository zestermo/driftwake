extends SceneTree
## (1.30) The brig (HullLayout._brig): taken out at the yard she's 1.5x the sloop's length on her own layout, two masts,
## five gun pairs down her waist, twice the sloop's hull, slower and slower to turn. Her decks are walkable: the main
## deck fore and aft of the masts, the quarterdeck up the stairs, in through the door and down the steps into the
## lounge, through the partition's doorway into the captain's cabin; the bunk, galley and chest answer F; you wake in
## the cabin. Back to the sloop, she's the sloop again (her guns, her masts).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var L
var SC
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			SC = load("res://scripts/ship/ship_classes.gd")
			var sloop = ship.layout
			root.get_node("Net").set_ship_kit(SC.switch_to(ship.kit, "brig"))
			L = ship.layout
			var len_k: float = (float(L.rings[0][0]) - float(L.rings[L.rings.size() - 1][0])) / (float(sloop.rings[0][0]) - float(sloop.rings[sloop.rings.size() - 1][0]))
			check("the brig: her own layout, 1.5x the sloop's length (x%.2f)" % len_k, L.cls == "brig" and absf(len_k - 1.5) < 0.01 and L.rooms)
			check("two masts: the main (with the nest) and a foremast, each its own rig", L.masts.size() == 1 and ship.get_node_or_null("ShipModel/Rig1") != null and ship.get_node_or_null("ShipModel/Rig") != null)
			var guns: Array = ship.cannons.filter(func(c): return c.name != "CannonBow")
			check("five gun pairs down her waist (%d guns)" % guns.size(), guns.size() == 10 and ship.side_cannons(1.0).size() == 5)
			check("twice the sloop's hull (%.0f)" % ship.max_hull, absf(ship.max_hull - 800.0) < 1.0)
			check("slower (%.1f m/s) and slower to turn (%.3f rad/s)" % [ship.MAX_SPEED * ship._top_k, ship.MAX_TURN * ship._turn_k], ship.MAX_SPEED * ship._top_k < 10.5 and ship.MAX_TURN * ship._turn_k < 0.45)
			put(Vector3(0, L.deck_y + 0.1, L.mast_z - 4.0), 0.0)
			until = TK.wait_ticks(20)
		1:
			check("on her main deck between the masts (y %.2f)" % local().y, standing(L.deck_y))
			put(Vector3(1.5, L.deck_y + 0.1, float(L.rings[L.rings.size() - 1][0]) + 4.0), 0.0)
			until = TK.wait_ticks(20)
		2:
			check("on her foredeck (y %.2f)" % local().y, standing(L.deck_y))
			put(Vector3((L.stair_x0 + L.cabin_hw) * 0.5, L.deck_y + 0.1, L.stair_z0 - 0.6), PI)
			Input.action_press("move_forward")
			until = TK.wait_secs(1.6)
		3:
			Input.action_release("move_forward")
			until = TK.wait_ticks(20)
		4:
			check("up the stairs onto the quarterdeck (z %.1f, y %.2f)" % [local().z, local().y], standing(L.qd_y) and local().z > L.qd_front)
			put(Vector3(0, L.deck_y + 0.1, L.qd_front - 2.0), PI)
			Input.action_press("move_forward")
			until = TK.wait_secs(0.75)
		5:
			Input.action_release("move_forward")
			until = TK.wait_ticks(20)
		6:
			check("in through the door and down into the lounge (z %.1f, y %.2f)" % [local().z, local().y], L.in_cabin(local()) and standing(L.cabin_y))
			Input.action_press("move_forward")
			until = TK.wait_secs(0.9)
		7:
			Input.action_release("move_forward")
			until = TK.wait_ticks(20)
		8:
			var pz: float = load("res://scripts/ship/ship_rooms.gd").part_z(L)
			check("through the partition's doorway into the captain's cabin (z %.1f > %.1f)" % [local().z, pz], local().z > pz + 0.3 and L.in_cabin(local()) and standing(L.cabin_y))
			put(L.bed_at + Vector3(0.85, 0.1, 0.0), -PI * 0.5)
			until = TK.wait_ticks(12)
		9:
			check("by the bunk: F rests (%s)" % prompt(), prompt().to_lower().contains("bunk"))
			put(L.counter_at + Vector3(-0.85, 0.1, 0.3), PI * 0.5)
			until = TK.wait_ticks(12)
		10:
			check("by the galley: F cooks (%s)" % prompt(), prompt().to_lower().contains("galley"))
			put(L.storage_at + Vector3(0.6, 0.1, 0.7), PI)
			until = TK.wait_ticks(12)
		11:
			check("by the chest: F opens the storage (%s)" % prompt(), prompt().to_lower().contains("storage"))
			check("you wake in her cabin", L.in_cabin(ship.to_local(ship.respawn_point.global_position)))
			root.get_node("Net").set_ship_kit(SC.switch_to(ship.kit, "sloop"))
			until = TK.wait_ticks(4)
		12:
			check("back to the sloop: her layout, one mast, two gun pairs", ship.layout.cls == "sloop" and ship.get_node_or_null("ShipModel/Rig1") == null and ship.side_cannons(1.0).size() == 2)
			check("...and her hull (%.0f)" % ship.max_hull, absf(ship.max_hull - 400.0) < 1.0)
			return TK.done(fails)
	step += 1
	return false
