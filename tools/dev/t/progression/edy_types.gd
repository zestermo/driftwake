extends SceneTree
## Edy (1.24.1, EdyTypes): a master's questions read a captain's type (most answers wins, a tie to the last answer);
## nothing's bought before it's read; each type's edge (Still: wider parry and dodge, Ember: heavier heavies, Crown:
## quicker ultimate, Storm: quicker attacks just after a dodge, Tide: quicker revives); the colours picked before
## become types; the capital's re-reading costs EdyTypes.REREAD_GOLD and does nothing without it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
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


func ev(e: String) -> void:
	root.get_node("Dialogue").dialogue_event.emit(e)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			var ET = load("res://scripts/progression/edy_types.gd")
			var nodes: Dictionary = ET.quiz_nodes("e", "after")
			check("the quiz: five questions, then the reading", nodes.has("eq0") and nodes.has("eq4") and nodes.has("eread") and str(nodes["eq0"].get("event", "")) == "edy:reset")
			pr.gift("will", 4)
			check("unread: nothing to buy (%s)" % pr.buy_why("w_coat_heavy"), pr.will_color == "" and pr.buy_why("w_coat_heavy").begins_with("Your Edy isn't read yet") and not pr.buy("w_coat_heavy"))
			for e in ["edy:reset", "edy:+storm", "edy:+still,tide", "edy:+tide", "edy:+still", "edy:+crown", "edy:read"]:
				ev(e)
			check("answers 1 storm, 2 still, 2 tide, 1 crown: a tie, and Tide was answered later... (%s)" % pr.will_color, pr.will_color == "still" or pr.will_color == "tide")
			for e in ["edy:reset", "edy:+ember", "edy:+ember", "edy:+storm", "edy:read"]:
				ev(e)
			check("most answers Ember: read as Ember", pr.will_color == "ember")
			check("...its colour on every Edy effect", pr.will_tint() == ET.color_of("ember"))
			check("...and now Coat can be bought", pr.buy("w_coat_heavy"))
			var h0: float = p.melee_hit(20.0, "heavy").damage
			var l0: float = p.melee_hit(20.0, "").damage
			pr.attune("still")
			var h1: float = p.melee_hit(20.0, "heavy").damage
			check("Ember's heavies hit 4%% harder (%.2f vs %.2f), lights the same" % [h0, h1], is_equal_approx(h0, h1 * 1.04) and is_equal_approx(l0, p.melee_hit(20.0, "").damage))
			check("Still: +0.03 parry window, +10%% dodge window", is_equal_approx(pr.stat("parry_all"), 0.03) and is_equal_approx(pr.stat("dodge_iframe_pct"), 0.1))
			pr.attune("crown")
			check("Crown: the ultimate charges 5% faster", is_equal_approx(pr.stat("ult_charge_pct"), 0.05))
			pr.attune("tide")
			check("Tide: revives 10% faster, Bond's gauge 5%", is_equal_approx(pr.stat("revive_pct"), 0.1) and is_equal_approx(pr.stat("bond_gauge_pct"), 0.05))
			pr.attune("storm")
			check("Storm: no haste before a dodge", ET.haste(p) == 0.0)
			p.state_machine.force_state("Dodge", {})
			check("...+3% attack speed just after one", is_equal_approx(ET.haste(p), 0.03))
			until = TK.wait_secs(2.3)
		1:
			var ET = load("res://scripts/progression/edy_types.gd")
			check("...gone 2 s later", ET.haste(p) == 0.0)
			var d: Dictionary = pr.to_dict()
			d["will_color"] = "red"
			pr.from_dict(d)
			check("a save's old red colour loads as Ember", pr.will_color == "ember")
			d["will_color"] = "blue"
			pr.from_dict(d)
			check("...blue as Still", pr.will_color == "still")
			var inv = p.inventory_component
			var gold = load("res://scripts/loot/item_db.gd").get_item("gold")
			inv.remove_item(gold, inv.count("gold"))
			ev("edy:buy:crown")
			check("the capital's re-reading without the gold: nothing changes", pr.will_color == "still")
			inv.add_item(gold, ET.REREAD_GOLD + 5)
			ev("edy:buy:crown")
			check("with %d gold: attuned to Crown, the gold paid (%d left)" % [ET.REREAD_GOLD, inv.count("gold")], pr.will_color == "crown" and inv.count("gold") == 5)
			return TK.done(fails)
	step += 1
	return false
