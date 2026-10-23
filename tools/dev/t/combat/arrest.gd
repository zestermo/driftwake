extends SceneTree
## Arrested (AdmiraltyBrig): beaten by an Admiralty squad, the captain wakes in the brig's cell on their feet, a share
## of their gold and their weapon taken, two guards at their posts behind the shut door; picking the lock opens it and
## sets the guards on; the chest gives the weapon back; the hatch puts them back where they were taken and the brig
## goes. Arrested again and downed in there: back in the cell, the door shut.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var e
var b
var gold0 := 0
var taken_at := Vector3.ZERO
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


func brig() -> Script:
	return load("res://scripts/ai/admiralty_brig.gd")


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var net := root.get_node("Net")
	match step:
		0:
			root.get_node("GameManager").rivals.clear()
			p.inventory_component.add_item(ItemDB.get_item("gold"), 100)
			gold0 = p.inventory_component.count("gold")
			var cut := ItemDB.get_item("cutlass")
			if p.equipped_weapon == null:
				p.inventory_component.add_item(cut, 1)
				p.equip_weapon(cut, false)
			taken_at = p.global_position
			e = load("res://scripts/ai/rival_encounter.gd").start(p, "hollow")
			until = TK.wait_secs(0.3)
		1:
			TK.act("interact")
			until = TK.wait_ticks(4)
		2:
			var hd := HitData.new()
			hd.damage = 99999.0
			p.hurtbox.take_hit(hd, e.rivals[0])
			until = TK.wait_secs(1.0)
		3:
			b = brig().of(self)
			check("beaten by the Admiralty: arrested, in the brig's cell on their feet", b != null and p.global_position.distance_to(b.to_global(b.CELL)) < 2.5 and p.current_state_name() != "Downed")
			check("...%d gold confiscated, the weapon taken" % (gold0 - p.inventory_component.count("gold")),
				p.inventory_component.count("gold") == gold0 - int(floor(gold0 * 0.3)) and p.equipped_weapon == null and p.inventory_component.count("cutlass") == 0)
			check("...two guards at their posts, the door shut, the squad gone", b.guards.size() == 2 and b.guards.all(func(g): return g.get_node("Brain").order == "hold")
				and not b.door_open and get_first_node_in_group("rival_encounter") == null)
			b._pick(p)
			until = TK.wait_secs(3.5)
		4:
			check("the lock picked: the door opens, the guards come on", b.door_open and b.guards.all(func(g): return g.get_node("Brain").order == "fight") and not p.input_locked)
			b._gear(p)
			check("the chest: the weapon back in hand", p.equipped_weapon != null and p.equipped_weapon.id == "cutlass")
			b._out(p)
			until = TK.wait_secs(1.5)
		5:
			check("the hatch: back where they were taken, and the brig's gone", p.global_position.distance_to(taken_at) < 3.0 and brig().of(self) == null)
			net._all_arrest(p.global_position, "Captain Bertrand Hollow")
			until = TK.wait_secs(0.5)
		6:
			b = brig().of(self)
			net._all_brig_door(true)
			var hd := HitData.new()
			hd.damage = 99999.0
			p.hurtbox.take_hit(hd, b.guards[0])
			until = TK.wait_secs(1.5)
		7:
			check("arrested again and downed in the brig: back in the cell, the door shut (%s)" % p.current_state_name(),
				not b.door_open and p.global_position.distance_to(b.to_global(b.CELL)) < 2.5 and p.current_state_name() != "Downed")
			return TK.done(fails)
	step += 1
	return false
