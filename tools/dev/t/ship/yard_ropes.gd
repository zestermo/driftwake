extends SceneTree
## The sloop has no swing ropes until the captain buys them at Tackett's yard (one level, paid in gold and
## timber, any captain, saved with her kit); then there's one at each end of the yard. A full swing from
## the deck passes well over the guns, and in the air the rope's prompt beats a cannon's right beside it
## (on the ground the nearer one, the cannon, still wins).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var rope
var cannon
var step := 0
var until := 0
var fails := 0
var low := INF
var far_z := 0.0
var swinging := false
var held := 0
var HB
var CAN


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func wanted():
	return p.interaction_component.current_interactable


func _physics_process(_d: float) -> bool:
	if swinging and p.current_state_name() == "Swing":
		var l: Vector3 = ship.to_local(p.global_position)
		held += 1
		far_z = minf(far_z, l.z)
		# (the grab hauls you up to the rope's length in the first 0.2 s: the arc proper starts after)
		if held > 18:
			low = minf(low, l.y)
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			HB = load("res://scripts/ship/hull_builder.gd")
			CAN = load("res://scripts/ship/cannon.gd")
			var ShipKitC = load("res://scripts/ship/ship_kit.gd")
			check("a ship from an old save has no ropes (a save with every other refit bought)", int(ShipKitC.merged({"armour": true, "guns": true, "sails": true, "rudder": true})["ropes"]) == 0)
			check("a plain sloop has no ropes to swing on", ship._rig.get_node_or_null("RopeS") == null and ship._rig.get_node_or_null("RopeP") == null)
			var inv = p.inventory_component
			var gold = load("res://resources/items/gold.tres")
			inv.remove_item(gold, inv.count("gold"))
			inv.add_item(gold, 500)
			inv.add_item(load("res://resources/items/timber.tres"), 2)
			var menu = root.get_node("GameMenu")
			menu.open("yard")
			menu._yard.order("ropes", 0)
			menu.close()
			check("bought at the yard: 90 gold and 2 timber (%d gold)" % inv.count("gold"), int(ship.kit["ropes"]) == 1 and inv.count("gold") == 410 and inv.count("timber") == 0)
			rope = ship._rig.get_node_or_null("RopeS")
			check("...a rope at each end of the yard", rope != null and ship._rig.get_node_or_null("RopeP") != null)
			check("...kept with her kit for the save", int(ship.kit["ropes"]) == 1 and int(root.get_node("GameManager").ship_kit["ropes"]) == 1)
			ship.apply_kit(ship.kit.merged({"armour": 1}, true))
			check("...another refit leaves them hanging", ship._rig.get_node_or_null("RopeS") == rope)
			# standing under the starboard rope on the deck, looking forward over the guns
			var at: Vector3 = ship.to_local(rope.interactable.global_position)
			p.state_machine.force_state("Fall", {})
			p.global_position = ship.to_global(Vector3(at.x, HB.DECK_Y + 0.9, at.z))
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			stage.camera_rig.global_rotation.y = ship.global_rotation.y
			until = TK.wait_ticks(2)
		1:
			check("jumping by the rope (and the second gun), F grabs it (%s, %s)" % [p.current_state_name(), wanted().prompt_text if wanted() else "nothing"],
				p.current_state_name() == "Fall" and wanted() == rope.interactable)
			swinging = true
			TK.act("interact")
			until = TK.wait_secs(3.0)
		2:
			swinging = false
			var guns: float = HB.DECK_Y + CAN.PIVOT_Y + CAN.BARREL * sin(CAN.PITCH_MAX) + 0.2
			print("   rope %.2f m, feet low point %.2f (guns' tops %.2f, deck %.2f), swung to z %.1f (second gun at %.1f)" % [rope.length, low, guns, HB.DECK_Y, far_z, ship.GUN_SPOTS[1][0]])
			check("it swings you out over the guns", far_z < float(ship.GUN_SPOTS[1][0]) - 0.5)
			check("...the arc's low point clears the guns' tops by 0.4 m", low > guns + 0.4)
			p.state_machine.force_state("Idle", {})
			cannon = ship.get_node("ShipModel/CannonS0")
			var seat: Vector3 = cannon.interactable.global_position
			# the rope's knot hung so its grab spot is by the gun's seat, a little higher
			rope.global_position = seat + Vector3(0.3, 0.9 + rope.length + 1.95, 0.0)
			p.global_position = seat - Vector3(0, 0.6, 0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.5)
		3:
			check("on the ground the gun beside you is the prompt (%s)" % (wanted().prompt_text if wanted() else "nothing"), wanted() == cannon.interactable)
			p.state_machine.force_state("Fall", {})
			p.global_position += Vector3(0, 0.9, 0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			until = TK.wait_ticks(2)
		4:
			check("...in the air the rope is (%s, %s)" % [p.current_state_name(), wanted().prompt_text if wanted() else "nothing"],
				p.current_state_name() == "Fall" and wanted() == rope.interactable)
			p.state_machine.force_state("Idle", {})
			var made_fast: Vector3 = ship.to_local(rope.global_position)
			rope.global_position = ship.to_global(Vector3(made_fast.x, made_fast.y, 1.5))
			var under: Vector3 = ship.to_local(rope.interactable.global_position)
			p.global_position = ship.to_global(Vector3(under.x, HB.DECK_Y + 0.05, under.z))
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.5)
		5:
			check("standing under a rope with no gun near, F grabs it (%s, %s)" % [p.current_state_name(), wanted().prompt_text if wanted() else "nothing"],
				p.current_state_name() in ["Idle", "Move"] and wanted() == rope.interactable)
			TK.act("interact")
			until = TK.wait_secs(0.3)
		6:
			check("...and you swing on it (%s)" % p.current_state_name(), p.current_state_name() == "Swing")
			return TK.done(fails)
	step += 1
	return false
