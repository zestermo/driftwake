extends SceneTree
## The economy's loot is scarce: a kill's coins come to ~45% of the creature's table (never none), a grunt
## drops a pistol ~6% of the time, a part as often as its table says; a landmark chest keeps ~45% of its
## gold, ~35% of its treasure and its weapon ~30% of the time (a boss's hoard always), and a kept blue weapon
## carries a trait. Prints the averages.
const TK := preload("res://tools/dev/test_kit.gd")
const N := 3000
var stage
var step := 0
var fails := 0
var LOOT


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})
	LOOT = load("res://scripts/items/loot.gd")


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func stacks(e: Array) -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for x in e:
		var st := ItemStack.new()
		st.item = ItemDB.get_item(str(x[0]))
		st.quantity = int(x[1])
		out.append(st)
	return out


func count(c: Array[ItemStack], pred: Callable) -> int:
	var n := 0
	for st in c:
		if pred.call(st.item):
			n += st.quantity
	return n


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var gold := 0
	for i in range(N):
		gold += LOOT.kill_gold(10)
	var avg := gold / float(N)
	print("   kill coins from a table of 10: %.2f" % avg)
	check("a kill's coins are ~45%% of its table (%.2f of 10)" % avg, absf(avg - 4.5) < 0.3)
	var pistols := 0
	var tusks := 0
	for i in range(N):
		for e in LOOT.roll_drops([["pistol", 0.06, 1], ["tusk", 0.5, 1]]):
			if str(e[0][1]) == "pistol":
				pistols += 1
			else:
				tusks += 1
	print("   pistol %.3f, tusk %.3f" % [pistols / float(N), tusks / float(N)])
	check("a grunt's pistol drops ~6%% of the time (%.3f)" % (pistols / float(N)), absf(pistols / float(N) - 0.06) < 0.015)
	check("a creature's part drops as often as its table says (%.3f of 0.5)" % (tusks / float(N)), absf(tusks / float(N) - 0.5) < 0.04)
	var ones := 0
	for i in range(200):
		if LOOT.kill_gold(1) >= 1:
			ones += 1
	check("a kill with coins always gives at least one", ones == 200 and LOOT.kill_gold(0) == 0)
	var cg := 0
	var ct := 0
	var cw := 0
	var traited := 0
	var hoard_w := 0
	var M := 400
	for i in range(M):
		var c = LOOT.chest(stacks([["gold", 20], ["treasure", 2], ["cutlass@2", 1]]), "isle3_test_%d" % i, false)
		cg += count(c, func(it): return it.id == "gold")
		ct += count(c, func(it): return it.id == "treasure")
		var w := count(c, func(it): return it.is_weapon())
		cw += w
		for st in c:
			if st.item.is_weapon() and st.item.weapon_trait != "" and int(st.item.rarity) == 2:
				traited += 1
		var h = LOOT.chest(stacks([["gold", 80], ["cutlass@3", 1]]), "isle3_hoard_%d" % i, false)
		hoard_w += count(h, func(it): return it.is_weapon())
	print("   chest of 20 gold, 2 treasure, a blue cutlass: %.2f gold, %.2f treasure, weapon %.2f" % [cg / float(M), ct / float(M), cw / float(M)])
	check("a chest keeps ~45%% of its gold (%.1f of 20)" % (cg / float(M)), absf(cg / float(M) - 9.0) < 1.0)
	check("...~35%% of its treasure (%.2f of 2)" % (ct / float(M)), absf(ct / float(M) - 0.7) < 0.12)
	check("...and its weapon ~30%% of the time (%.2f)" % (cw / float(M)), absf(cw / float(M) - 0.3) < 0.07)
	check("every blue weapon kept carries a trait", traited == cw)
	check("a boss's hoard always keeps its weapon", hoard_w == M)
	var placed = LOOT.chest(stacks([["gold", 3], ["boarding_axe", 1]]), "ruins_chest", true)
	check("a hand-placed home chest keeps its weapon", count(placed, func(it): return it.id == "boarding_axe") == 1)
	var never_empty := true
	for i in range(100):
		if LOOT.chest(stacks([["treasure", 1]]), "isle1_t_%d" % i, false).is_empty():
			never_empty = false
	check("a rolled chest is never empty", never_empty)
	return TK.done(fails)
