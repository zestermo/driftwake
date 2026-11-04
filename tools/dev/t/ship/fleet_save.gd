extends SceneTree
## (1.30) Saves and the crew's ships: a 1.29 save sailing the caravel with the sloop laid up (the sloop's own paint in
## her laid-up kit) loads with both still owned, the sloop's upgrades kept and her old paint gone (the crew's colours are
## the ship she sails). A save sailing the galleon, the sloop, caravel and brig laid up, loads back as the galleon on her own
## layout (her rooms, her gun deck), every ship still owned with its upgrades.
const TK := preload("res://tools/dev/test_kit.gd")
const SAVE := "user://t_fleet_save.dat"
var stage
var step := 0
var until := 0
var fails := 0
var SG
var SC


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _with_kit(kit: Dictionary) -> void:
	var f := FileAccess.open(SAVE, FileAccess.READ)
	var data: Dictionary = f.get_var()
	f.close()
	data["ship_kit"] = kit
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_var(data)
	f.close()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var ship = stage.ship
	var gm = root.get_node("GameManager")
	match step:
		0:
			SG = load("res://scripts/game/save_game.gd")
			SC = load("res://scripts/ship/ship_classes.gd")
			SG.use_test_file(SAVE)
			SG.save(p)
			_with_kit({"class": "caravel", "hull": 2, "sails": 1, "fleet": {"sloop": {"guns": 2, "hull": 5, "figure": 3}}})
			SG.load_into(p)
			until = TK.wait_ticks(2)
		1:
			var k: Dictionary = gm.ship_kit
			check("a 1.29 save: the caravel sailing, the sloop still owned (%s)" % str(SC.owned(k)), SC.owned(k) == ["caravel", "sloop"])
			check("...the sloop's upgrades kept, her old paint gone", int(k["fleet"]["sloop"]["guns"]) == 2 and not (k["fleet"]["sloop"] as Dictionary).has("hull"))
			var out: Dictionary = SC.switch_to(k, "sloop")
			check("...out again she's in the crew's paint (2), her guns hers (2)", int(out["hull"]) == 2 and int(out["guns"]) == 2)
			# sailing the galleon, the brig and sloop laid up with their own upgrades
			var kit: Dictionary = SC.switch_to(SC.switch_to(ship.kit.merged({"guns": 2}, true), "brig").merged({"guns": 1, "armour": 2}, true), "galleon")
			root.get_node("Net").set_ship_kit(kit.merged({"rudder": 3, "hull": 1}, true))
			until = TK.wait_ticks(2)
		2:
			SG.save(p)
			gm.ship_kit = load("res://scripts/ship/ship_kit.gd").fresh()
			ship.apply_kit(gm.ship_kit)
			SG.load_into(p)
			until = TK.wait_ticks(3)
		3:
			var k: Dictionary = gm.ship_kit
			check("saved sailing the galleon, she loads as the galleon (%s, layout %s)" % [SC.class_of(k), ship.layout.cls], SC.class_of(k) == "galleon" and ship.layout.cls == "galleon" and ship.layout.has_lower())
			check("...her own upgrades on (rudder %d) and the crew's paint (%d)" % [int(k["rudder"]), int(k["hull"])], int(k["rudder"]) == 3 and int(k["hull"]) == 1)
			check("...every ship owned (%s), each with its own (brig armour %d)" % [str(SC.owned(k)), int(k["fleet"]["brig"]["armour"])],
				SC.owned(k) == ["galleon", "sloop", "caravel", "brig"] and int(k["fleet"]["brig"]["armour"]) == 2 and int(k["fleet"]["sloop"]["guns"]) == 2)
			SG.use_test_file("")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			return TK.done(fails)
	step += 1
	return false
