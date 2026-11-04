extends SceneTree
## (1.30) The brig's and galleon's broadside from the helm: with the sails set and a captain standing amidships, she
## sails on and the captain rides her (still aboard, still on her deck); the helmsman's broadside fires every gun on
## that side, the galleon's gun deck below too (5 and 10 a side), the balls clearing her own hull (no hull lost).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var SC
var step := 0
var until := 0
var fails := 0
var cls := "brig"
var start := Vector3.ZERO
var balls := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func local() -> Vector3:
	return ship.to_local(p.global_position)


func _on_ball(n: Node) -> void:
	var s: Script = n.get_script()
	if s and s.resource_path.ends_with("cannonball.gd"):
		balls += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			SC = load("res://scripts/ship/ship_classes.gd")
			if not node_added.is_connected(_on_ball):
				node_added.connect(_on_ball)
			root.get_node("Net").set_ship_kit(SC.switch_to(ship.kit, cls))
			var L = ship.layout
			p.state_machine.force_state("Idle", {})
			p.global_position = ship.global_transform * Vector3(-1.5, L.deck_y + 0.1, L.mast_z - 3.0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(15)
		1:
			ship.sail = 1.0
			start = ship.global_position
			until = TK.wait_secs(5.0)
		2:
			var L = ship.layout
			var moved: float = ship.global_position.distance_to(start)
			check("%s: under sail she makes way (%.1f m)" % [cls, moved], moved > 8.0)
			check("...and the captain rides her on deck (y %.2f, z %.1f)" % [local().y, local().z], ship.aboard(p.global_position) and absf(local().y - L.deck_y) < 0.2 and p.is_on_floor())
			ship.sail = 0.0
			balls = 0
			var hull: float = ship.hull
			ship.set_meta("hull0", hull)
			var target: Vector3 = ship.global_transform * Vector3(70.0, 0.0, 0.0)
			var n: int = ship.broadside(1.0, target, p)
			var want := 5 if cls == "brig" else 10
			check("the broadside fires every gun on her starboard side (%d of %d)" % [n, want], n == want)
			until = TK.wait_secs(3.0)
		3:
			check("...every ball away (%d)" % balls, balls >= (5 if cls == "brig" else 10))
			check("...none into her own hull (%.0f -> %.0f)" % [float(ship.get_meta("hull0")), ship.hull], ship.hull >= float(ship.get_meta("hull0")) - 0.01)
			if cls == "brig":
				cls = "galleon"
				step = 0
				return false
			return TK.done(fails)
	step += 1
	return false
