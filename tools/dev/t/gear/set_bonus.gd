extends SceneTree
## Named sets (1.24): all three corsair pieces give an air step (two don't); all three Admiralty pieces hit anyone in
## the Admiralty's grey 10% harder, and no one else.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": true})


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
			var gear = load("res://scripts/loot/gear.gd")
			var gs = load("res://scripts/items/gear_stats.gd")
			p.equipment.clear()
			p.refresh_look()
			var j0: int = p.max_jumps
			p.equipment.equip(gear.make("head", "tricorn", {"hat": "tricorn"}, "", 0))
			p.equipment.equip(gear.make("coat", "captain", {"coat": "captain"}, "", 0))
			p.refresh_look()
			check("two corsair pieces: no air step", p.max_jumps == j0)
			p.equipment.equip(gear.make("feet", "tall_boots", {"feet": "tall_boots"}, "", 1))
			p.refresh_look()
			check("the third: +1 air step (%d -> %d)" % [j0, p.max_jumps], p.max_jumps == j0 + 1)
			p.equipment.clear()
			for e in [["head", "bicorne", {"hat": "bicorne"}], ["coat", "admiral", {"coat": "admiral"}], ["feet", "cavalier_boots", {"feet": "cavalier_boots"}]]:
				p.equipment.equip(gear.make(e[0], e[1], e[2], "", 0))
			p.refresh_look()
			var holder := GDScript.new()
			holder.source_code = "extends Node\nvar look := {}\n"
			holder.reload()
			var lk := {}
			load("res://scripts/ship/enemy_ship.gd").marine_look(lk, RandomNumberGenerator.new(), false)
			var foe = holder.new()
			foe.look = lk
			var pirate = holder.new()
			pirate.look = {"name": "Pirate"}
			check("Admiralty set: +10%% on a marine (%.2f)" % gs.versus(p, foe), is_equal_approx(gs.versus(p, foe), 1.1))
			check("...not on a pirate", is_equal_approx(gs.versus(p, pirate), 1.0))
			p.equipment.unequip("feet")
			p.refresh_look()
			check("two pieces: nothing", is_equal_approx(gs.versus(p, foe), 1.0))
			foe.free()
			pirate.free()
			return TK.done(fails)
	step += 1
	return false
