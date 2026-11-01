extends SceneTree
## Sea stops are rolled per leg from the chain (Chain.sea_stop): none on the first two legs, more often later in the
## chain, never on every leg, the same roll again for the same chain, every kind turns up across chains, and the
## Admiralty lieutenant comes more often to a crew with a bigger bounty.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
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


func _legs(c) -> Array:
	var out: Array = []
	for id in c.next_of(-1):
		out.append([-1, int(id)])
	for n in c.nodes:
		for id in c.next_of(int(n["id"])):
			out.append([int(n["id"]), int(id)])
	return out


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var early := 0
	var early_legs := 0
	var late := 0
	var late_legs := 0
	var mid := 0
	var mid_legs := 0
	var kinds := {}
	var lieu := [0, 0]
	var same := true
	var all_stops := 0
	var all_legs := 0
	for s in range(60):
		var c = load("res://scripts/world/chain.gd").make(1000 + s * 7919, Vector2(150, 150), Vector2(1, 0.2))
		for leg in _legs(c):
			var layer := int(c.node(leg[1])["layer"])
			var k: String = c.sea_stop(leg[0], leg[1], 0)
			same = same and k == c.sea_stop(leg[0], leg[1], 0)
			all_legs += 1
			if k != "":
				all_stops += 1
				kinds[k] = true
			if layer <= 2:
				early_legs += 1
				early += int(k != "")
			elif layer <= 5:
				mid_legs += 1
				mid += int(k != "")
			else:
				late_legs += 1
				late += int(k != "")
			lieu[0] += int(k == "lieutenant")
			lieu[1] += int(c.sea_stop(leg[0], leg[1], 4) == "lieutenant")
	print("   early %d/%d, mid %d/%d, late %d/%d, lieutenants %d at tier 0, %d at tier 4" % [early, early_legs, mid, mid_legs, late, late_legs, lieu[0], lieu[1]])
	check("no stop on the first two legs of a chain", early == 0)
	check("stops turn up mid-chain", mid > 0)
	check("...and more often late in the chain", float(late) / late_legs > float(mid) / mid_legs)
	check("never on every leg (well under half overall)", all_stops < all_legs * 0.5)
	check("the same leg rolls the same stop again", same)
	check("every kind of stop turns up across chains", kinds.size() == 4)
	check("the lieutenant comes more often to a wanted crew", lieu[1] > lieu[0] + 3)
	return TK.done(fails)
