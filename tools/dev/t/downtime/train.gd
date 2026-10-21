extends SceneTree
## Training (the action wheel's Train): the weapon comes out and the body runs its drill (a suburi loop with a
## blade), and every interval of it the weapon in your hand gains mastery; moving gets you up again.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var AW
var DT
var xp0 := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func sword_xp() -> int:
	var m: Dictionary = p.progression.mastery_of("sword")
	var total := int(m["xp"])
	for lv in range(1, int(m["lv"])):
		total += p.progression.mastery_to_next(lv)
	return total


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			AW = load("res://scripts/game/action_wheel.gd")
			DT = load("res://scripts/game/downtime.gd")
			p.sheathe_weapon(true)
			until = TK.wait_ticks(3)
		1:
			var ids: Array = AW.entries_for(p)
			check("ashore the wheel offers Train with the cutlass (%s)" % AW.label_of("train", p), ids.has("train") and AW.label_of("train", p).contains("Cutlass"))
			xp0 = sword_xp()
			AW.run("train", p)
			until = TK.wait_ticks(20)
		2:
			check("training: the Downtime state, the blade drawn (%s)" % p.current_state_name(), p.current_state_name() == "Downtime" and p.armed)
			check("...the body runs the blade drill (%s)" % p.body_model.current_action(), p.body_model.current_action() == "dt_train_blade")
			until = TK.wait_secs(DT.KINDS["train"]["every"] + 0.3)
		3:
			check("an interval of training: +%d cutlass mastery (%d)" % [DT.TRAIN_MASTERY, sword_xp() - xp0], sword_xp() - xp0 == DT.TRAIN_MASTERY)
			TK.press("move_forward")
			until = TK.wait_ticks(4)
		4:
			TK.release("move_forward")
			check("moving gets you up (%s)" % p.current_state_name(), p.current_state_name() in ["Idle", "Move"] and p.body_model.current_action() != "dt_train_blade")
			p.progression.mastery_of("sword")["lv"] = DT.TRAIN_CAP
			check("drills teach only up to mastery %d (%s)" % [DT.TRAIN_CAP, DT.refuse(p, "train")], DT.refuse(p, "train") != "" and DT._train_ok(p) is String)
			return TK.done(fails)
	step += 1
	return false
