extends SceneTree
## (1.29) The face slot and the wraps: every mask, mouth covering and head bandage is an item for the face slot (named,
## a stat, an icon) worn on the head under every hat; arm and foot wraps go in the hands and feet; the wardrobe has a
## FACE slot; tailors, the armourer and plunder carry them; the creator's outfit becomes gear with them; worn pieces
## save and load, and a save from before the slot loads with the face bare.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var gm
var save
var gear
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


func head_verts(body) -> int:
	var n := 0
	for c in body.head.get_children():
		if c is MeshInstance3D and c.mesh:
			for s in range(c.mesh.get_surface_count()):
				n += c.mesh.surface_get_array_len(s)
	return n


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
			gm = root.get_node("GameMenu")
			save = load("res://scripts/game/save_game.gd")
			gear = load("res://scripts/loot/gear.gd")
			var stats = load("res://scripts/items/gear_stats.gd")
			save.use_test_file("user://t_face_slot_%d.dat" % OS.get_process_id())
			var bad := []
			for fw in CharacterLook.FACE_WEAR:
				if fw == "none":
					continue
				var it = gear.make("face", fw, {"face_wear": fw, "face_color": Color(0.66, 0.14, 0.12)})
				if gear.NAMES.get(fw, "") == "" or stats.of(it).is_empty() or it.icon == null or p.equipment.slot_for(it) != "face":
					bad.append(fw)
			check("every face piece is a named face-slot item with a stat and an icon (bad: %s)" % str(bad), bad.is_empty())
			# under every hat: the face piece adds to the head, nothing fails to build
			var flat := []
			for hat in CharacterLook.HATS:
				for fw in ["oni", "kerchief", "bandage", "half_mask"]:
					var lk := CharacterLook.default_look()
					lk["hat"] = hat
					lk["face_wear"] = "none"
					p.body_model.apply_look(lk)
					var bare := head_verts(p.body_model)
					lk["face_wear"] = fw
					p.body_model.apply_look(lk)
					if head_verts(p.body_model) <= bare:
						flat.append("%s+%s" % [hat, fw])
			check("a face piece goes on under every hat (missing: %s)" % str(flat), flat.is_empty())
			var lk2 := CharacterLook.default_look()
			lk2.merge({"face_wear": "kerchief", "face_color": Color(0.2, 0.32, 0.62), "arm_wraps": true, "wraps_color": Color(0.9, 0.88, 0.8), "feet": "foot_wraps", "gloves": false}, true)
			var outfit: Dictionary = gear.items_from_look(lk2)
			check("the creator's kerchief, arm wraps and foot wraps become gear", outfit.has("face") and outfit["face"].icon_kind == "kerchief"
				and outfit.get("hands") and outfit["hands"].icon_kind == "arm_wraps" and outfit.get("feet") and outfit["feet"].icon_kind == "foot_wraps")
			p.equipment.clear()
			for slot in outfit.keys():
				if slot != "extra":
					p.equipment.equip(outfit[slot], slot)
			p.refresh_look()
			var wl: Dictionary = p.body_model.look
			check("worn: the look has them (%s, %s, %s)" % [wl.get("face_wear"), wl.get("arm_wraps"), wl.get("feet")],
				wl.get("face_wear") == "kerchief" and wl.get("arm_wraps") == true and wl.get("feet") == "foot_wraps")
			var shops = load("res://scripts/game/shops.gd")
			var sela: Array = (shops.SHOPS["sela"]["pool"] as Array).map(func(e): return str(e[1]))
			var vey: Array = (shops.SHOPS["vey"]["pool"] as Array).map(func(e): return str(e[1]))
			var plunder: Array = gear.PLUNDER.map(func(e): return str(e[1]))
			check("the tailor sells masks, coverings, bandages and wraps", ["kerchief", "bandage", "eye_wrap", "half_mask", "mask", "oni", "arm_wraps", "foot_wraps"].all(func(s): return sela.has(s)))
			check("the armourer the iron faceplate and mouth guard; some turn up as plunder", vey.has("iron_mask") and vey.has("mouth_guard") and plunder.has("oni") and plunder.has("iron_mask"))
			check("saved", save.save(p))
			p.equipment.unequip("face")
			p.refresh_look()
			check("...loads with the kerchief back on", save.load_into(p) and p.equipment.get_item("face") != null and p.body_model.look.get("face_wear") == "kerchief")
			rewrite(func(d): d["worn"].erase("face"))
			check("a save from before the face slot loads bare-faced", save.load_into(p) and p.equipment.get_item("face") == null and p.body_model.look.get("face_wear") == "none")
			gm.open("inventory")
			until = TK.wait_ticks(4)
		1:
			var doll: Dictionary = gm._inventory._doll
			check("the wardrobe has a FACE slot", doll.has("face") and doll["face"].visible)
			gm.close()
			return TK.done(fails)
	step += 1
	return false
