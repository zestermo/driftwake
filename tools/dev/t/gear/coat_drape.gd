extends SceneTree
## (1.29) A coat draped over the shoulders: the wardrobe's DRAPE box under the coat slot wears it with the sleeves empty
## (the arms in the shirt's, the coat's body behind the arms and both sleeves on the torso's chains, pushed by the arms), every coat
## in the game drapes, it's saved, and a crewmate's screen (the look sent over the wire) drapes it too.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pup
var gm
var save
var coat
var gear
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


func torso_chains(body) -> int:
	var n := 0
	for c in body.torso.get_children():
		if c is SpringChains:
			n += c.chain_count()
	return n


func arm_pushed(body) -> bool:
	for c in body.torso.get_children():
		if c is SpringChains and c.colliders.has("arm_l") and c.colliders.has("fore_r"):
			return true
	return false


func chains_finite(body) -> bool:
	for c in body.torso.get_children():
		if c is SpringChains:
			for b in range(c.skel.get_bone_count()):
				var o: Vector3 = c.skel.get_bone_global_pose(b).origin
				if not o.is_finite() or o.length() > 3.0:
					return false
	return true


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pup = stage.crew[0]
			gm = root.get_node("GameMenu")
			save = load("res://scripts/game/save_game.gd")
			gear = load("res://scripts/loot/gear.gd")
			save.use_test_file("user://t_coat_drape_%d.dat" % OS.get_process_id())
			coat = gear.make("coat", "longcoat", {"coat": "longcoat", "coat_color": Color(0.9, 0.88, 0.8), "trim_color": Color(0.85, 0.68, 0.24)})
			p.equipment.equip(coat)
			p.refresh_look()
			# (1.30.3: worn the usual way it hangs from the shoulders in sewn cloth: four panels on the torso, no forearm capsules)
			check("a long coat worn the usual way: not draped, hung (its 4 panels on the torso, the captain's look may add one: %d)" % torso_chains(p.body_model), p.body_model.look.get("coat_drape") == false and not arm_pushed(p.body_model) and torso_chains(p.body_model) in [4, 5])
			gm.open("inventory")
			until = TK.wait_ticks(4)
		1:
			var box = gm._inventory._drape_box
			check("the inventory has a DRAPE box under the coat slot, unticked", box.visible and not box.button_pressed)
			box.button_pressed = true
			check("ticked: the coat is draped (look %s)" % str(p.body_model.look.get("coat_drape")), p.equipment.is_draped(coat) and p.body_model.look.get("coat_drape") == true)
			check("...its body and both empty sleeves hang on the torso's chains (%d)" % torso_chains(p.body_model), torso_chains(p.body_model) >= 6)
			check("...and the arms push them", arm_pushed(p.body_model))
			var front := 0
			for c in p.body_model.torso.get_children():
				if c is SpringChains:
					for ci in range(c.chain_count()):
						if (c.chain(ci)["p"] as PackedVector3Array)[0].z < 0.0:
							front += 1
			check("...all of it behind the arms (in front only the sash's tail: %d)" % front, front <= 1)
			gm.close()
			pup.net_event("look", [p.body_model.look.duplicate(true), false])
			TK.press("move_forward")
			until = TK.wait_secs(1.0)
		2:
			TK.release("move_forward")
			check("walking draped: the chains stay on the body", chains_finite(p.body_model))
			check("a crewmate's screen drapes it too", pup.body_model.look.get("coat_drape") == true and torso_chains(pup.body_model) >= 6)
			check("draped is saved", save.save(p))
			p.drape_coat(false)
			check("...untick: sleeves back on the arms (hung again: %d chains)" % torso_chains(p.body_model), p.body_model.look.get("coat_drape") == false and not arm_pushed(p.body_model) and torso_chains(p.body_model) in [4, 5])
			check("...and the save loads it draped", save.load_into(p) and p.equipment.is_draped(coat) and p.body_model.look.get("coat_drape") == true)
			var ok := []
			for style in CharacterLook.COATS:
				if style == "none":
					continue
				var it = gear.make("coat", style, {"coat": style, "coat_color": Color(0.3, 0.2, 0.4), "trim_color": Color(0.85, 0.68, 0.24)})
				p.equipment.equip(it)
				p.drape_coat(true)
				if torso_chains(p.body_model) >= 6 and arm_pushed(p.body_model):
					ok.append(style)
			check("every coat drapes (%s)" % ", ".join(ok), ok.size() == CharacterLook.COATS.size() - 1)
			var other = gear.make("coat", "jacket", {"coat": "jacket"})
			p.equipment.equip(other)
			p.refresh_look()
			check("a different coat put on isn't draped till ticked", p.body_model.look.get("coat_drape") == false)
			until = TK.wait_ticks(10)
		3:
			check("the last draped look stood still and finite", chains_finite(p.body_model))
			return TK.done(fails)
	step += 1
	return false
