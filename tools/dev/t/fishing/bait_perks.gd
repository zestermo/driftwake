extends SceneTree
## Bait and Fishing's perks: with no bait picked the best carried goes on the hook; a click in the bag picks one
## (marked B, saved); worms bring bites sooner; a landed catch uses one up, Bait Saver keeps some; Cut bait on the
## action wheel turns a crab into shrimp bait. Fishing's perks are bought at their levels (Bait Saver at 8, Master Angler
## at 20) and are read: the window, the legendary odds.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var inv
var gm
var save
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


func give(id: String, n: int) -> void:
	inv.add_item(ItemDB.get_item(id), n)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			inv = p.inventory_component
			gm = root.get_node("GameMenu")
			save = load("res://scripts/game/save_game.gd")
			save.use_test_file("user://t_bait_perks_%d.dat" % OS.get_process_id())
			check("no bait: a bare hook", inv.bait_on() == "")
			give("bait_worm", 10)
			give("bait_shrimp", 3)
			check("none picked: the best carried goes on (%s)" % inv.bait_on(), inv.bait_on() == "bait_shrimp")
			gm.open("inventory")
			until = TK.wait_ticks(4)
		1:
			var ui = gm._inventory
			var cell: int = ui._view.find(inv.find_index("bait_worm"))
			ui._click_bag(cell, false)
			check("a click on the worms puts them on the hook (%s)" % inv.bait_on(), inv.bait_on() == "bait_worm")
			cell = ui._view.find(inv.find_index("bait_worm"))
			check("...marked B in the bag", ui._bag[cell].key.text == "B")
			gm.close()
			var F = load("res://scripts/fishing/fishing.gd")
			seed(3)
			var b0: float = F.bite_secs(p, "driftwood", "")
			seed(3)
			var b1: float = F.bite_secs(p, "driftwood", "bait_worm")
			check("worms bring bites sooner (%.1f -> %.1f s)" % [b0, b1], b1 < b0 * 0.85)
			F.land(p, "fish_sardine", "bait_worm")
			check("a landed catch uses one up (%d left)" % inv.count("bait_worm"), inv.count("bait_worm") == 9)
			check("the pick is saved", save.save(p))
			inv.select_bait("")
			check("...and loads", save.load_into(p) and inv.bait == "bait_worm")
			var pr = p.progression
			while pr.mastery_level("fish") < 8:
				pr.add_life("fish", pr.mastery_to_next(pr.mastery_level("fish")))
			pr.buy("fs_saver")
			check("Bait Saver bought at Fishing 8 (%.2f, %s)" % [pr.stat("fish_bait_save"), pr.buy_why("fs_saver")], pr.owned.has("fs_saver") and pr.stat("fish_bait_save") > 0.0)
			give("bait_worm", 30)
			var had: int = inv.count("bait_worm")
			for i in range(30):
				F.land(p, "fish_sardine", "bait_worm")
				inv.remove_item(ItemDB.get_item("fish_sardine"), inv.count("fish_sardine"))
			var used: int = had - inv.count("bait_worm")
			check("...keeps the bait now and then (%d used for 30 catches)" % used, used < 30 and used > 10)
			var w0: float = F.window(p, "driftwood")
			while pr.mastery_level("fish") < 20:
				pr.add_life("fish", pr.mastery_to_next(pr.mastery_level("fish")))
			pr.buy("fs_master")
			check("Master Angler at Fishing 20: twice the legendary odds and a longer window (%.2f -> %.2f s)" % [w0, F.window(p, "driftwood")],
				pr.owned.has("fs_master") and is_equal_approx(pr.stat("fish_legend"), 1.0) and F.window(p, "driftwood") > w0)
			var AW = load("res://scripts/game/action_wheel.gd")
			for id in ["fish", "crab_meat", "sea_urchin"]:
				inv.remove_item(ItemDB.get_item(id), inv.count(id))
			check("Cut bait greyed with nothing to cut (%s)" % AW.why_not("cut_bait", p), AW.why_not("cut_bait", p) != "")
			give("crab_meat", 1)
			var shrimp: int = inv.count("bait_shrimp")
			check("...a crab to cut", AW.why_not("cut_bait", p) == "")
			AW.run("cut_bait", p)
			check("Cut bait: the crab into 3 shrimp bait", inv.count("crab_meat") == 0 and inv.count("bait_shrimp") == shrimp + 3)
			save.delete()
			return TK.done(fails)
	step += 1
	return false
