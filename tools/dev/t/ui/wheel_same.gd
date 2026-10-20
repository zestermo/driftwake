extends SceneTree
## The action wheel (N) is one list ashore and aboard: what can't be done where you are is greyed with the
## reason (Make camp aboard, Cook away from a galley or fire, Fish away from the water, Sleep away from a bunk
## or camp). At the water's edge Fish can be done. Aboard a ship under way with nobody at the wheel, Train
## starts and keeps going (no lashing needed); Read needs her looked after until the helm is lashed.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var AW
var ashore: Array = []
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "water": true, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func put(at: Vector3, yaw: float) -> void:
	p.global_position = at
	p.player_model.rotation.y = yaw
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			AW = load("res://scripts/game/action_wheel.gd")
			until = TK.wait_ticks(5)
		1:
			ashore = AW.entries_for(p)
			print("   ashore: %s" % str(ashore))
			check("ashore the list has camp, train, cook, read, tinker, fish, cut bait, sleep", ashore == ["camp", "train", "cook", "read", "tinker", "fish", "cut_bait", "sleep"])
			check("...Make camp and Train can be done", AW.why_not("camp", p) == "" and AW.why_not("train", p) == "")
			check("...Cook: at a galley or campfire", AW.why_not("cook", p) == "At a galley or campfire")
			check("...Read: aboard or at camp", AW.why_not("read", p) == "Aboard or at camp")
			check("...Fish: at the water's edge (%s)" % AW.why_not("fish", p), AW.why_not("fish", p) == "At the water's edge")
			check("...Sleep: in a bunk or at camp", AW.why_not("sleep", p) == "In a bunk or at camp")
			put(Vector3(stage.SHORE_X - 1.5, stage.GROUND_Y + 0.1, 0.0), -PI * 0.5)
			until = TK.wait_ticks(6)
		2:
			check("at the water's edge, facing the sea: Fish can be done (%s)" % AW.why_not("fish", p), AW.why_not("fish", p) == "")
			ship.sail = 1.0 / 3.0
			ship.speed = 3.0
			put(ship.global_transform * Vector3(0, ship.DECK_Y + 0.3, 0.0), ship.global_rotation.y)
			until = TK.wait_ticks(10)
		3:
			check("aboard (%s): the same list (%s)" % [AW.place(p), str(AW.entries_for(p))], AW.place(p) == "ship" and AW.entries_for(p) == ashore)
			check("...Make camp greyed: ashore, out of town", AW.why_not("camp", p) == "Ashore, out of town")
			check("...under way with nobody at the wheel, Read waits for the lashing (%s)" % AW.why_not("read", p), AW.why_not("read", p) == "Lash the helm or drop anchor first")
			check("...Cook can be done aboard", AW.why_not("cook", p) == "")
			check("...Train can be done, no lashing needed (%s)" % AW.why_not("train", p), AW.why_not("train", p) == "" and not ship.lashed)
			AW.run("train", p)
			until = TK.wait_secs(2.0)
		4:
			check("training aboard under way, unlashed: still at it (%s, %s)" % [p.current_state_name(), p.body_model.current_action()],
				p.current_state_name() == "Downtime" and p.body_model.current_action().begins_with("dt_train") and ship.speed > 1.0)
			root.get_node("/root/Net").lash_helm(true, ship._heading)
			until = TK.wait_ticks(3)
		5:
			check("the helm lashed: Read can be done", AW.why_not("read", p) == "")
			ship.sail = 0.0
			return TK.done(fails)
	step += 1
	return false
