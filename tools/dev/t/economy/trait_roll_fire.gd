extends SceneTree
## An Embered cutlass changes the roll: a plain cutlass's roll leaves nothing behind, an Embered one's leaves a
## trail of fire (FireZone) that burns out after its 3 s.
const TK := preload("res://tools/dev/test_kit.gd")
const ID := "cutlass@2+embered"
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func fires() -> int:
	return get_nodes_in_group("fire_zones").size()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			TK.act("dodge")
			until = TK.wait_ticks(4)
		1:
			check("the plain cutlass rolls", p.current_state_name() == "Dodge")
			until = TK.wait_secs(0.5)
		2:
			check("a plain cutlass's roll leaves no fire", fires() == 0)
			var it: ItemData = ItemDB.get_item(ID)
			p.inventory_component.add_item(it, 1)
			p.equip_weapon(it)
			check("an Embered cutlass in hand", p.equipped_weapon == it and it.weapon_trait == "embered")
			until = TK.wait_secs(0.8)
		3:
			TK.act("dodge")
			until = TK.wait_ticks(4)
		4:
			check("the Embered cutlass rolls", p.current_state_name() == "Dodge")
			until = TK.wait_secs(0.4)
		5:
			check("the Embered roll leaves a trail of fire (%d)" % fires(), fires() >= 2)
			until = TK.wait_secs(3.5)
		6:
			check("the fire burns out", fires() == 0)
			return TK.done(fails)
	step += 1
	return false
