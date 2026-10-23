extends SceneTree
## A captain's bounty (Bounty, Net.bounty): a deed in reach raises it by its Bounty.TABLE value (scaled), one out of
## reach doesn't; crossing 5,000 makes them Wanted (the tier), the HUD shows it under the gold, the co-op snapshot
## carries it, and the numbers read with thousands commas.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var board
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var net := root.get_node("Net")
	var B = load("res://scripts/game/bounty.gd")
	match step:
		0:
			p.bounty = 0
			var rng := RandomNumberGenerator.new()
			board = load("res://scripts/island/kit/kit_village.gd").notice_board(rng)
			stage.add_child(board)
			board.global_position = p.global_position + Vector3(0, 0, -4)
			until = TK.wait_secs(2.4)
		1:
			check("no bounty: the notice board's as it was (%d nodes on its poster)" % board.get_node("Wanted").get_child_count(), board.get_node("Wanted").get_child_count() == 0)
			net.bounty("ship", p.global_position + Vector3(10, 0, 0), 60.0)
			check("a ship taken in reach: +1,500 (%d)" % p.bounty, p.bounty == 1500)
			net.bounty("boss", p.global_position + Vector3(200, 0, 0), 60.0)
			check("a boss beaten out of reach: nothing (%d)" % p.bounty, p.bounty == 1500)
			net.bounty("boss", p.global_position, 70.0, 0.4)
			check("a miniboss: 40%% of a boss's (%d)" % p.bounty, p.bounty == 1500 + 2400)
			check("...not wanted yet (%s)" % B.title(p.bounty), B.tier_of(p.bounty) == 0)
			net.bounty("rival", p.global_position, 60.0, 1.0)
			check("a rival crew beaten: Wanted (%d, %s)" % [p.bounty, B.title(p.bounty)], p.bounty == 6900 and B.title(p.bounty) == "Wanted")
			until = TK.wait_secs(2.4)
		2:
			var hud = get_first_node_in_group("hud")
			check("the HUD shows it under the gold ('%s')" % hud.bounty_text(), hud.bounty_text() == "Bounty 6,900  -  Wanted")
			check("...and the co-op snapshot carries it", int(p.net_pack()[12]) == 6900)
			check("numbers read with commas (%s, %s)" % [B.fmt(150000), B.fmt(999)], B.fmt(150000) == "150,000" and B.fmt(999) == "999" and B.fmt(1234567) == "1,234,567")
			check("the tiers climb (%s, %s, %s)" % [B.title(20000), B.title(60000), B.title(150000)],
				B.title(20000) == "Notorious" and B.title(60000) == "Infamous" and B.title(150000) == "Dreaded")
			var texts := []
			for c in board.get_node("Wanted").get_children():
				if c is Label3D:
					texts.append(c.text)
			check("wanted: a poster on the board with their name and bounty (%s)" % str(texts),
				"WANTED" in texts and p.display_name() in texts and "6,900" in texts)
			check("prices: an armourer +15%%, a treasure dealer -8%%, a grocer as ever (%.2f, %.2f, %.2f)" % [B.shop_k("armourer", 6900), B.shop_k("treasure", 6900), B.shop_k("grocer", 6900)],
				is_equal_approx(B.shop_k("armourer", 6900), 1.15) and is_equal_approx(B.shop_k("treasure", 6900), 0.92) and B.shop_k("grocer", 6900) == 1.0)
			p.bounty = 60000
			root.get_node("GameMenu").open_shop("vey")
			until = TK.wait_ticks(2)
		3:
			check("Infamous: the armourer won't serve them (the shop stays shut)", root.get_node("GameMenu")._current != "shop")
			return TK.done(fails)
	step += 1
	return false
