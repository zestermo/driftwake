extends SceneTree
## (1.30.3, docs/v1_30_3_slots.md) The slots without "Accessory": old accessory items take their own kinds (a cape the
## Back, a pauldron the Shoulders, an earring a Trinket), two trinkets fill trinket1 then trinket2; the three pauldron
## items draw on the left, the right and both shoulders; pieces that can't go together are refused with a reason
## (cloak + pauldron, mantle + greatcoat, a helm over a full mask, apron + frock; a helm over a bandage is fine) and a
## draped coat under a mantle too; covered pieces are worn but not drawn (goggles under a helm); an old save's
## accessories go to their slots and what doesn't fit (a cape beside the pack, a third trinket) to the bag.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
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


func mk(kind: String, style: String, look: Dictionary):
	return gear.make(kind, style, look)


## (1.30.3) A pauldron rides its shoulder chain's helper in the arm's skin: the vertices bound wholly to that side's helper.
func arm_meshes(side: String) -> int:
	var n := 0
	for mi in p.body_model.find_children("*", "MeshInstance3D", true, false):
		var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D if (mi as MeshInstance3D).skin else null
		if skel == null:
			continue
		var bone := skel.find_bone("shoulder_%s_%d" % [side, BodyBuilder.PAULDRON_FOLLOW])
		if bone < 0:
			continue
		var am := mi.mesh as ArrayMesh
		for s in range(am.get_surface_count()):
			var arr := am.surface_get_arrays(s)
			var b: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			for i in range(b.size()):
				if b[i] == bone and w[i] > 0.99:
					n += 1
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			gear = load("res://scripts/loot/gear.gd")
			# old kinds remapped
			var cape = mk("accessory", "cape", {"cape": true, "cape_color": Color.RED})
			var pd = mk("accessory", "pauldron", {"pauldron": true})
			var ear = mk("accessory", "earring", {"earring": true})
			var scarf = mk("accessory", "scarf", {"scarf": true})
			var apron = mk("accessory", "apron", {"apron": true})
			var band = mk("accessory", "bandolier", {"bandolier": true})
			check("old accessories take their slots: cape %s, pauldron %s, earring %s, scarf %s, apron %s, bandolier %s" % [
				cape.gear_slot, pd.gear_slot, ear.gear_slot, scarf.gear_slot, apron.gear_slot, band.gear_slot],
				cape.gear_slot == "back" and pd.gear_slot == "shoulders" and ear.gear_slot == "trinket" and scarf.gear_slot == "face"
				and apron.gear_slot == "belt" and band.gear_slot == "strap")
			# trinkets fill both slots
			var eq = p.equipment
			eq.clear()
			eq.equip(ear)
			var patch = mk("accessory", "eyepatch", {"eyepatch": true})
			eq.equip(patch)
			check("two trinkets go in trinket1 and trinket2", eq.get_item("trinket1") == ear and eq.get_item("trinket2") == patch)
			# the pauldron items
			var sides := []
			for st in ["pauldron", "pauldron_r", "pauldrons"]:
				var it = mk("shoulders", st, gear.PAULDRONS[st])
				eq.equip(it)
				p.refresh_look()
				sides.append([arm_meshes("l"), arm_meshes("r")])
			eq.clear()
			p.refresh_look()
			var bare := [arm_meshes("l"), arm_meshes("r")]
			print("plate vertices on the shoulder helpers (left, right): bare %s, left %s, right %s, pair %s" % [bare, sides[0], sides[1], sides[2]])
			check("the left pauldron on the left arm only", sides[0][0] > bare[0] and sides[0][1] == bare[1])
			check("the right pauldron on the right arm only", sides[1][1] > bare[1] and sides[1][0] == bare[0])
			check("the pair on both", sides[2][0] > bare[0] and sides[2][1] > bare[1])
			# blocks
			var cloak = mk("back", "cloak", {"cloak": true})
			eq.equip(cloak)
			var why: String = eq.clash(mk("shoulders", "pauldron_r", {"pauldron_r": true}))
			check("a pauldron under a cloak is refused: '%s'" % why, why != "")
			eq.clear()
			eq.equip(mk("coat", "greatcoat", {"coat": "greatcoat"}))
			check("a mantle over a greatcoat is refused", eq.clash(mk("back", "mantle", {"mantle": true})) != "")
			eq.clear()
			eq.equip(mk("head", "helm", {"hat": "helm"}))
			check("a full mask under a helm is refused", eq.clash(mk("face", "oni", {"face_wear": "oni"})) != "")
			check("a head bandage under a helm is fine", eq.clash(mk("face", "bandage", {"face_wear": "bandage"})) == "")
			check("the Bulwark Helm counts as a helm", gear.clash({"head": mk("head", "bulwark_helm", gear.LOOKS["bulwark_helm"][1]),
				"face": mk("face", "iron_mask", {"face_wear": "iron_mask"})}) != "")
			eq.clear()
			eq.equip(mk("coat", "frock", {"coat": "frock"}))
			check("an apron over a frock is refused", eq.clash(apron) != "")
			eq.clear()
			var coat = mk("coat", "longcoat", {"coat": "longcoat"})
			eq.equip(coat)
			eq.equip(mk("back", "mantle", {"mantle": true}))
			check("draping a coat under a mantle is refused", eq.clash(null, "coat", true) != "")
			check("the bag refuses the blocked piece and keeps it", _bag_refuses())
			# hidden, not blocked
			eq.clear()
			eq.equip(mk("head", "helm", {"hat": "helm"}))
			eq.equip(mk("accessory", "goggles", {"goggles": true}))
			var lk: Dictionary = gear.compose({}, eq.look_slots())
			check("goggles under a helm are worn but not drawn", eq.get_item("trinket1") != null and not lk.get("goggles", true))
			# an old save's accessories
			eq.clear()
			p.inventory_component.items.clear()
			eq.equip(mk("back", "backpack", {"backpack": true}))
			var moved := [mk("accessory", "cape", {"cape": true}), mk("accessory", "earring", {"earring": true}),
				mk("accessory", "eyepatch", {"eyepatch": true}), mk("accessory", "goggles", {"goggles": true}),
				mk("accessory", "pauldron", {"pauldron": true}), mk("accessory", "pauldron", {"pauldron": true})]
			load("res://scripts/game/save_game.gd")._rehome(p, moved)
			var in_bag := []
			for s in p.inventory_component.items:
				in_bag.append(s.item.icon_kind)
			print("bag after the move: %s" % str(in_bag))
			check("the pack stays on the back, the cape to the bag", eq.get_item("back").icon_kind == "backpack" and "cape" in in_bag)
			check("two trinkets worn, the third to the bag", eq.get_item("trinket1") != null and eq.get_item("trinket2") != null
				and "goggles" in in_bag)
			check("one pauldron worn, the second to the bag", eq.get_item("shoulders") != null and "pauldron" in in_bag)
			return TK.done(fails)
	step += 1
	return false


## A blocked piece clicked in the bag stays in the bag (equip_gear_from_bag refuses it).
func _bag_refuses() -> bool:
	var eq = p.equipment
	eq.clear()
	eq.equip(mk("back", "cloak", {"cloak": true}))
	p.inventory_component.items.clear()
	var pd = mk("shoulders", "pauldrons", gear.PAULDRONS["pauldrons"])
	p.inventory_component.add_item(pd, 1)
	var ok: bool = p.equip_gear_from_bag(0)
	return not ok and eq.get_item("shoulders") == null and p.inventory_component.items.size() == 1
