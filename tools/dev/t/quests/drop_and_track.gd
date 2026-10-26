extends SceneTree
## 1.23's journal fixes: a quest you take becomes the one you track (even while another is tracked), a crewmate's
## doesn't steal it, and a dropped quest leaves the journal (tracking falls to the next) and can be taken again.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var j
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


func entry(id: String, by: int) -> Dictionary:
	return {"id": id, "title": id.capitalize(), "giver": "Kai", "isle": "Test Isle", "pos": Vector3(120, 0, -40), "src": "board",
		"goals": ["Do it", "Tell Kai"], "step": 0, "done": false, "reward": {"gold": 5}, "cost": [], "by": by}


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			j = root.get_node("Journal")
			var me: int = root.get_node("Net").my_id()
			j.reset()
			j.apply("take", [entry("t_old", me)])
			check("the first quest taken is tracked", j.tracked == "t_old")
			j.apply("take", [entry("t_new", me)])
			check("a newer quest you take is tracked at once (not the old one)", j.tracked == "t_new")
			j.apply("take", [entry("t_mate", me + 7)])
			check("a crewmate's new quest doesn't take your tracking", j.tracked == "t_new")
			j.abandon("t_new")
			check("dropped: out of the journal", not j.has("t_new") and j.active().size() == 2)
			check("...tracking moves to another active quest", j.tracked != "t_new" and j.has(j.tracked))
			j.apply("take", [entry("t_new", me)])
			check("...and it can be taken again", j.has("t_new") and not j.is_done("t_new"))
			j.abandon("story")
			check("the story can't be dropped (nothing happens)", j.active().size() == 3)
			return TK.done(fails)
	step += 1
	return false
