extends SceneTree
## (1.29) The traveller's pack: an item for the new back slot (a stat, an icon, at the tailor), worn on the back with a
## bedroll, a pot and a lantern swinging on chains of their own; the gadget belt's pouch, worn on the back, moves to the
## front of the right hip while it's on (and back when it's off), a rebuild keeps it there; a cape goes over the pack; a
## crewmate sees it (the look); saved.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pup
var save
var gear
var belt
var pack
var bare_chains := 0
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
		if c is SpringChains and c.name != "GadgetBag":
			n += c.chain_count()
	return n


func pouch_z(body) -> float:
	var pouch = body.torso.get_node_or_null("GadgetPouch")
	return pouch.position.z if pouch else INF


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pup = stage.crew[0]
			save = load("res://scripts/game/save_game.gd")
			gear = load("res://scripts/loot/gear.gd")
			belt = load("res://scripts/gadgets/gadget_belt.gd")
			var stats = load("res://scripts/items/gear_stats.gd")
			save.use_test_file("user://t_backpack_%d.dat" % OS.get_process_id())
			belt.wear(p.body_model, 0)
			bare_chains = torso_chains(p.body_model)
			check("the belt's pouch on the back without a pack (z %.2f)" % pouch_z(p.body_model), pouch_z(p.body_model) > 0.05)
			pack = gear.make("back", "backpack", {"backpack": true, "backpack_color": Color(0.62, 0.52, 0.38)})
			check("the pack is a back-slot item with a stat and an icon", p.equipment.slot_for(pack) == "back" and not stats.of(pack).is_empty() and pack.icon != null)
			p.equipment.equip(pack)
			p.refresh_look()
			check("worn: bedroll, pot and lantern hang on chains of their own (%d more)" % (torso_chains(p.body_model) - bare_chains), torso_chains(p.body_model) >= bare_chains + 3)
			check("...and the pouch has moved to the front of the hip (z %.2f)" % pouch_z(p.body_model), pouch_z(p.body_model) < 0.0)
			var shops = load("res://scripts/game/shops.gd")
			check("the tailor sells it", (shops.SHOPS["sela"]["pool"] as Array).any(func(e): return str(e[1]) == "backpack"))
			pup.net_event("look", [p.body_model.look.duplicate(true), false])
			check("a crewmate sees the pack", pup.body_model.look.get("backpack") == true and torso_chains(pup.body_model) >= 3)
			check("saved", save.save(p))
			TK.press("move_forward")
			TK.press("sprint")
			until = TK.wait_secs(1.2)
		1:
			TK.release("move_forward")
			TK.release("sprint")
			var ok := true
			for c in p.body_model.torso.get_children():
				if c is SpringChains:
					for b in range(c.skel.get_bone_count()):
						var o: Vector3 = c.skel.get_bone_global_pose(b).origin
						if not o.is_finite() or o.length() > 3.0:
							ok = false
			check("running: the loose parts swing and stay on the pack", ok)
			var lk: Dictionary = p.body_model.look.duplicate(true)
			lk["cape"] = true
			p.body_model.apply_look(lk)
			var cape = p.body_model.torso.get_node_or_null("Cape")
			var root_z: float = (cape.chain(0)["p"] as PackedVector3Array)[0].z if cape else 0.0
			check("a cape goes over the pack (hung from %.2f m behind)" % root_z, cape != null and root_z > 0.25)
			check("a rebuild keeps the pouch at the hip", pouch_z(p.body_model) < 0.0)
			p.unequip_gear("back")
			check("the pack off: the pouch back on the back", pouch_z(p.body_model) > 0.05 and torso_chains(p.body_model) == bare_chains)
			check("...and the save loads it on", save.load_into(p) and p.equipment.get_item("back") != null and p.body_model.look.get("backpack") == true)
			return TK.done(fails)
	step += 1
	return false
