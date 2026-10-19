extends SceneTree
## The quick item is saved and loaded; a save from before v1.18 (three quick slots, no quick item) loads with
## its first food or drink as the quick item (a weapon left on an old slot is skipped).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var save
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func rewrite(change: Callable) -> void:
	var d: Dictionary = save._read(save.path())
	change.call(d)
	var f := FileAccess.open(save.path(), FileAccess.WRITE)
	f.store_var(d)
	f.close()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			save = load("res://scripts/game/save_game.gd")
			# (a file of its own: every stage test starting meanwhile wipes the shared test slot)
			save.use_test_file("user://t_quick_save_%d.dat" % OS.get_process_id())
			var inv = p.inventory_component
			inv.add_item(ItemDB.get_item("biscuit"), 2)
			inv.select_quick("biscuit")
			check("saved", save.save(p))
			inv.select_quick("rum")
			check("loaded", save.load_into(p))
			check("the quick item comes back (%s)" % inv.quick, inv.quick == "biscuit")
			rewrite(func(d):
				d.erase("quick")
				d["hotbar"] = ["pistol", "", "biscuit", "rum"])
			inv.select_quick("rum")
			check("an old save loads", save.load_into(p))
			check("...its first food or drink is the quick item (%s)" % inv.quick, inv.quick == "biscuit")
			save.delete()
			return TK.done(fails)
	step += 1
	return false
