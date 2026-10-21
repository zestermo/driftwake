extends SceneTree
## The skill bar across loadouts, on the light stage: a katana in hand, pistols in loadout 2, katana and pistol
## skills on the bar, a cutlass skill whose weapon is in no loadout (greyed) and the pistols' ultimate on R.
## Saves the screen and the bar cropped and scaled x3. Args: <out_prefix>
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var t := 0.0
var step := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "katana"})


func learn(p, skill_id: String) -> void:
	var tree = load("res://scripts/progression/skill_tree.gd")
	for k in tree.nodes().keys():
		if str(tree.get_node_def(k).get("skill", "")) == skill_id:
			p.progression.owned[k] = true
			return


func _process(d: float) -> bool:
	# (a windowed first launch opens the character creator: accept the default captain)
	var cc := load("res://scripts/ui/character_creator.gd")
	for n in root.find_children("*", "", true, false):
		if n.get_script() == cc and n.is_inside_tree():
			n._finish(true)
	if not stage.up:
		return false
	t += d
	if step == 0:
		step = 1
		t = 0.0
		var p = stage.player
		for id in ["wind_sever", "phantom_step", "deadeye", "smoke_bomb", "swordfish", "deaths_waltz", "soru"]:
			learn(p, id)
		p.inventory_component.add_item(ItemDB.get_item("pistol"), 2)
		p.loadouts[1] = ["pistol", "pistol"]
		p.power.equip("wind_sever", 0)
		p.power.equip("phantom_step", 1)
		p.power.equip("deadeye", 2)
		p.power.equip("soru", 3)
		p.power.equip("deaths_waltz", 4)
		p.power.loadout[5] = "swordfish"
		p.power.loadout_changed.emit()
		p.power.energy = p.power.max_energy()
		p.power.ult = 100.0
	elif step == 1 and t > 1.0:
		step = 2
		var out := OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
		var img := root.get_texture().get_image()
		img.save_png(out + "_screen.png")
		var w := img.get_width()
		var h := img.get_height()
		var crop := img.get_region(Rect2i(int(w * 0.31), int(h * 0.86), int(w * 0.38), int(h * 0.14)))
		crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
		crop.save_png(out + "_bar.png")
		print("SAVED")
		quit()
	return false
