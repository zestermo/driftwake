extends SceneTree
## 1.23 villages: a person with a quest to give shows a gold "!" over their head, gone once it's taken, and a "?" when
## it's ready to turn in; a face in the crowd ("scenery") has no talk prompt; a village rolls 2-4 traders from the
## pool, all different, each with a shop cut from the home island's.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var j
var kai
var crowd
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			j = root.get_node("Journal")
			j.reset()
			j.register({"id": "t_mark", "title": "Lost Net", "giver": "Net-mender Kai", "isle": "Test", "pos": Vector3.ZERO, "src": "npc",
				"steps": [{"goal": "Find it", "do": "reach"}, {"goal": "Tell Kai", "do": "turnin"}], "reward": {"gold": 5}}, null)
			var N = load("res://scripts/npc/npc.gd")
			kai = N.new().setup({"name": "Net-mender Kai", "barks": ["Hm."]})
			stage.add_child(kai)
			kai.global_position = stage.player.global_position + Vector3(3, 0, 0)
			crowd = N.new().setup({"name": "Villager", "barks": ["Fine day."], "scenery": true})
			stage.add_child(crowd)
			crowd.global_position = stage.player.global_position + Vector3(-3, 0, 0)
			until = TK.wait_secs(1.5)
		1:
			check("a quest to give: '!' over their head", kai._mark != null and kai._mark.visible and kai._mark.text == "!")
			check("a face in the crowd has no talk prompt", not crowd.interactable.enabled)
			j.take("t_mark")
			until = TK.wait_secs(1.5)
		2:
			check("taken: the mark goes", kai._mark == null or not kai._mark.visible)
			j.advance("t_mark", 0)
			until = TK.wait_secs(1.5)
		3:
			check("ready to turn in: '?'", kai._mark != null and kai._mark.visible and kai._mark.text == "?")
			var V = load("res://scripts/island/village_vendors.gd")
			var ok := true
			var seen := {}
			for s in range(1, 30):
				var t: Array = V.roll(s, 1)
				if t.size() < 2 or t.size() > 4 or t.size() != (t.duplicate() as Array).filter(func(x): return t.count(x) == 1).size():
					ok = false
				for x in t:
					seen[x] = true
					var sh: Dictionary = V.shop(str(x), "Aru")
					if not sh.has("stock") or not str(sh["name"]).begins_with("Aru"):
						ok = false
			check("villages roll 2-4 different traders, each with a shop (%s)" % str(seen.keys()), ok and seen.size() == V.POOL.size())
			return TK.done(fails)
	step += 1
	return false
