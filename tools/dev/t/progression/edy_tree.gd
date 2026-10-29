extends SceneTree
## The Edy tree (1.26, EdyTree; docs/v1_26_plan.md round 3): nothing before the reading; then anything linked to the
## core or to what you own, for its price in Edy; bridges join two branches; an ability ranks up by use (its effects
## change, a toast); a switchable passive turns off (its effects gone) and back on; the save keeps the uses and switches.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


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
	var p = stage.player
	var pr = p.progression
	var ET = load("res://scripts/progression/edy_tree.gd")
	pr.will_color = ""
	pr.gift("will", 40)
	check("unread: nothing to buy (%s)" % pr.buy_why("e_iron_0"), pr.buy_why("e_iron_0").begins_with("Your Edy isn't read yet"))
	pr.will_color = "storm"
	check("read: the core's first nodes can be bought", pr.buy_why("e_iron_0") == "" and pr.buy_why("e_tide_0") == "")
	check("...a node further out can't, not linked to anything yours (%s)" % pr.buy_why("e_iron_5"), pr.buy_why("e_iron_5") != "")
	check("eight branches of seven, sixteen bridges", ET.all().size() == 1 + 8 * 7 + 16)
	check("a bridge is reached from either side", ET.learn_path(pr, "e_iron_2") and pr.buy_why("e_br0_0") == "")
	# ranks by use
	check("Infuse bought: rank I, its skill known", ET.learn_path(pr, "e_iron_1") and pr.knows("armament_coat") and ET.rank(pr, "e_iron_1") == 1)
	var c0: float = pr.stat("coat_dmg")
	ET.use(p, "e_iron_1", 25)
	check("25 uses: rank II, Hardened (coat %.2f -> %.2f)" % [c0, pr.stat("coat_dmg")], ET.rank(pr, "e_iron_1") == 2 and pr.stat("coat_dmg") > c0 + 0.1)
	ET.use(p, "e_iron_1", 60)
	check("85 uses: rank III, Overflow", ET.rank(pr, "e_iron_1") == 3 and pr.stat("coat_burst") >= 1.0)
	# Foresight by itself
	check("Foresight works by itself: every 20 s", ET.learn_path(pr, "e_sense_3") and is_equal_approx(pr.stat("foresight_auto"), 20.0))
	ET.use(p, "e_sense_3", 40)
	check("...40 dodges: Second Sight, every 14 s", is_equal_approx(pr.stat("foresight_auto"), 14.0))
	# a switch
	check("Wave Walk bought: on", ET.learn_path(pr, "e_tide_1") and pr.stat("wave_walk") >= 1.0)
	pr.edy_off["e_tide_1"] = true
	pr._dirty()
	check("...switched off: its effect gone", pr.stat("wave_walk") <= 0.0)
	var d: Dictionary = pr.to_dict()
	pr.from_dict(d)
	check("the save keeps the uses and the switch", int(pr.edy_uses.get("e_iron_1", 0)) == 85 and pr.edy_off.has("e_tide_1") and pr.bought.has("e_sense_3"))
	pr.edy_off.erase("e_tide_1")
	pr._dirty()
	check("...switched back on", pr.stat("wave_walk") >= 1.0)
	return TK.done(fails)
