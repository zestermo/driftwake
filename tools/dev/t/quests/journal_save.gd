extends SceneTree
## The crew journal is kept in the save: an active quest on its second step, a done one, the rumours, the
## crew's perks (a discount, a favour owed) and the quest this captain tracks all come back after a load.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
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


func entry(id: String, goals: Array, reward: Dictionary) -> Dictionary:
	return {"id": id, "title": id.capitalize(), "giver": "Kai", "isle": "Test Isle", "pos": Vector3(120, 0, -40), "src": "board", "goals": goals, "step": 0,
		"done": false, "reward": reward, "cost": []}


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			j = root.get_node("Journal")
			j.reset()
			j.apply("take", [entry("t_hunt", ["Find the tracks", "Follow them", "Tell Kai"], {"gold": 20})])
			j.apply("step", ["t_hunt", 0])
			j.apply("take", [entry("t_done", ["Tell Kai"], {"gold": 5, "discount": ["t_shop", 0.1, "Wiremu's"], "favour": {"who": "Kai", "gift": [["rum", 1]]}})])
			j.apply("done", ["t_done", Vector3(9999, 0, 0), 1, []])
			j.apply("rumour", [{"text": "The reef sings at night.", "who": "Kai", "isle": "Test Isle"}])
			j.track("t_hunt")
			var SG = load("res://scripts/game/save_game.gd")
			check("saved", SG.save(p))
			j.reset()
			check("(cleared)", j.entries.is_empty() and j.rumours.is_empty() and j.perks.is_empty() and j.tracked == "story")
			SG.load_into(p)
			check("the active quest, on its second step", j.has("t_hunt") and not j.is_done("t_hunt") and j.step_of("t_hunt") == 1 and j.goal("t_hunt") == "Follow them")
			check("...where its island is", j.target("t_hunt") == Vector3(120, 0, -40))
			check("the done one, done", j.is_done("t_done") and j.done().size() == 1)
			check("the rumour", j.rumours.size() == 1 and j.rumours[0]["text"] == "The reef sings at night.")
			check("the crew's discount and the favour owed", is_equal_approx(j.discount("t_shop"), 0.1) and j.favour_owed("t_done"))
			check("the quest this captain tracks", j.tracked == "t_hunt")
			j.apply("take", [entry("t_new", ["Tell Kai"], {"gold": 1})])
			check("taken after the load: listed above the older ones", j.active()[0]["id"] == "t_new")
			return TK.done(fails)
	step += 1
	return false
