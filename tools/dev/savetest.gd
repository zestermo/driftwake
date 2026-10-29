extends SceneTree
## Title screen + save slots: new game, save, quit to title, continue, a second
## slot, loading from the pause menu, deleting.
var t := 0.0
var step := 0
var t0 := 0.0
var fails := 0
var SG
var lv_saved := 0
var was = null
var seen_at := -1
var wall0 := 0


func check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1


func _initialize():
	load("res://tools/dev/test_kit.gd").seed_of(self)
	SG = load("res://scripts/game/save_game.gd")
	SG.use_test_dir("user://test_slots")
	for i in range(1, 4):
		SG.delete_slot(i)
	change_scene_to_file("res://scenes/ui/title_screen.tscn")


func title():
	return root.get_tree().get_first_node_in_group("title_screen")


func player():
	return root.get_tree().get_first_node_in_group("player")


func wait(secs: float) -> bool:
	return t - t0 >= secs


func next() -> void:
	step += 1
	t0 = t
	wall0 = Time.get_ticks_msec()
	was = player()
	seen_at = -1


## A load's world is up (however long that takes under load): a captain who wasn't there before
## the step began, a few frames in (GameManager applies the save two frames after he registers).
func world_ready() -> bool:
	var p = player()
	if p == null or p == was:
		# wall clock: --fixed-fps makes the frame delta run ahead of the loader's thread
		return Time.get_ticks_msec() - wall0 >= 60000
	if seen_at < 0:
		seen_at = Engine.get_process_frames()
	return Engine.get_process_frames() - seen_at >= 5


func _process(d: float) -> bool:
	t += d
	match step:
		0:
			if not wait(1.0): return false
			var ts = title()
			check(ts != null, "title screen is the scene")
			check(ts._continue.disabled, "Continue disabled with no saves")
			check(SG.latest_slot() == 0, "no saves yet")
			ts._open_slots("new")
			check(ts._slots.visible and ts._slots.mode == "new", "New Game shows the slots")
			ts._start(1, true)
			next()
		1:
			if not world_ready(): return false
			var p = player()
			check(p != null and p != was, "world loaded from the title (%.1f s)" % (t - t0))
			check(SG.slot == 1 and SG.new_game, "slot 1, new game")
			check(p.progression.level == 1, "new captain is level 1")
			p.progression.add_xp(500)
			lv_saved = p.progression.level
			root.get_node("GameManager").opened["test_chest"] = true
			check(SG.save(p), "saved")
			check(not SG.new_game, "new_game cleared after the first save")
			var info = SG.slot_info(1)
			check(int(info.get("level", 0)) == lv_saved, "slot 1 shows level %d" % lv_saved)
			check(str(info.get("name", "")) != "", "slot 1 shows the captain's name")
			root.get_node("GameMenu")._quit_to_title()
			next()
		2:
			if not wait(1.5): return false
			var ts = title()
			check(ts != null, "quit to title")
			check(not ts._continue.disabled and ts._continue_slot == 1, "Continue points at slot 1")
			check(player() == null, "no player on the title")
			ts._start(2, true)
			next()
		3:
			if not world_ready(): return false
			var p = player()
			check(p != null and p != was and SG.slot == 2, "new game in slot 2")
			check(p.progression.level == 1, "slot 2 starts at level 1")
			check(root.get_node("GameManager").opened.is_empty(), "world state reset for the new game")
			SG.save(p)
			check(SG.latest_slot() == 2 or SG.slot_info(1)["saved_at"] == SG.slot_info(2)["saved_at"], "slot 2 is the latest")
			root.get_node("GameMenu").open("load")
			check(root.get_node("GameMenu")._load.visible, "pause menu Load shows the slots")
			root.get_node("GameMenu")._load_slot(1)
			next()
		4:
			if not world_ready(): return false
			var p = player()
			check(p != null and p != was and SG.slot == 1, "loaded slot 1 from the pause menu")
			check(p.progression.level == lv_saved, "slot 1 level restored (%d)" % p.progression.level)
			check(root.get_node("GameManager").opened.has("test_chest"), "slot 1 world state restored")
			check(not root.get_tree().paused, "game unpaused after loading")
			SG.delete_slot(2)
			check(SG.slot_info(2).is_empty(), "slot 2 deleted")
			check(SG.format_time(3720.0) == "1h 02m", "play time format")
			var txt = load("res://scripts/ui/save_slot_list.gd").slot_text(1, SG.slot_info(1))
			check("Lv" in txt and "played" in txt, "slot row text: " + txt.replace("\n", " | "))
			# (1.26: unlimited saves) the list, newest first; a new save past the highest number; the row's new lines
			var i1: Dictionary = SG.slot_info(1)
			check(SG.slots().has(1) and SG.first_free_slot() > 1, "the save list has slot 1, a new save goes past it (%d)" % SG.first_free_slot())
			check(str(i1.get("game_version", "")) == str(ProjectSettings.get_setting("application/config/version", "")) and bool(i1.get("compatible", false)), "the save knows its build, and this build can load it (%s)" % i1.get("game_version", ""))
			check(str(i1.get("place", "")) != "", "the save knows where you were (%s)" % i1.get("place", ""))
			for i in range(1, 4):
				SG.delete_slot(i)
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
	return false
