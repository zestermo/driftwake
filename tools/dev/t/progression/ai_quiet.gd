extends SceneTree
## An AI captain's progression never reaches this screen's HUD (1.26: a rival's new weapon trees showed their
## "Added to COMBAT" cards on the player's screen): its level-ups, tree finds and Edy stay its own; the player's own
## still show.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0
var calls: Array = []


class Ear extends Node:
	var log: Array
	func show_banner(t, _s = "", _b = false): log.append("banner " + str(t))
	func show_toast(t): log.append("toast " + str(t))
	func show_new_tree(t, _s = ""): log.append("tree " + str(t))


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var ear := Ear.new()
	ear.log = calls
	ear.add_to_group("hud")
	root.add_child(ear)
	var p = stage.player
	var pr = p.progression
	p.is_ai = true
	pr.found.erase("cannon")
	pr.discover("cannon")
	pr.add_xp(5000)
	pr.will_point(1, "test")
	check("an AI captain's tree find, level-ups and Edy show nothing here (%s)" % ", ".join(calls), calls.is_empty())
	check("...though it did level up (%d)" % pr.level, pr.level > 1)
	p.is_ai = false
	calls.clear()
	pr.will_point(1, "test")
	check("the player's own still show (%s)" % ", ".join(calls), not calls.is_empty())
	return TK.done(fails)
