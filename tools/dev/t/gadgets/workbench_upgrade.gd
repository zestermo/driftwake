extends SceneTree
## Upgrading at the workbench (1.28): Mk II waits for Tinkering 6 and Mk III for 12; each upgrade is paid from the bag,
## refills to the new tier's charges, looks different (its own model; the pouch on the back follows the belt's best
## tier) and does more; past Mk III there's nothing more.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
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


func _pay_for(G, tier: int) -> void:
	for e in G.cost("smoke", tier):
		p.inventory_component.add_item(ItemDB.get_item(str(e[0])), int(e[1]))


func _tinker(lv: int) -> void:
	p.progression.mastery["tinker"] = {"lv": lv, "xp": 0}


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var G = load("res://scripts/gadgets/gadgets.gd")
	var D = load("res://scripts/gadgets/gadget_data.gd")
	var M = load("res://scripts/gadgets/gadget_models.gd")
	match step:
		0:
			p = stage.player
			_tinker(1)
			_pay_for(G, 0)
			check("Mk I builds at Tinkering 1", G.build(p, "smoke") == "" and p.gadgets.tier_of("smoke") == 0)
			_pay_for(G, 1)
			var why: String = G.why_not(p, "smoke")
			check("Mk II waits for Tinkering 6 (%s)" % why, why == "Needs Tinkering 6")
			_tinker(6)
			p.gadgets.owned["smoke"]["charges"] = 1
			check("at 6 it upgrades", G.build(p, "smoke") == "" and p.gadgets.tier_of("smoke") == 1)
			check("...paid (no gold left)", p.inventory_component.count("gold") == 0)
			check("...to Mk II's charges, full (%d)" % p.gadgets.charges("smoke"), p.gadgets.charges("smoke") == 4)
			check("...a bigger cloud", D.tier_val("smoke", "radius", 1) > D.tier_val("smoke", "radius", 0))
			check("Mk II has its own model", M.mesh("smoke", 1) != M.mesh("smoke", 0))
			check("the pouch shows Mk II", p.body_model.pouch_tier == 1)
			_pay_for(G, 2)
			check("Mk III waits for Tinkering 12", G.why_not(p, "smoke") == "Needs Tinkering 12")
			_tinker(12)
			check("at 12 it goes to Mk III", G.build(p, "smoke") == "" and p.gadgets.tier_of("smoke") == 2 and p.gadgets.charges("smoke") == 5)
			check("...the pouch with it", p.body_model.pouch_tier == 2)
			check("nothing past Mk III", G.next_tier(p, "smoke") == -1 and G.why_not(p, "smoke") == "Already Mk III")
			return TK.done(fails)
	step += 1
	return false
