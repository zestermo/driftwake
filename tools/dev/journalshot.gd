extends SceneTree
## The Captain's Log (J) on the light stage, filled with made-up quests, news and rumours, a real chain for the chain's
## step: the HUD (the objective box, a pinned card, small news), then the log's NEXT, QUESTS, NEWS and DONE tabs.
## Args: <out dir> [WxH] (default 1280x720: the tightest canvas, 640x360). Writes hud/next/quests/news/done.png.
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
	stage = TK.stage(self, {"npc": {"name": "Net-mender Kai", "at": Vector3(-6, 0, -14)}, "grunts": [{"post": Vector3(1.5, 0, -5.0), "role": "sword", "seed": 71}]})


func entry(id: String, title: String, giver: String, isle: String, src: String, goals: Array, at: int, reward: Dictionary, by := 1) -> Dictionary:
	return {"id": id, "title": title, "giver": giver, "isle": isle, "pos": Vector3(30, 2, -60 - at * 30), "src": src, "goals": goals, "step": at,
		"done": false, "reward": reward, "cost": [], "by": by}


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
			root.get_node("Story").step = "done"
			load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			root.get_node("Dialogue").set_flag("log_pose")
			stage.player.progression.level = 8
			root.get_node("GameManager").play_time = 900.0
			j.apply("take", [entry("q1", "Kai's shell necklace", "Net-mender Kai", "Mokuhala", "npc",
				["Find the shell necklace in the old stones", "Bring the shell necklace back to Kai"], 0, {"gold": 32, "favour": {"who": "Kai", "gift": [["rum", 2]]}})])
			j.apply("take", [entry("q2", "Bounty: Captain Rusk", "Elder Mako", "Mokuhala", "board",
				["Defeat Captain Rusk at the pirate camp", "Bring word to Elder Mako"], 0, {"gold": 60, "discount": ["t", 0.15, "Wiremu's Trade Goods"]})])
			j.apply("take", [entry("q3", "The Queen's line", "Queen Ilsabet", "Port Solenne", "line",
				["Find the Guild's forger", "Tell Queen Ilsabet it's done", "Bring the writ to Saint Odran's Rock"], 2, {"xp": 0.0, "note": "the Crown's purse and favour"}, 0)])
			for e in [entry("q4", "Three fish for Tane", "Carver Tane", "Kalani Reach", "npc", ["Bring three fish to Tane"], 0, {"gold": 35, "reveal": true}),
					entry("q5", "The view from the summit", "Lookout Ari", "Kalani Reach", "npc", ["Climb to the lookout", "Tell Ari what you saw"], 1, {"gold": 22})]:
				j.apply("take", [e])
				j.apply("done", [e["id"], Vector3(9999, 0, 0), 1, []])
			for r in [["They say Captain Rusk buried something in the jungle before setting up camp.", "Hunter Noa"],
					["The needle pulls toward Ashfall Key next. A sun-baked desert isle, pack light.", "Storyteller Mele"]]:
				j.apply("rumour", [{"text": r[0], "who": r[1], "isle": "Mokuhala"}])
			j.seen()
			j.track("q3")
			stage.hud.pin_news("rival", "The Lantern Saints have anchored off the harbour", "Their captain is asking for you by name.")
			stage.hud.show_toast("+40 gold  -  arena purse")
			stage.hud.show_toast("Katana mastery 19")
			# (an engaged foe: its bar and marker)
			for g in stage.camp.grunts:
				g.health.current_health = g.health.max_health * 0.4
				g.state = g.S.CHASE
				g.process_mode = Node.PROCESS_MODE_DISABLED
			until = 37
		1:
			# (the stage's own "new skill tree" card is in the way of the shot)
			if stage.hud._tree_card:
				stage.hud._tree_card.visible = false
			until = 3
		2:
			shot("hud.png")
			j.open()
			until = 30
		3:
			shot("next.png")
			j.screen.show_tab("quests")
			until = 20
		4:
			shot("quests.png")
			j.screen.show_tab("news")
			until = 20
		5:
			shot("news.png")
			j.screen.show_tab("done")
			until = 20
		6:
			shot("done.png")
			quit()
	step += 1
	return false
