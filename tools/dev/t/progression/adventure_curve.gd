extends SceneTree
## The Adventure trees' pacing (1.30, docs/v1_30_previews.md section 2): their own curve 40 x lv^1.15 (467 xp for level
## 5, 2,349 for 10) while a weapon keeps 60 x lv^1.3; twice the xp for what you do in Defense, Cooking, Sailing,
## Swimming, Tinkering, Fishing and Stealth (not Acrobatics); an older save (format 8) re-levelled on the new curve,
## Acrobatics' xp halved, nobody losing a level: the playtest's Acrobatics 12 stays 12, Seamanship 4 becomes 6.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
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


func to_level(tree: String, lv: int) -> int:
	var n := 0
	for l in range(1, lv):
		n += pr.mastery_to_next(l, tree)
	return n


func old_total(lv: int, xp: int) -> int:
	var n := xp
	for l in range(1, lv):
		n += pr.mastery_to_next(l)
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			print("   adventure: lv5 %d, lv10 %d, lv30 %d; katana lv5 %d" % [to_level("sea", 5), to_level("sea", 10), to_level("acrobatics", 30), to_level("katana", 5)])
			check("an Adventure tree: 467 xp for level 5, ~2,349 for 10", to_level("sea", 5) == 467 and absi(to_level("sea", 10) - 2349) <= 5)
			check("...a weapon keeps its curve (822 for mastery 5)", to_level("katana", 5) == 822)
			pr.add_life("cook", 10)
			pr.add_life("sea", 10)
			pr.add_life("acrobatics", 10)
			check("Cooking and Sailing earn twice, Acrobatics once", int(pr.mastery_of("cook")["xp"]) == 20 and int(pr.mastery_of("sea")["xp"]) == 20 and int(pr.mastery_of("acrobatics")["xp"]) == 10)
			check("...every doubled tree listed", ["defense", "cook", "sea", "swim", "tinker", "fish", "stealth"].all(func(t): return int(pr.LIFE_XP_K.get(t, 1)) == 2) and not pr.LIFE_XP_K.has("acrobatics"))
			var d: Dictionary = pr.to_dict()
			d["format"] = 8
			d["mastery"] = {"acrobatics": {"lv": 12, "xp": 7587 - old_total(12, 0)}, "sea": {"lv": 4, "xp": 794 - old_total(4, 0)},
				"swim": {"lv": 3, "xp": 311 - old_total(3, 0)}, "katana": {"lv": 9, "xp": 40}}
			pr.from_dict(d)
			print("   migrated: acrobatics %s sea %s swim %s katana %s" % [pr.mastery_of("acrobatics"), pr.mastery_of("sea"), pr.mastery_of("swim"), pr.mastery_of("katana")])
			check("an old save's Acrobatics 12 (7,587 xp) stays 12 on half its xp", pr.mastery_level("acrobatics") == 12)
			check("...Seamanship 4 (794 xp) becomes 6, Swimming 3 (311) becomes 4", pr.mastery_level("sea") == 6 and pr.mastery_level("swim") == 4)
			check("...the katana untouched", pr.mastery_level("katana") == 9 and int(pr.mastery_of("katana")["xp"]) == 40)
			check("...Adventure points follow the levels (11 + 5 + 3)", pr.earned("adventure") == 19)
			d = pr.to_dict()
			pr.from_dict(d)
			check("...saved again and loaded: not re-levelled twice", pr.mastery_level("sea") == 6 and pr.mastery_level("acrobatics") == 12)
			return TK.done(fails)
	step += 1
	return false
