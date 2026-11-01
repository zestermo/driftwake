extends SceneTree
## The workbench (1.28): F at it opens the bench and studies a carried blueprint (learned, used up); Build makes the
## gadget's Mk I from the bag's gold and parts (paid, Tinkering xp, onto the belt with full charges); without the
## parts it says what's short and takes nothing; an unknown blueprint can't be built.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var bench
var menu
var step := 0
var until := 0
var fails := 0
var xp0 := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _give(id: String, n: int) -> void:
	p.inventory_component.add_item(ItemDB.get_item(id), n)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var G = load("res://scripts/gadgets/gadgets.gd")
	match step:
		0:
			p = stage.player
			menu = root.get_node("GameMenu")
			bench = load("res://scripts/gadgets/workbench.gd").place(stage, p.global_position + Vector3(0, 0, -1.9), PI)
			_give("bp_tar", 1)
			_give("gold", 30)
			_give("pitch", 2)
			_give("timber", 1)
			check("the tar bomb's blueprint isn't known yet", not G.knows(p, "tar"))
			check("an unknown blueprint can't be built", G.why_not(p, "caltrops") != "" and G.build(p, "caltrops") != "")
			until = TK.wait_ticks(6)
		1:
			TK.act("interact")
			until = TK.wait_secs(0.4)
		2:
			check("F at the bench opens it", menu.is_open() and menu._current == "workbench")
			check("...and studies the carried blueprint", G.knows(p, "tar") and p.inventory_component.count("bp_tar") == 0)
			xp0 = int(p.progression.mastery_of("tinker")["xp"]) + 1000 * p.progression.mastery_level("tinker")
			menu._bench._pick("tar")
			menu._bench.build_selected()
			check("Build makes a Mk I tar bomb onto the belt", p.gadgets.tier_of("tar") == 0 and "tar" in p.gadgets.slots)
			check("...with its charges full", p.gadgets.charges("tar") == 3)
			check("...paid from the bag", p.inventory_component.count("gold") == 0 and p.inventory_component.count("pitch") == 0 and p.inventory_component.count("timber") == 0)
			check("...for Tinkering xp", int(p.progression.mastery_of("tinker")["xp"]) + 1000 * p.progression.mastery_level("tinker") > xp0)
			check("the smoke pellet is known from the start", G.knows(p, "smoke"))
			var why: String = G.build(p, "smoke")
			check("without its parts it says what's short (%s)" % why, why.begins_with("Short of") and p.gadgets.tier_of("smoke") == -1)
			menu.close()
			until = TK.wait_ticks(4)
		3:
			check("the bench closes", not menu.is_open())
			return TK.done(fails)
	step += 1
	return false
