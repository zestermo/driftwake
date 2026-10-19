extends SceneTree
## Screens of the player menu and a duel on the light stage, a stand-in crewmate 2 m ahead: the F prompt, the
## menu, Inspect (with an item card), their challenge, the countdown, the fight (the boss bar), Victory.
## Args: <out_prefix> (e.g. res://tools/dev/out/duel/d)
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var menu
var duel
var out := ""
var step := 0
var until := 0
var shots := ["prompt", "menu", "inspect", "challenge", "countdown", "fight", "victory"]


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	TK.seed_of(self)
	stage = TK.stage(self, {"crew": [{"name": "Red Hand Rook", "at": Vector3(0, 0, -2)}]})


func shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%02d_%s.png" % [out, shots.find(n), n])
	print("shot ", n)


func _process(_d: float) -> bool:
	# (with a window a new game opens the creator first)
	for n in root.find_children("*", "CharacterCreator", true, false):
		n._finish(true)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			mate = stage.crew[0]
			menu = p.get_node("PlayerMenu")
			duel = Duel.inst
			mate.equipped_weapon = ItemDB.get_item("katana")
			var gear: Dictionary = Gear.items_from_look(p.appearance)
			for slot in gear.keys():
				if slot != "extra":
					mate.equipment.equip(gear[slot], slot)
			mate.inventory_component.add_item(ItemDB.get_item("rum"), 3)
			mate.inventory_component.quick = "rum"
			mate.progression.level = 7
			mate.player_model.rotation.y = PI
			p.player_model.rotation.y = 0.0
			until = TK.wait_secs(0.6)
		1:
			shot("prompt")
			menu.open_for(mate)
			until = TK.wait_secs(0.3)
		2:
			shot("menu")
			menu.choose("inspect")
			until = TK.wait_ticks(4)
		3:
			var s = menu._inspect._slots["weapon"]
			menu._inspect._hover("weapon", s)
			until = TK.wait_secs(0.3)
		4:
			shot("inspect")
			menu.close()
			duel._challenge(mate.net_id, 1)
			until = TK.wait_secs(0.4)
		5:
			shot("challenge")
			duel.answer(true)
			until = TK.wait_ticks(8)
		6:
			shot("countdown")
			until = TK.wait_secs(Duel.COUNTDOWN)
		7:
			mate.health_component.current_health = 46.0
			until = TK.wait_ticks(10)
		8:
			shot("fight")
			mate.health_component.current_health = 0.0
			until = TK.wait_ticks(12)
		9:
			shot("victory")
			print("RESULT OK")
			return true
	step += 1
	return false
