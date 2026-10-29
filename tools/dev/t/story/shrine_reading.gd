extends SceneTree
## 1.25.4 the Edy reading is a story step at the shrine: on step "shrine" Master Isao's talk opens on the story's
## reading, his questions (EdyTypes.QUIZ) read the captain's Edy type from the answers (storm answers: Storm), and the
## reading's end moves the story on to Tomo's spar and remembers it was read; Hana at the teahouse no longer reads.
const TK := preload("res://tools/dev/test_kit.gd")
## Each question's storm answer.
const STORM := [3, 3, 3, 1, 3]
var stage
var p
var story
var dlg
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


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
			story = root.get_node("Story")
			dlg = root.get_node("Dialogue")
			load("res://scripts/island/starter_island.gd").edy_reading(dlg)
			story.begin()
			for id in ["find_town", "see_gus", "see_nessa", "lighthouse", "brawl", "see_vey", "vey_rack", "vey_drills", "smugglers", "vey_skills"]:
				story.step = id
				story.complete(id)
			check("(on the shrine step, unread: '%s')" % p.progression.will_color, story.step == "shrine" and p.progression.will_color == "")
			dlg.start("isao")
			check("Isao's talk opens on the story's reading (%s)" % str(dlg._node.get("next", "")), dlg.active and dlg._node.get("next", "") == "sq0")
			dlg._goto("sq0")
			for i in range(STORM.size()):
				var ch: Array = dlg._node["choices"]
				dlg._on_choice(ch[STORM[i]])
				dlg._goto(str(dlg._node["next"]))
			check("the questions done, the type read: Storm (%s)" % p.progression.will_color, p.progression.will_color == "storm")
			dlg._goto(str(dlg._node["next"]))
			check("...then what Edy's for: the tree, infusing (%s)" % dlg._node.get("event", ""), dlg._node.get("event", "") == "story:shrine" and "Infus" in str(dlg._node["text"]))
			dlg._close()
			check("read: the story's on to Tomo (%s)" % story.step, story.step == "tomo")
			check("...and remembered as read", dlg.has_flag("edy_read"))
			var hana: Dictionary = dlg._load("hana")
			check("Hana no longer reads (no quiz in her talk)", not (hana["nodes"] as Dictionary).has("eq0") and not (hana["nodes"] as Dictionary).has("edy_ask"))
			story.reset()
			return TK.done(fails)
	step += 1
	return false
