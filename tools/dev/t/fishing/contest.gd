extends SceneTree
## A town's fishing contest (1.28): no rod or no gold, no entry; entered, it takes 10 gold, runs on the HUD and
## counts every catch landed (worth x length against size); time up, a score past the town's three anglers places
## 1st (150 gold, shrimp bait and a book), a poor one places 4th (nothing); once a game day per town.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var F
var C
var step := 0
var until := 0
var fails := 0
var g0 := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "hud": false})


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
			F = load("res://scripts/fishing/fishing.gd")
			C = load("res://scripts/fishing/fishing_contest.gd")
			var inv = p.inventory_component
			check("no rod: no entry", C.enter(p, "test_town", 2) != "")
			inv.add_item(ItemDB.get_item("rod_driftwood"), 1)
			p.equip_gear_from_bag(inv.find_index("rod_driftwood"))
			check("no gold: no entry", C.enter(p, "test_town", 2).contains("gold"))
			inv.add_item(ItemDB.get_item("gold"), 50)
			check("entered", C.enter(p, "test_town", 2) == "")
			check("the entry's 10 gold", inv.count("gold") == 40)
			check("a second contest at once is refused", C.enter(p, "other_town", 2) != "")
			until = TK.wait_ticks(5)
			step = 1
		1:
			var c = C.of(p)
			check("it's running with three town anglers", c != null and c.rivals.size() == 3)
			check("its line on the HUD", c._label.text.begins_with("FISHING CONTEST"))
			F.land(p, "fish_king_marlin")
			F.land(p, "fish_golden_carp")
			F.land(p, "fish_mahi")
			check("catches score (%.1f)" % c.score, c.score > 30.0)
			check("past every town angler (%.1f vs %.1f)" % [c.score, c.best_rival()], c.score > c.best_rival())
			g0 = p.inventory_component.count("gold")
			c.left = 0.0
			until = TK.wait_ticks(3)
			step = 2
		2:
			var inv = p.inventory_component
			check("time up, the contest's over", C.of(p) == null)
			check("1st: 150 gold (%d)" % (inv.count("gold") - g0), inv.count("gold") - g0 == 150)
			check("...shrimp bait", inv.count("bait_shrimp") >= 4)
			var books := 0
			for b in C.BOOKS:
				books += inv.count(b)
			check("...and a book", books == 1)
			check("once a game day per town", C.enter(p, "test_town", 2).contains("tomorrow"))
			# another town: a poor score places 4th
			check("another town's contest", C.enter(p, "other_town", 2) == "")
			until = TK.wait_ticks(3)
			step = 3
		3:
			var c = C.of(p)
			g0 = p.inventory_component.count("gold")
			c.left = 0.0
			until = TK.wait_ticks(3)
			step = 4
		4:
			check("no catches: no prize", p.inventory_component.count("gold") == g0 and C.of(p) == null)
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit(1 if fails else 0)
			step = 5
	return false
