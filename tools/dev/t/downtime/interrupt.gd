extends SceneTree
## Downtime aboard needs the ship looked after: under sail with nobody at the wheel, training is refused;
## lashed, it starts. Danger ends it: a sail coming up close rouses you with a word on why.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var DT
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true, "weapon": "cutlass"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			DT = load("res://scripts/game/downtime.gd")
			p.sheathe_weapon(true)
			p.global_position = ship.global_transform * Vector3(0, ship.DECK_Y + 0.3, 0.0)
			p.reset_physics_interpolation()
			ship.sail = 1.0 / 3.0
			ship.speed = 3.0
			until = TK.wait_ticks(10)
		1:
			check("aboard under sail, nobody at the wheel: training refused (%s)" % DT.refuse(p, "train"), DT.refuse(p, "train").begins_with("Lash the helm"))
			DT.start(p, "train")
			check("...and doesn't start", p.current_state_name() != "Downtime")
			root.get_node("/root/Net").lash_helm(true, ship._heading)
			DT.start(p, "train")
			until = TK.wait_ticks(10)
		2:
			check("lashed, it starts (%s)" % p.current_state_name(), p.current_state_name() == "Downtime")
			var es = load("res://scripts/ship/enemy_ship.gd").new().setup(ship.global_position + Vector3(70, 0, 40), 20.0, 0.0, 99, "brig")
			es.name = "Brig"
			es.position = ship.global_position + Vector3(70, 0, 40)
			stage.add_child(es)
			check("a sail close by is danger (%s)" % DT.danger(p), DT.danger(p).begins_with("Sail ho"))
			until = TK.wait_secs(0.7)
		3:
			check("...it rouses you from training (%s)" % p.current_state_name(), p.current_state_name() != "Downtime" and p.body_model.current_action() != "dt_train_blade")
			check("...and you can't start again while it's there", DT.refuse(p, "train").begins_with("Sail ho"))
			ship.sail = 0.0
			return TK.done(fails)
	step += 1
	return false
