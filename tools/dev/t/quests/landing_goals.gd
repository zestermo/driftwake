extends SceneTree
## 1.30 (round 9): landing on a new island, the objective box gives three first steps in order, each the crew's (world
## flags and the journal): 1. find the town (until a captain reaches it), 2. ask the elder what troubles the island
## (until the crew takes its trouble), 3. check the notice board (until a captain reads it); then the trouble's own step.
const TK := preload("res://tools/dev/test_kit.gd")
const ISLE := preload("res://tools/dev/t/quests/_isle.gd")
var stage
var p
var isl
var hud
var gm
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _put(at: Vector2) -> void:
	p.global_position = ISLE.world(isl, at) + Vector3.UP * 1.5
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			gm = root.get_node("GameManager")
			root.get_node("Journal").reset()
			root.get_node("Dialogue").set_flag("log_pose")
			p.progression.level = 6
			isl = ISLE.build(stage, 9100)
			hud = stage.hud._objective
			check("the island has its trouble", isl.life.arc != null)
			_put(isl.sites["dock"])
			until = TK.wait_ticks(30)
		1:
			check("landed: find the town first (%s)" % hud._goal.text, hud._goal.text.begins_with("Find the town"))
			check("...the chain's step, a marker with its distance (%s)" % hud._dist.text, hud._head.text.contains("THE CHAIN") and hud._dist.text != "")
			check("...nobody has found it yet", not gm.world_flags.has(isl.life.town_flag()))
			_put(isl.sites["village"])
			until = TK.wait_ticks(60)
		2:
			check("in the village: the crew found the town (a world flag)", gm.world_flags.get(isl.life.town_flag(), false))
			var elder: String = isl.life.arc.village.elder_name
			check("then ask the elder (%s)" % hud._goal.text, hud._goal.text == "Ask %s what troubles %s" % [elder, isl.island_name])
			root.get_node("Journal").take(isl.life.arc.key)
			until = TK.wait_ticks(20)
		3:
			check("the trouble taken: check the board (%s)" % hud._goal.text, hud._goal.text.begins_with("Check the notice board"))
			var v = isl.get_node("Site_village/Village")
			v.read_board(p)
			check("reading the board opens its page", root.get_node("GameMenu")._current == "notice_board")
			root.get_node("GameMenu").close()
			until = TK.wait_ticks(20)
		4:
			check("read: a world flag", gm.world_flags.get(isl.life.board_flag(), false))
			var j = root.get_node("Journal")
			check("then the trouble's own step (%s)" % hud._goal.text, hud._goal.text == j.goal(isl.life.arc.key))
			return TK.done(fails)
	step += 1
	return false
