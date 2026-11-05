extends SceneTree
## (1.30.1) Whole skill trees for judging their layout: the skills menu on the light stage, each tree's map centred on
## its root at one zoom, a level-12 captain with a little mastery. Args: <out_prefix> [WxH] [zoom] [trees, e.g.
## katana,acrobatics,vine] (default tools/dev/out/smfull at 1920x1080, zoom 0.8, katana,polearm,acrobatics,vine,defense).
## Writes <out>_<tree>.png.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var out := "res://tools/dev/out/smfull"
var zoom := 0.8
var trees := ["katana", "polearm", "acrobatics", "vine", "defense"]
var step := 0
var until := 0
var i := 0
var sm


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
	if args.size() > 1:
		var wh := args[1].split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		root.size = Vector2i(int(wh[0]), int(wh[1]))
	if args.size() > 2:
		zoom = float(args[2])
	if args.size() > 3:
		trees = Array(args[3].split(","))
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": true, "weapon": "katana"})


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
			for lv in range(1, 12):
				xp += pr.xp_to_next(lv)
			pr.add_xp(xp)
			stage.player.power.eat("vine")
			root.get_node("Story").step = "done"
			var gm = root.get_node("GameMenu")
			gm.open("skills")
			sm = gm._skills
			until = 10
		1:
			if i >= trees.size():
				quit()
				return false
			var t: String = trees[i]
			var sec: String = SkillTrees.section_of(t)
			sm.set_tab("combat" if sec == "combat" else sec, t)
			sm._map_tree = t
			sm._map_k = zoom
			sm._map_pan = Vector2.ZERO
			sm.sel = "n:" + str(SkillTrees.tree_def(t)["root"])
			until = 12
			step = 2
			return false
		2:
			var path := ProjectSettings.globalize_path("%s_%s.png" % [out, trees[i]]) if out.begins_with("res://") else "%s_%s.png" % [out, trees[i]]
			root.get_texture().get_image().save_png(path)
			print("saved ", path)
			i += 1
			step = 1
			return false
	step += 1
	return false
