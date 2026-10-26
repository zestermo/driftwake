extends SceneTree
## 1.23 tutorial: on Story's "vey_drills" step Vey's checklist shows (each move with its key), ticks as the captain does
## each (cuts, a lunge, a roll, sheathe and draw...), and when every one's ticked the story moves on to the smugglers.
## A menu's first-time tip shows once (Walkthrough), and never again.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var d
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": true, "dummy": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var story = root.get_node("Story")
	match step:
		0:
			p = stage.player
			story.step = "vey_drills"
			story.changed.emit()
			until = TK.wait_ticks(3)
		1:
			var ds := get_nodes_in_group("drills")
			d = ds[0] if not ds.is_empty() else null
			check("Vey's checklist shows on the drills step", d != null)
			if d:
				check("...each move with its key (%s)" % d._rows["dodge"].text, d._rows["dodge"].text.begins_with("[ ]") and not d._rows["dodge"].text.contains("%s"))
			TK.act("ready_weapon")
			until = TK.wait_secs(0.6)
		2:
			TK.act("light_attack")
			until = TK.wait_secs(0.3)
		3:
			TK.act("light_attack")
			until = TK.wait_secs(0.3)
		4:
			TK.act("light_attack")
			until = TK.wait_secs(1.6)
		5:
			check("a two-cut combo: ticked", d.done.has("light"))
			TK.press("heavy_attack")
			until = TK.wait_secs(0.25)
		6:
			TK.release("heavy_attack")
			until = TK.wait_secs(1.0)
		7:
			check("a lunge: ticked", d.done.has("heavy"))
			TK.act("dodge")
			until = TK.wait_secs(0.9)
		8:
			check("a roll: ticked", d.done.has("dodge"))
			TK.act("ready_weapon")
			until = TK.wait_secs(0.6)
		9:
			TK.act("ready_weapon")
			until = TK.wait_secs(0.6)
		10:
			check("sheathed and drawn again: ticked", d.done.has("draw"))
			for id in ["parry", "block", "air"]:
				d.tick(id)
			until = TK.wait_ticks(3)
		11:
			check("all ticked: the story moves on to the smugglers (%s)" % story.step, story.step == "smugglers" and get_nodes_in_group("drills").is_empty())
			# a first-time tip, once (tools never show them: allow it here)
			return TK.done(fails)
	step += 1
	return false
