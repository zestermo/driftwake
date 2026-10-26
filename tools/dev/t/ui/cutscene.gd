extends SceneTree
## Cutscene (scripts/dialogue/cutscene.gd), played the co-op way (Net.everyone "_all_cutscene", here single player):
## it takes the camera and letterboxes the screen, the captain's held (the stick moves nothing), an AI captain holds
## still, the line types out as a subtitle under its speaker's name, and at the end the camera and control come back; played
## again, Interact skips it at once.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var c
var cam0: Camera3D
var rival
var rpos := Vector3.ZERO
var ppos := Vector3.ZERO
var ended := []
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"npc": {}})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func cut() -> Script:
	return load("res://scripts/dialogue/cutscene.gd")


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var net := root.get_node("Net")
	match step:
		0:
			p = stage.player
			cam0 = root.get_viewport().get_camera_3d()
			rival = load("res://scripts/ai/rival_duel.gd").spawn(p, 0.9, "cutlass")
			until = TK.wait_secs(0.4)
		1:
			rpos = rival.global_position
			ppos = p.global_position
			net.everyone("_all_cutscene", ["test", [net.key_of(stage.npc)]])
			c = cut().active
			c.finished.connect(func(skipped): ended.append(skipped))
			TK.press("move_forward")
			until = TK.wait_secs(0.9)
		2:
			check("it plays and takes the camera", c != null and root.get_viewport().get_camera_3d() == c._cam)
			check("...the captain's held: the stick moves nothing (%.2f m)" % p.global_position.distance_to(ppos), p.input_locked and p.global_position.distance_to(ppos) < 0.05)
			check("...an AI captain holds still (%.2f m)" % rival.global_position.distance_to(rpos), rival.global_position.distance_to(rpos) < 0.3)
			check("...letterboxed", c._bars != null and c._bars.get_child_count() >= 2)
			until = TK.wait_secs(0.9)
		3:
			check("the line types out under its speaker's name ('%s: %s')" % [c._name_tag.text, c._bubble.text], c._bubble.visible and c._bubble.text.length() > 0 and c._name_tag.text == "Test")
			until = TK.wait_secs(2.5)
		4:
			TK.release("move_forward")
			check("it ends by itself (not skipped)", ended == [false] and cut().active == null)
			check("...the camera and control come back", root.get_viewport().get_camera_3d() == cam0 and not p.input_locked)
			net.everyone("_all_cutscene", ["test", [net.key_of(stage.npc)]])
			c = cut().active
			c.finished.connect(func(skipped): ended.append(skipped))
			until = TK.wait_secs(0.3)
		5:
			TK.act("interact")
			until = TK.wait_ticks(3)
		6:
			check("Interact skips it at once", ended == [false, true] and cut().active == null and not p.input_locked)
			# 1.23: a line waits for the captain's press (tests opt in to the wait)
			cut().tools_wait = true
			net.everyone("_all_cutscene", ["test", [net.key_of(stage.npc)]])
			c = cut().active
			c.finished.connect(func(skipped): ended.append(skipped))
			until = TK.wait_secs(1.5)
		7:
			TK.act("jump")
			until = TK.wait_ticks(3)
		8:
			check("a press while it types finishes the line ('%s')" % c._bubble.text, c._bubble.text == c._line and cut().active != null)
			until = TK.wait_secs(3.0)
		9:
			check("...then it waits for the press, not the clock", cut().active == c and ended.size() == 2)
			TK.act("jump")
			until = TK.wait_ticks(3)
		10:
			check("...and a second press goes on (the scene ends, not skipped)", ended == [false, true, false] and cut().active == null)
			cut().tools_wait = false
			return TK.done(fails)
	step += 1
	return false
