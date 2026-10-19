extends SceneTree
## The equipment slot (was the instrument slot): an instrument goes in it; a save from before v1.18 with the
## instrument in "instrument" loads it into "equipment". The inventory's SHOW box under the slot hides the piece
## on the body: not drawn on the back, still playable (in the hands while played), saved, and a crewmate's
## screen (the look sent over the wire) hides it the same.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pup
var gm
var save
var fid
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "crew": [{"name": "Wren", "at": Vector3(3, 0, -2)}]})


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


func back_shown(who) -> bool:
	var b = who.jam._back
	return b != null and is_instance_valid(b) and b.visible


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pup = stage.crew[0]
			gm = root.get_node("GameMenu")
			save = load("res://scripts/game/save_game.gd")
			save.use_test_file("user://t_equipment_slot_%d.dat" % OS.get_process_id())
			fid = ItemDB.get_item("fiddle")
			p.inventory_component.add_item(fid, 1)
			p.equip_gear_from_bag(p.inventory_component.find_index("fiddle"))
			check("the fiddle goes in the equipment slot", p.equipment.get_item("equipment") == fid and p.body_model.look.get("instrument") == "fiddle")
			check("saved", save.save(p))
			rewrite(func(d):
				d["worn"]["instrument"] = d["worn"]["equipment"]
				d["worn"].erase("equipment")
				d.erase("equip_hidden"))
			p.unequip_gear("equipment")
			check("an old save (instrument slot) loads", save.load_into(p))
			check("...its instrument is in the equipment slot (%s)" % str(p.equipment.slots.keys()), p.equipment.get_item("equipment") == fid \
				and not p.equipment.slots.has("instrument") and p.jam.worn() == "fiddle")
			until = TK.wait_ticks(4)
		1:
			check("shown: the fiddle rides on the back", back_shown(p))
			gm.open("inventory")
			until = TK.wait_ticks(4)
		2:
			var box = gm._inventory._show_box
			check("the inventory has a SHOW box under the equipment slot, ticked", box.visible and box.button_pressed)
			box.button_pressed = false
			check("...unticked: the piece is hidden (look %s)" % str(p.body_model.look.get("equip_hidden")), p.equipment.is_hidden(fid) and p.body_model.look.get("equip_hidden") == true)
			gm.close()
			pup.net_event("look", [p.body_model.look.duplicate(true), false])
			# (the load stood us 0.3 m up: back on the ground to play)
			until = TK.wait_secs(0.8)
		3:
			check("hidden: nothing on the back", not back_shown(p))
			check("...on a crewmate's screen too (the look sent over the wire)", pup.jam.worn() == "fiddle" and not back_shown(pup))
			check("...still playable", p.jam.can_play())
			p.jam.start()
			until = TK.wait_ticks(10)
		4:
			check("played hidden: in the hands", p.jam.playing and (p.jam._parts["body"] as Node3D).visible)
			p.jam.stop()
			check("hidden is saved", save.save(p))
			p.show_equipment(true)
			check("...and loads back hidden", save.load_into(p) and p.equipment.is_hidden(fid) and p.body_model.look.get("equip_hidden") == true)
			p.show_equipment(true)
			until = TK.wait_ticks(4)
		5:
			check("shown again: on the back", back_shown(p))
			save.delete()
			return TK.done(fails)
	step += 1
	return false
