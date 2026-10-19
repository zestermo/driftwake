extends SceneTree
## The crew journal (J) on the light stage, filled with made-up quests and rumours: the objective tracker on
## the HUD, then the journal's Active, Done and Rumours tabs. Args: <out dir> [WxH] (default 1280x720: the
## tightest canvas, 640x360). Writes hud.png, active.png, done.png, rumours.png.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var j
var out := "res://tools/dev/out/journal"
var step := 0
var until := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	var wh := (a[1] if a.size() > 1 else "1280x720").split("x")
	root.size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	TK.seed_of(self)
	stage = TK.stage(self, {"npc": {"name": "Net-mender Kai", "at": Vector3(-6, 0, -14)}})


func entry(id: String, title: String, giver: String, isle: String, src: String, goals: Array, at: int, reward: Dictionary) -> Dictionary:
	return {"id": id, "title": title, "giver": giver, "isle": isle, "pos": Vector3(0, 2, -40), "src": src, "goals": goals, "step": at, "done": false, "reward": reward, "cost": []}


func shot(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out.path_join(name)))
	print("SAVED ", name)


func _process(_d: float) -> bool:
	# (frames, not ticks: the open journal pauses the game; a windowed run opens the creator first)
	until -= 1
	for c in root.find_children("*", "CharacterCreator", true, false):
		c._finish(true)
	if not stage.up or until > 0:
		return false
	match step:
		0:
			DisplayServer.window_set_size(root.size)
			j = root.get_node("Journal")
			j.reset()
			j.apply("take", [entry("q1", "Kai's shell necklace", "Net-mender Kai", "Mokuhala", "npc",
				["Find the shell necklace in the old stones", "Bring the shell necklace back to Kai"], 0, {"gold": 32, "favour": {"who": "Kai", "gift": [["rum", 2]]}})])
			j.apply("take", [entry("q2", "Bounty: Captain Rusk", "Elder Mako", "Mokuhala", "board",
				["Defeat Captain Rusk at the pirate camp", "Bring word to Elder Mako"], 0, {"gold": 60, "discount": ["t", 0.15, "Wiremu's Trade Goods"]})])
			j.apply("take", [entry("q3", "A parcel for Lea", "Healer Hoku", "Mokuhala", "npc",
				["Take a bundle of fever herbs to Lea, at the market stalls", "Tell Hoku it's delivered"], 1, {"gold": 18, "items": [["tonic", 2]]})])
			for e in [entry("q4", "Three fish for Tane", "Carver Tane", "Kalani Reach", "npc", ["Bring three fish to Tane"], 0, {"gold": 35, "reveal": true}),
					entry("q5", "The view from the summit", "Lookout Ari", "Kalani Reach", "npc", ["Climb to the lookout", "Tell Ari what you saw"], 1, {"gold": 22})]:
				j.apply("take", [e])
				j.apply("done", [e["id"], Vector3(9999, 0, 0), 1])
			for r in [["They say Captain Rusk buried something in the jungle before setting up camp.", "Hunter Noa"],
					["The needle pulls toward Ashfall Key next. A sun-baked desert isle, pack light.", "Storyteller Mele"],
					["Something big walks the far side of the island at night. We don't go there.", "Elder Mako"]]:
				j.apply("rumour", [{"text": r[0], "who": r[1], "isle": "Mokuhala"}])
			j.track("q1")
			until = 60
		1:
			shot("hud.png")
			j.open()
			until = 30
		2:
			shot("active.png")
			j.screen.show_tab("done")
			until = 20
		3:
			shot("done.png")
			j.screen.show_tab("rumours")
			until = 20
		4:
			shot("rumours.png")
			quit()
	step += 1
	return false
