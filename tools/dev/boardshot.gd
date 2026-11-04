extends SceneTree
## 1.30 round 9: a generated island's landing steps and its notice board, with real data. A jungle isle (seed 9100,
## t/quests/_isle.gd) built on the light stage: the objective box at the dock (find the town), in the village (ask the
## elder), with the trouble taken (check the board), then the board's page with some of the island done (part explored,
## places found, a side quest done, a bounty to report, one under way), then the box on the trouble's own step.
## Args: <out dir> [WxH] (default 1280x720: the tightest canvas). Writes board_goal_1..4.png and board_page.png.
const TK := preload("res://tools/dev/test_kit.gd")
const ISLE := preload("res://tools/dev/t/quests/_isle.gd")
var stage
var isl
var p
var j
var out := "res://tools/dev/out/board"
var step := 0
var win := Vector2i(1280, 720)
var until := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	var wh := (a[1] if a.size() > 1 else "1280x720").split("x")
	win = Vector2i(int(wh[0]), int(wh[1]))
	root.size = win
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	TK.seed_of(self)
	stage = TK.stage(self, {})


func shot(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out.path_join(name)))
	print("SAVED ", name)


func _put(at: Vector2) -> void:
	p.global_position = ISLE.world(isl, at) + Vector3.UP * 1.0
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _process(_d: float) -> bool:
	# (frames, not ticks: the board's page pauses the game; a windowed run opens the creator first)
	until -= 1
	for c in root.find_children("*", "CharacterCreator", true, false):
		c._finish(true)
	if not stage.up or until > 0:
		return false
	match step:
		0:
			DisplayServer.window_set_size(win)
			root.size = win
			p = stage.player
			j = root.get_node("Journal")
			j.reset()
			root.get_node("Story").step = "done"
			root.get_node("Dialogue").set_flag("log_pose")
			p.progression.level = 6
			isl = ISLE.build(stage, 9100)
			if stage.hud._tree_card:
				stage.hud._tree_card.visible = false
			_put(isl.sites["dock"] + (isl.sites["village"] - isl.sites["dock"]).normalized() * 12.0)
			until = 90
		1:
			shot("board_goal_1.png")
			_put(isl.sites["village"] + Vector2(3, 3))
			until = 90
		2:
			shot("board_goal_2.png")
			j.take(isl.life.arc.key)
			until = 40
		3:
			shot("board_goal_3.png")
			_progress()
			isl.get_node("Site_village/Village").read_board(p)
			until = 30
		4:
			shot("board_page.png")
			root.get_node("GameMenu").close()
			until = 40
		5:
			shot("board_goal_4.png")
			quit()
	step += 1
	return false


## Some of the island done, as a crew a while in would have it.
func _progress() -> void:
	var R = load("res://scripts/quests/island_record.gd")
	var d = load("res://scripts/map/map_isles.gd").of(isl)
	var land: PackedInt32Array = R.land_cells(d)
	var seen := PackedInt32Array()
	for i in range(land.size()):
		if i % 5 < 2:
			seen.append(land[i])
	var net = root.get_node("Net")
	net.fog_reveal(str(d["key"]), int(d["n"]), seen)
	for s in (d["spots"] as Array).slice(0, 3):
		net.spot_found(str(d["key"]), str(s["id"]), str(s["name"]))
	var q: Dictionary = isl.life.given[0]
	j.take(q["id"])
	j.settle(q["id"])
	if isl.life.given.size() > 1:
		j.take(isl.life.given[1]["id"])
	var notices: Array = isl.life.notices
	j.take(notices[0]["id"])
	net.world_flag("cleared_" + str(notices[0]["id"]))
	j.advance(notices[0]["id"], 0)
	j.take(notices[1]["id"])
	j.track(isl.life.arc.key)
