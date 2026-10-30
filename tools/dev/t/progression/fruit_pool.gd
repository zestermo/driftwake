extends SceneTree
## The Driftfruits' world pool (1.27, FruitPool): each fruit once per save: a draw reserves a free fruit of its tier for
## everyone; once every fruit of a tier is out, a draw comes up empty; a freed fruit can be drawn again; sell prices by
## tier.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var FP = load("res://scripts/powers/fruit_pool.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var solids: Array = FP.free_of(self, "solid")
	check("free solid fruits the game has (%s)" % [solids], not solids.is_empty())
	var got: Array = []
	for i in range(solids.size()):
		got.append(FP.draw(self, "solid", rng))
	check("each drawn once (%s)" % [got], got.size() == solids.size() and got.all(func(id): return got.count(id) == 1))
	check("...then none left: the draw comes up empty", FP.draw(self, "solid", rng) == "")
	FP.release(self, got[0])
	check("a freed fruit can be drawn again", FP.draw(self, "solid", rng) == got[0])
	check("sell prices by tier (%d, %d)" % [FP.sell_price("wolf"), FP.sell_price("ember")], FP.sell_price("wolf") == 60000 and FP.sell_price("ember") == 200000)
	return TK.done(fails)
