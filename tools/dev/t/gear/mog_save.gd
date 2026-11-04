extends SceneTree
## (1.30) Transmog is saved with the captain's gear: the cosmetic pieces and which slots are mogged load back, and a
## save from before transmog (no "worn_mog" / "mog") loads with every slot unmogged.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var gear
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			gear = load("res://scripts/loot/gear.gd")
			save = load("res://scripts/game/save_game.gd")
			save.use_test_file("user://t_mog_save_%d.dat" % OS.get_process_id())
			var eq = p.equipment
			eq.clear()
			eq.equip(gear.make("legs", "trousers", {"legs": "trousers"}, "", 0))
			eq.equip(gear.make("feet", "tall_boots", {"feet": "tall_boots"}, "", 1))
			eq.wear_cosmetic(gear.make("legs", "hakama", {"legs": "hakama"}, "", 2), "legs")
			eq.wear_cosmetic(gear.make("feet", "sandals", {"feet": "sandals"}, "", 0), "feet")
			eq.set_mog("legs", true)
			p.refresh_look()
			check("mogged legs before saving (%s)" % p.body_model.look.get("legs"), p.body_model.look.get("legs") == "hakama")
			check("saved", save.save(p))
			eq.clear()
			p.refresh_look()
			check("loads", save.load_into(p))
			check("...the cosmetic pieces back in their slots", eq.get_cosmetic("legs") != null and eq.get_cosmetic("legs").look.get("legs") == "hakama"
				and eq.get_cosmetic("feet") != null and eq.get_cosmetic("feet").look.get("feet") == "sandals")
			check("...legs mogged, feet not (%s)" % str(eq.mog.keys()), eq.is_mogged("legs") and not eq.is_mogged("feet"))
			check("...the body as it was: hakama, tall boots (%s, %s)" % [p.body_model.look.get("legs"), p.body_model.look.get("feet")],
				p.body_model.look.get("legs") == "hakama" and p.body_model.look.get("feet") == "tall_boots")
			var f := FileAccess.open(save.path(), FileAccess.READ)
			var data: Dictionary = f.get_var()
			f.close()
			data.erase("worn_mog")
			data.erase("mog")
			f = FileAccess.open(save.path(), FileAccess.WRITE)
			f.store_var(data)
			f.close()
			check("a save from before transmog loads", save.load_into(p))
			check("...with MOG off everywhere and no cosmetic pieces", eq.mog.is_empty() and eq.cosmetic.is_empty())
			check("...the worn trousers showing (%s)" % p.body_model.look.get("legs"), p.body_model.look.get("legs") == "trousers")
			DirAccess.remove_absolute(save.path())
			return TK.done(fails)
	step += 1
	return false
