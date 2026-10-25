extends SceneTree
## The economy's loot is scarce (1.22's tables): 60% of kills that carry coins pay (~45% of the creature's table,
## at least one), a drop as often as its table says; a landmark chest keeps ~45% of its gold, ~35% of its treasure
## and its weapon ~25% of the time (a boss's hoard always), rolled round the island's tier with no traits below
## purple and nothing past blue on a blue island; Brinehollow's own chests a random pistol, cutlass, dagger or
## hatchet, mostly green. Prints the averages.
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
	check("a kill's coins: 60%% pay, ~45%% of its table (%.2f of 10)" % avg, absf(avg - 2.7) < 0.3)
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
	check("a creature's trophy part a third as often as its table says (%.3f of 0.5)" % (tusks / float(N)), absf(tusks / float(N) - 0.15) < 0.03)
	var paid := 0
	var zero := 0
	for i in range(1000):
		var g: int = LOOT.kill_gold(1)
		paid += 1 if g >= 1 else 0
		zero += 1 if g < 0 else 0
	check("~60%% of kills with coins pay, at least one when they do (%.2f)" % (paid / 1000.0), absf(paid / 1000.0 - 0.6) < 0.06 and zero == 0 and LOOT.kill_gold(0) == 0)
	var cg := 0
	var ct := 0
	var cw := 0
	var traited := 0
	var top := 0
	var hoard_w := 0
	var M := 400
	for i in range(M):
		var c = LOOT.chest(stacks([["gold", 20], ["treasure", 2], ["cutlass@2", 1]]), "isle3_test_%d" % i, false)
		cg += count(c, func(it): return it.id == "gold")
		ct += count(c, func(it): return it.id == "treasure")
		var w := count(c, func(it): return it.is_weapon())
		cw += w
		for st in c:
			if st.item.is_weapon():
				top = maxi(top, int(st.item.rarity))
				if st.item.weapon_trait != "":
					traited += 1
		var h = LOOT.chest(stacks([["gold", 80], ["cutlass@3", 1]]), "isle3_hoard_%d" % i, false)
		hoard_w += count(h, func(it): return it.is_weapon())
	print("   chest of 20 gold, 2 treasure, a blue cutlass: %.2f gold, %.2f treasure, weapon %.2f" % [cg / float(M), ct / float(M), cw / float(M)])
	check("a chest keeps ~45%% of its gold (%.1f of 20)" % (cg / float(M)), absf(cg / float(M) - 9.0) < 1.0)
	check("...~35%% of its treasure (%.2f of 2)" % (ct / float(M)), absf(ct / float(M) - 0.7) < 0.12)
	check("...and its weapon ~25%% of the time (%.2f)" % (cw / float(M)), absf(cw / float(M) - 0.25) < 0.06)
	check("on a blue island: no traits, nothing past blue (%d traited, best %d)" % [traited, top], traited == 0 and top <= 2)
	check("a boss's hoard always keeps its weapon", hoard_w == M)
	var kinds := {}
	var blue := 0
	var always := true
	for i in range(300):
		var placed = LOOT.chest(stacks([["gold", 3], ["pistol@2", 1]]), "den_strongbox_%d" % i, true)
		var ws: Array = placed.filter(func(st): return st.item.is_weapon())
		if ws.size() != 1:
			always = false
			continue
		kinds[ws[0].item.weapon_model] = true
		blue += 1 if int(ws[0].item.rarity) == 2 else 0
	check("Brinehollow's chests: always a weapon, of several kinds (%s), ~15%% blue (%.2f)" % [kinds.keys(), blue / 300.0],
		always and kinds.size() >= 3 and absf(blue / 300.0 - 0.15) < 0.06)
	var never_empty := true
	for i in range(100):
		if LOOT.chest(stacks([["treasure", 1]]), "isle1_t_%d" % i, false).is_empty():
			never_empty = false
	check("a rolled chest is never empty", never_empty)
	return TK.done(fails)
