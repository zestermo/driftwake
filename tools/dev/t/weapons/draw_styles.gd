extends SceneTree
## Each weapon kind draws and puts away its own way with its own sound: blades, the katana, axes (from the back),
## the great axe, daggers, and the pistol (spun before it's holstered).
const TK := preload("res://tools/dev/test_kit.gd")
## item, draw style (DrawMoves.kind), its draw sound, its sheathe sound
const KINDS := [["cutlass", "blade", "draw_blade", "sheathe_blade"], ["katana", "katana", "draw_katana", "sheathe_katana"],
	["boarding_axe", "axe", "draw_axe", "sheathe_axe"], ["war_axe", "great", "draw_great", "sheathe_great"],
	["dagger", "dagger", "draw_dagger", "sheathe_dagger"], ["pistol", "pistol", "draw_pistol", "holster"]]
var stage
var p
var heard: Array = []
var wi := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	node_added.connect(func(n): if n is AudioStreamPlayer3D: heard.append(n.stream))
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func was_heard(sound: String) -> bool:
	return heard.has(root.get_node("FX")._streams[sound])


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var k: Array = KINDS[wi]
	var b = stage.player.body_model
	match step:
		0:
			p = stage.player
			var it = ItemDB.get_item(k[0])
			p.inventory_component.add_item(it, 1)
			p.equip_weapon(it, false)
			until = TK.wait_secs(0.4)
		1:
			if k[1] in ["axe", "great"]:
				check("%s: sheathed on the back" % k[0], b.weapon.get_parent().name == "BackSocket")
			heard.clear()
			TK.act("ready_weapon")
			until = TK.wait_ticks(4)
		2:
			check("%s: drawn its own way (%s / %s)" % [k[0], b.current_action(), DrawMoves.kind(b)], b.current_action() == "draw" and DrawMoves.kind(b) == k[1])
			until = TK.wait_secs(0.6)
		3:
			check("%s: in hand, with its sound (%s)" % [k[0], k[2]], b.weapon_in_hand and was_heard(k[2]))
			heard.clear()
			TK.act("ready_weapon")
			until = TK.wait_secs(0.7)
		4:
			check("%s: put away, with its sound (%s)" % [k[0], k[3]], not b.weapon_in_hand and was_heard(k[3]))
			if k[0] == "pistol":
				check("...spun before it's holstered", was_heard("gun_spin"))
			wi += 1
			if wi == KINDS.size():
				return TK.done(fails)
			step = 0
			return false
	step += 1
	return false
