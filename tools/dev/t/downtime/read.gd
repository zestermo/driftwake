extends SceneTree
## Reading aboard (anchored): sat on the deck with a book open, each interval earns experience, every few a
## piece of sea lore, and enough of it turns up a recipe (the Captain's Feast); the reading is saved.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var ship
var DT
var xp0 := 0
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


func state():
	return p.state_machine.current_state


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			ship = stage.ship
			DT = load("res://scripts/game/downtime.gd")
			ship.set_anchored(true)
			p.global_position = ship.global_transform * Vector3(0, ship.DECK_Y + 0.3, 0.0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		1:
			var ids: Array = load("res://scripts/game/action_wheel.gd").entries_for(p)
			check("aboard the wheel offers Read, Tinker, Fish and Sleep (%s)" % str(ids), ids.has("read") and ids.has("tinker") and ids.has("fish") and ids.has("sleep"))
			xp0 = pr.xp
			DT.start(p, "read")
			until = TK.wait_ticks(20)
		2:
			check("reading: sat on the deck, a book in hand (%s)" % p.body_model.current_action(), p.current_state_name() == "Downtime" and p.body_model.seated \
				and p.body_model.current_action() == "clip_read" and p.body_model.get_node_or_null("DowntimeProps") != null)
			state()._earned = DT.every(p, "read") - 0.1
			until = TK.wait_secs(0.3)
		3:
			check("an interval of reading: +XP (%d)" % (pr.xp - xp0), pr.xp > xp0)
			check("...counted", int(pr.downtime.get("read_n", 0)) == 1)
			pr.downtime["read_n"] = DT.RECIPE_AT - 1
			state()._earned = DT.every(p, "read") - 0.1
			until = TK.wait_secs(0.3)
		4:
			check("enough reading turns up the Captain's Feast", pr.recipes.has("captains_feast"))
			var d: Dictionary = pr.to_dict()
			pr.from_dict({})
			pr.from_dict(d)
			check("...the reading is saved with the captain", int(pr.downtime.get("read_n", 0)) == DT.RECIPE_AT)
			TK.press("move_back")
			until = TK.wait_ticks(4)
		5:
			TK.release("move_back")
			check("moving gets you up, the book away", p.current_state_name() != "Downtime" and not p.body_model.seated)
			until = TK.wait_ticks(3)
		6:
			check("...gone from the hand", p.body_model.get_node_or_null("DowntimeProps") == null)
			return TK.done(fails)
	step += 1
	return false
