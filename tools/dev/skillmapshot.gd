extends SceneTree
## The skill map (K) on the light stage, a captain part way along (level 6, some cutlass mastery and its
## family's share, Swimming and Seamanship grown): the Captain tree, the cutlass's (a node selected), the LIFE
## tab. Saves <out>_captain.png, <out>_cutlass.png, <out>_life.png. Args: <out_prefix> (default tools/dev/out/skillmap).
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
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": true, "weapon": "cutlass"})


func shot(name_: String) -> void:
	var path := ProjectSettings.globalize_path("%s_%s.png" % [out, name_])
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _process(_d: float) -> bool:
	# (frames, not ticks: the open menu pauses the game)
	until -= 1
	for c in root.find_children("*", "CharacterCreator", true, false):
		c._finish(true)
	if not stage.up or until > 0:
		return false
	match step:
		0:
			var pr = stage.player.progression
			var xp := 0
			for lv in range(1, 6):
				xp += pr.xp_to_next(lv)
			pr.add_xp(xp)
			for id in ["c_agility", "m_geppo", "c_vitality", "v_hardy"]:
				pr.learn(id)
			for i in range(120):
				pr.on_hit()
			for id in ["s_edge", "s_dash", "s_flying"]:
				pr.learn(id)
			pr.add_life("swim", 700)
			pr.add_life("sea", 300)
			# (closing the creator began a new game's story, which locks the map until Vey)
			root.get_node("Story").step = "done"
			var gm = root.get_node("GameMenu")
			gm.open("skills")
			sm = gm._skills
			sm.set_tab("base")
			until = 20
		1:
			shot("captain")
			sm.set_tab("sword")
			sm._sel = "s_flourish"
			until = 20
		2:
			shot("cutlass")
			sm.set_tab("life")
			sm._sel = "sw_born"
			until = 20
		3:
			shot("life")
			quit()
	step += 1
	return false
