extends SceneTree
## Everyone present gets a quest's reward: a turn-in (by this captain or, as it arrives from the host, by a
## crewmate) pays gold and items to this captain when they're within the journal's reach of it and nothing
## when they're far off; never XP. Only the captain turning in hands over its items. A discount and a favour
## are the crew's either way; the favour is called in once, its gift to whoever calls it.
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


func entry(id: String, reward: Dictionary, cost: Array = []) -> Dictionary:
	return {"id": id, "title": id, "giver": "Kai", "isle": "Test Isle", "pos": Vector3.ZERO, "src": "npc", "goals": ["Tell Kai"], "step": 0,
		"done": false, "reward": reward, "cost": cost}


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			j = root.get_node("Journal")
			j.reset()
			var inv = p.inventory_component
			var xp0: int = p.progression.xp
			for e in [entry("t_far", {"gold": 30, "discount": ["t_shop", 0.15, "Wiremu's Trade Goods"], "favour": {"who": "Kai", "gift": [["rum", 2]]}}),
					entry("t_near", {"gold": 25, "items": [["tonic", 2]]}), entry("t_mate", {"gold": 10, "items": [["stew", 1]]}, [["fish", 1]]),
					entry("t_mate_far", {"gold": 10})]:
				j.apply("take", [e])
			var far: Vector3 = p.global_position + Vector3(0, 0, -j.REWARD_REACH - 5.0)
			var g0: int = inv.count("gold")
			j.turn_in("t_far", far)
			check("turned in out of reach: done, but nothing for this captain", j.is_done("t_far") and inv.count("gold") == g0)
			check("...the crew's discount stands (15% at t_shop)", is_equal_approx(j.discount("t_shop"), 0.15))
			check("...and Kai owes the crew a favour", j.favour_owed("t_far"))
			j.turn_in("t_near", p.global_position + Vector3(3, 0, 0))
			check("turned in close by: 25 gold and two tonics", inv.count("gold") == g0 + 25 and inv.count("tonic") >= 2)
			inv.add_item(ItemDB.get_item("fish"), 1)
			var fish: int = inv.count("fish")
			var stew: int = inv.count("stew")
			# (as the host passes on a crewmate's turn-in: by peer 2)
			j.apply("done", ["t_mate", p.global_position + Vector3(0, 0, 8), 2])
			check("a crewmate's turn-in close by pays this captain too (10 gold, a stew)", inv.count("gold") == g0 + 35 and inv.count("stew") == stew + 1)
			check("...and their items aren't taken from this captain's bag", inv.count("fish") == fish)
			j.apply("done", ["t_mate_far", far, 2])
			check("a crewmate's turn-in far off pays this captain nothing", inv.count("gold") == g0 + 35 and j.is_done("t_mate_far"))
			check("no XP from any of it", p.progression.xp == xp0)
			var rum: int = inv.count("rum")
			j.call_favour("t_far")
			check("calling in the favour: the gift to the caller, and it's spent", inv.count("rum") == rum + 2 and not j.favour_owed("t_far"))
			j.call_favour("t_far")
			check("...only once", inv.count("rum") == rum + 2)
			return TK.done(fails)
	step += 1
	return false
