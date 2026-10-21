extends SceneTree
## The skills menu (K) on the light stage, a captain part way along: level 12, katana mastery 14 with some steps
## bought, cutlass 7 and pistol 6, Swimming and Sailing found, the Vine Fruit eaten, katana and pistol loadouts, three
## katana skills on the bar and a katana passive slotted. Saves <out>_captain, _combat (the katana tree, Wind Severer
## inspected), _variant (the iai upgrade inspected), _chart, _adventure, _loadout, _fruit, _pistol PNGs.
## Args: <out_prefix> [WxH] (default tools/dev/out/skillmap at 1280x720, the 640x360 canvas; 1600x900 is 800x450).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var out := "res://tools/dev/out/skillmap"
var step := 0
var until := 0
var sm


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
	if args.size() > 1:
		var wh := args[1].split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		root.size = Vector2i(int(wh[0]), int(wh[1]))
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": true, "weapon": "katana"})


func shot(name_: String) -> void:
	var path := ProjectSettings.globalize_path("%s_%s.png" % [out, name_]) if out.begins_with("res://") else "%s_%s.png" % [out, name_]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func mastery(pr, tree: String, lv: int) -> void:
	pr.mastery_of(tree)["lv"] = lv - 1
	pr.mastery_of(tree)["xp"] = 0
	pr.add_mastery(tree, pr.mastery_to_next(lv - 1))


func _process(_d: float) -> bool:
	# (frames, not ticks: the open menu pauses the game)
	until -= 1
	for c in root.find_children("*", "CharacterCreator", true, false):
		c._finish(true)
	if not stage.up or until > 0:
		return false
	match step:
		0:
			var p = stage.player
			var pr = p.progression
			var xp := 0
			for lv in range(1, 12):
				xp += pr.xp_to_next(lv)
			pr.add_xp(xp)
			mastery(pr, "katana", 14)
			mastery(pr, "sword", 7)
			mastery(pr, "pistol", 6)
			mastery(pr, "swim", 6)
			mastery(pr, "sea", 9)
			mastery(pr, "acrobatics", 8)
			mastery(pr, "defense", 5)
			for k in ["k_keen", "k_keen", "k_keen", "k_keen", "k_keen", "k_nerves", "k_deep", "k_deep", "k_deep", "k_feet", "k_feet"]:
				pr.buy_step(k)
			p.power.eat("vine")
			p.loadouts[0] = ["katana", ""]
			p.loadouts[1] = ["pistol", ""]
			p.inventory_component.add_item(ItemDB.get_item("pistol"), 1)
			for s in [["wind_sever", 0], ["tiger_rush", 1], ["phantom_step", 2]]:
				p.power.equip(s[0], s[1])
			pr.equip_passive("k_clean", 0)
			pr.grant_will("h_arm")
			pr.pick_talent(5, 0)
			pr.pick_talent(10, 1)
			# (closing the creator began a new game's story, which locks the menu until Vey)
			root.get_node("Story").step = "done"
			var gm = root.get_node("GameMenu")
			gm.open("skills")
			sm = gm._skills
			sm.set_tab("captain")
			until = 20
		1:
			shot("captain")
			sm.set_tab("combat", "katana")
			sm.sel = "n:k_wind"
			until = 20
		2:
			shot("combat")
			sm.sel = "n:k_iai"
			until = 10
		3:
			shot("variant")
			sm.chart = true
			sm.sel = "w:katana"
			until = 20
		4:
			shot("chart")
			sm.chart = false
			sm.set_tab("adventure", "acrobatics")
			until = 20
		5:
			shot("adventure")
			sm.set_tab("loadout")
			sm.sel = "lib:tiger_rush"
			until = 20
		6:
			shot("loadout")
			sm.set_tab("fruit")
			until = 20
		7:
			shot("fruit")
			sm.set_tab("combat", "pistol")
			until = 20
		8:
			shot("pistol")
			quit()
	step += 1
	return false
