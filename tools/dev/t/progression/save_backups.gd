extends SceneTree
## Save backups (1.26): each save shifts the last copies along (save_N.bak1 newest, SaveGame.BACKUPS of them), so a
## save that won't read (a crash mid-write, a full disk) comes back from the one before.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var SG = load("res://scripts/game/save_game.gd")
	SG.use_test_dir("user://test_backups")
	for k in range(0, 5):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SG.backup_path(1, k)))
	SG.delete_slot(1)
	SG.slot = 1
	SG.new_game = false
	var p = stage.player
	check("a first save writes the file", SG.save(p) and FileAccess.file_exists(SG.slot_path(1)))
	check("...no backup yet (nothing before it)", not FileAccess.file_exists(SG.backup_path(1, 1)))
	SG.save(p)
	SG.save(p)
	check("two more saves: the previous ones kept as backups", FileAccess.file_exists(SG.backup_path(1, 1)) and FileAccess.file_exists(SG.backup_path(1, 2)))
	var f := FileAccess.open(SG.slot_path(1), FileAccess.WRITE)
	f.store_string("not a save")
	f.close()
	check("the save corrupted: it won't read", SG._read(SG.slot_path(1)).is_empty())
	check("...but the newest backup does", not SG._read_backup().is_empty())
	SG.delete_slot(1)
	check("deleting the save takes its backups too", not FileAccess.file_exists(SG.backup_path(1, 1)))
	return TK.done(fails)
