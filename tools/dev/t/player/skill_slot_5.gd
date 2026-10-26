extends SceneTree
## Keys 1-5 are ability slots: a skill on the fifth slot casts with 5 (the ultimate stays on R), and a newly
## learned skill fills the fifth slot once 1-4 are taken. Nothing is bound to 6.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var sk := ""
var casts: Array = []
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


## Skills a captain with a cutlass can cast on dry land, with their tree nodes.
func plain_skills() -> Array:
	var tree = load("res://scripts/progression/skill_trees.gd")
	var skills = load("res://scripts/progression/skills.gd")
	var out: Array = []
	for k in tree.nodes().keys():
		var id := str(tree.node_def(k).get("skill", ""))
		if id == "" or skills.is_ult(id) or out.any(func(o): return o[0] == id):
			continue
		var d: Dictionary = skills.get_skill(id)
		var styles: Array = d.get("styles", [])
		if str(d.get("fruit", "")) == "" and str(d.get("needs", "")) in ["", "sword"] and (styles.is_empty() or styles.has("sword")):
			out.append([id, k])
	return out


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var plain := plain_skills()
			check("enough plain skills to fill the bar (%d)" % plain.size(), plain.size() >= 5)
			for i in range(5):
				p.progression.owned[plain[i][1]] = true
				p.power.auto_equip(plain[i][0])
			sk = plain[4][0]
			check("the fifth learned skill goes on slot 5 (key 5)", p.power.loadout[5] == sk and p.power.key_of(5) == "5")
			check("nothing on 6", not InputMap.has_action("skill_6"))
			p.power.energy = p.power.max_energy()
			p.power.cast.connect(func(slot): casts.append(slot))
			TK.act("skill_5")
			until = TK.wait_ticks(3)
		1:
			check("5 casts it (%s)" % str(casts), casts == [5])
			check("the ultimate slot stays R", p.power.key_of(p.power.ULT) == "R" and not p.power.equip(sk, p.power.ULT))
			return TK.done(fails)
	step += 1
	return false
