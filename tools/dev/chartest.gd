extends SceneTree
var fails := 0
var step := 0
var t := 0.0
var p
var got = null
func check(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n); if not c: fails += 1
func _initialize():
	# 1. every option value builds
	var opts := {"body": CharacterLook.BODIES, "build": CharacterLook.BUILDS, "height": CharacterLook.HEIGHTS,
		"head": CharacterLook.HEADS, "nose": CharacterLook.NOSES, "eyes": range(6), "brows": range(5), "mouth": range(6),
		"marks": CharacterLook.MARKS, "hair": CharacterLook.HAIR, "facial_hair": CharacterLook.FACIAL_HAIR,
		"hat": CharacterLook.HATS, "top": CharacterLook.TOPS, "sleeves": CharacterLook.SLEEVES, "vest": CharacterLook.VESTS,
		"coat": CharacterLook.COATS, "legs": CharacterLook.LEGS, "feet": CharacterLook.FEET, "belt": CharacterLook.BELTS,
		"gloves": [true, false], "apron": [true, false], "earring": [true, false], "eyepatch": [true, false],
		"scarf": [true, false], "pauldron": [true, false], "pouch": [true, false]}
	var built := 0
	var ok := true
	for k in opts.keys():
		for v in opts[k]:
			var lk := CharacterLook.default_look(); lk[k] = v
			var h := Humanoid.new(); h.setup(lk); root.add_child(h)
			for i in range(5): h._process(1.0 / 60.0)
			var meshes := h.find_children("*", "MeshInstance3D", true, false).size()
			if meshes < 8 or h.hand_r == null or h.hip_socket == null or h.head == null:
				ok = false; print("   bad build ", k, "=", v, " meshes=", meshes)
			h.free(); built += 1
	check("all %d single-option variants build (>=8 meshes, sockets present)" % built, ok)
	var rng := RandomNumberGenerator.new()
	ok = true
	var max_meshes := 0
	for i in range(60):
		rng.seed = 1000 + i
		var h := Humanoid.new(); h.setup(CharacterLook.random_look(rng)); root.add_child(h)
		for j in range(5): h._process(1.0 / 60.0)
		var n := h.find_children("*", "MeshInstance3D", true, false).size()
		max_meshes = maxi(max_meshes, n)
		if n < 8: ok = false
		h.free()
	check("60 random looks build (max %d mesh instances each)" % max_meshes, ok and max_meshes <= 16)
	# 2. apply_look keeps the weapon
	var h2 := Humanoid.new(); h2.setup(CharacterLook.default_look()); root.add_child(h2)
	h2.set_weapon(Props.weapon_mesh("cutlass"))
	h2._attach_weapon(true)
	rng.seed = 5
	h2.apply_look(CharacterLook.random_look(rng))
	check("apply_look keeps weapon in hand", h2.weapon != null and is_instance_valid(h2.weapon) and h2.weapon.get_parent() == h2.hand_r)
	h2._attach_weapon(false)
	h2.apply_look(CharacterLook.default_look())
	check("apply_look keeps weapon sheathed", h2.weapon.get_parent() == h2.hip_socket)
	h2.free()
	# 3. legacy conversion + neutral defaults
	var legacy := CharacterLook.normalize({"shirt": Color.RED, "coat": true, "hat": "bald", "face": 2, "width": 1.3})
	check("legacy look converts (coat/hair/beard/build/top color)", legacy["coat"] == "longcoat" and legacy["hair"] == "bald" and legacy["facial_hair"] == "beard" and legacy["build"] == "stout" and legacy["top_color"] == Color.RED and not legacy.has("shirt"))
	var partial := CharacterLook.normalize({"top": "tunic"})
	check("partial look fills from neutral base (no captain coat/hat)", partial["coat"] == "none" and partial["hat"] == "none" and partial["top"] == "tunic")
	# 4. save/load
	rng.seed = 77
	var lk := CharacterLook.random_look(rng); lk["name"] = "Mara Vance"
	CharacterLook.save_look(lk)
	var re := CharacterLook.load_look()
	var same := true
	for k in lk.keys():
		if typeof(lk[k]) == TYPE_COLOR:
			if not (lk[k] as Color).is_equal_approx(re[k]): same = false; print("   diff ", k)
		elif lk[k] != re[k]: same = false; print("   diff ", k)
	check("save/load round-trips every key", same)
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	match step:
		0:
			if t < 1.0: return false
			p = root.get_tree().get_first_node_in_group("player")
			check("player loads the saved look", p.body_model.look["name"] == "Mara Vance")
			check("headless: creator not auto-opened", not CharacterCreator.active)
			check("{captain} token fills the name", root.get_node("Dialogue")._fill_tokens("Hi {captain}") == "Hi Mara Vance")
			# open from the pause menu
			root.get_node("GameMenu").open("pause")
			root.get_node("GameMenu")._open_appearance()
			step = 1; t = 0
		1:
			if t < 0.2: return false
			var cc: CharacterCreator = null
			for n in root.get_children():
				if n is CharacterCreator: cc = n
			check("Appearance opens the creator and pauses", cc != null and paused and CharacterCreator.active)
			for tab in CharacterCreator.TABS: cc._show_tab(tab)
			check("all tabs build rows", cc._list.get_child_count() > 0)
			var before: String = p.body_model.look["hair"]
			cc._randomize()
			cc._finish(false)
			check("Cancel keeps the old look and unpauses", p.body_model.look["hair"] == before and not paused and not CharacterCreator.active)
			p.open_creator(false)
			step = 2; t = 0
		2:
			if t < 0.2: return false
			var cc2: CharacterCreator = null
			for n in root.get_children():
				if n is CharacterCreator: cc2 = n
			var coat_before = p.body_model.look["coat"]
			check("Appearance no longer edits clothes (no Outfit/Extras tabs)", not cc2._tab_buttons.has("Outfit") and not cc2._tab_buttons.has("Extras"))
			cc2.look["hair"] = "ponytail"; cc2.look["coat"] = "captain" if coat_before != "captain" else "jacket"; cc2.look["name"] = "Ada Black"
			cc2._finish(true)
			check("Done applies + saves body/hair, keeps worn gear", p.body_model.look["hair"] == "ponytail" and p.body_model.look["coat"] == coat_before and CharacterLook.load_look()["name"] == "Ada Black")
			check("weapon survives the rebuild", p.body_model.weapon != null and p.body_model.weapon.get_parent() != null)
			print("RESULT fails=", fails)
			quit()
	return false
