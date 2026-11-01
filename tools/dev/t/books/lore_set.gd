extends SceneTree
## A lore set pays its reward on its last volume, not before: the Drowned King a Will point, Captain Orla's voyages gold
## and the Feast of the Isles, the Bestiary a permanent +15% rare fish.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var B
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			B = load("res://scripts/books/books.gd")
			var will0: int = pr.will_earned
			for id in ["lore_king_1", "lore_king_2", "lore_king_3"]:
				B.read(p, id)
			check("three of four volumes: no reward yet", pr.will_earned == will0 and not B.set_done(pr, "drowned_king"))
			B.read(p, "lore_king_4")
			check("the fourth: the set's Will point", pr.will_earned == will0 + 1 and B.set_done(pr, "drowned_king"))
			var gold0: int = p.inventory_component.count("gold")
			for id in ["lore_orla_1", "lore_orla_2", "lore_orla_3"]:
				B.read(p, id)
			check("Orla's voyages: 400 gold", p.inventory_component.count("gold") == gold0 + 400)
			check("...and the Feast of the Isles", pr.recipes.has("isles_feast"))
			var rare0: float = pr.stat("fish_rare_pct")
			B.read(p, "lore_deep_1")
			B.read(p, "lore_deep_2")
			check("the Bestiary unfinished: no perk", is_equal_approx(pr.stat("fish_rare_pct"), rare0))
			B.read(p, "lore_deep_3")
			check("the Bestiary whole: +15%% rare fish (%.2f)" % (pr.stat("fish_rare_pct") - rare0), is_equal_approx(pr.stat("fish_rare_pct") - rare0, 0.15))
			return TK.done(fails)
	step += 1
	return false
