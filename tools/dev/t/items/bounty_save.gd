extends SceneTree
## The bounty, its log, the personal sea chest and the arena rank come back from a save whatever is in the hand.
## (v1.19 to 1.31 restored them only with an empty hand: a save with a weapon out loaded them as nothing.)
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var save
var gm
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


## Sets the saved things, saves, wipes them, loads, and checks they're back.
func round_trip(hand: String) -> void:
	p.bounty = 150300
	p.bounty_log = [{"why": "commodore", "amount": 25000}]
	p.arena_rank = 3
	p.arena_defended_day = 7
	gm.sea_chest.clear()
	var st := ItemStack.new()
	st.item = ItemDB.get_item("biscuit")
	st.quantity = 4
	gm.sea_chest.append(st)
	check("%s: saved" % hand, save.save(p))
	p.bounty = 0
	p.bounty_log = []
	p.arena_rank = 0
	p.arena_defended_day = -1
	gm.sea_chest.clear()
	check("%s: loaded" % hand, save.load_into(p))
	check("%s: the bounty comes back (%d)" % [hand, p.bounty], p.bounty == 150300)
	check("%s: its log comes back (%d entries)" % [hand, p.bounty_log.size()],
			p.bounty_log.size() == 1 and int(p.bounty_log[0].get("amount", 0)) == 25000)
	check("%s: the arena rank and its defended day come back (%d, day %d)" % [hand, p.arena_rank, p.arena_defended_day],
			p.arena_rank == 3 and p.arena_defended_day == 7)
	check("%s: the personal chest comes back (%d stacks)" % [hand, gm.sea_chest.size()],
			gm.sea_chest.size() == 1 and gm.sea_chest[0].item.id == "biscuit" and gm.sea_chest[0].quantity == 4)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			gm = root.get_node("GameManager")
			save = load("res://scripts/game/save_game.gd")
			# (a file of its own: every stage test starting meanwhile wipes the shared test slot)
			save.use_test_file("user://t_bounty_save_%d.dat" % OS.get_process_id())
			p.equip_weapon(ItemDB.get_item("cutlass"), false)
			check("a weapon is in the hand", p.equipped_weapon != null)
			round_trip("weapon out")
			check("...and the weapon is still in the hand", p.equipped_weapon != null and p.equipped_weapon.id == "cutlass")
			p.unequip_weapon()
			check("the hand is empty", p.equipped_weapon == null)
			round_trip("empty hand")
			save.delete()
			return TK.done(fails)
	step += 1
	return false
