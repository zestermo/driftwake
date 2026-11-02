class_name GadgetBag
extends RefCounted
## The gadget bag (1.28.1): an item (one per colour, "gadget_bag_<colour>") that carries BAG_SLOTS gadgets where the
## belt alone carries one. Worn as a round, slouchy cloth sack on a strap over the right shoulder, across the chest and
## the back, the bag at the left hip; it swings on a spring chain (SpringChains, the hair and cloth system, simulated
## with the body's own chains so it sleeps far from the camera) and its flap is clasped shut, or thrown open while the
## gadget wheel is up or you've just cycled. Everything here is a look: GadgetBelt decides what's carried.
## No autoloads by name (ItemDB calls make_items before they exist; humanoid.gd loads this).

const COLOURS := {"mustard": Color(0.8, 0.62, 0.2), "olive": Color(0.44, 0.47, 0.22), "oxblood": Color(0.45, 0.12, 0.1), "navy": Color(0.16, 0.21, 0.38)}
const ORDER := ["mustard", "olive", "oxblood", "navy"]
const PRICE := 250
const VALUE := 120
## How far open the flap swings (rad) and how fast it moves (rad/s, game time).
const FLAP_OPEN := -1.9
const FLAP_SPEED := 9.0


static func item_id(colour: String) -> String:
	return "gadget_bag_" + colour


static func colour_of(item: String) -> String:
	return item.trim_prefix("gadget_bag_")


## (Gadgets.make_items) the four bags into the item table.
static func make_items(items: Dictionary) -> void:
	for c in ORDER:
		var it := ItemData.new()
		it.id = item_id(c)
		it.display_name = "Gadget Bag (%s)" % c.capitalize()
		it.value = VALUE
		it.rarity = ItemData.Rarity.RARE
		it.description = "A round, slouchy cloth satchel on a strap, its flap clasped shut. Carry it and you carry %d gadgets instead of one: tap O for the next, hold O to pick from the wheel." % GadgetData.BAG_SLOTS
		it.item_type = ItemData.ItemType.LOOT
		it.max_stack = 1
		it.icon_kind = "part"
		it.icon = icon(c)
		items[it.id] = it


static var _icons: Dictionary = {}


static func icon(colour: String) -> Texture2D:
	if not _icons.has(colour):
		var mb := MeshBuilder.new()
		var cloth := PSXMat.lit("canvas", COLOURS[colour])
		var rings := [[0.0, 0.05, 0.07], [-0.05, 0.08, 0.12], [-0.13, 0.1, 0.16], [-0.22, 0.095, 0.15], [-0.28, 0.06, 0.1], [-0.31, 0.015, 0.03]]
		mb.add_loft(cloth, Transform3D.IDENTITY, rings.map(func(r): return [r[0], r[2], r[1]]), MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, true, true)
		mb.add_box(PSXMat.lit("canvas", COLOURS[colour].darkened(0.2)), Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, -0.07, -0.1)), Vector3(0.24, 0.14, 0.02), 3.0, Color.WHITE, false)
		mb.add_blob(PSXMat.lit("metal", GadgetModels.BRASS), Transform3D(Basis(), Vector3(0, -0.13, -0.115)), Vector3(0.02, 0.02, 0.012), RandomNumberGenerator.new(), 0.0, 3, 5, 4.0)
		mb.add_tube(PSXMat.lit("canvas", COLOURS[colour].darkened(0.3)), MeshBuilder.curve_points(Vector3(-0.15, -0.02, 0), Vector3(0, 0.22, 0), Vector3(0.15, -0.02, 0), 7), 0.014, 0.014, 4)
		_icons[colour] = WeaponDesigns.mesh_icon(mb.commit(), Basis.from_euler(Vector3(0.2, 0.5, 0.0)), 0.0)
	return _icons[colour]


## Put the bag of `colour` on `body` ("" takes it off), its flap open or shut. Humanoid.apply_look wears it again on
## a rebuild (bag_colour).
static func wear(body: Humanoid, colour: String, open := false) -> void:
	if body == null:
		return
	body.bag_colour = colour
	for n in ["GadgetBag", "GadgetBagStrap"]:
		var old := body.torso.get_node_or_null(n)
		if old:
			body._sims.erase(old)
			old.free()
	if colour == "":
		return
	var col: Color = COLOURS[colour]
	var cloth := PSXMat.lit("canvas", col)
	var dark := PSXMat.lit("canvas", col.darkened(0.3))
	var sh: float = body.arm_l.position.y
	var sx: float = absf(body.arm_r.position.x)
	var belt: Vector3 = body.lantern_spot
	var hip := absf(belt.x) / cos(0.4)
	var front := Vector2(belt.x, belt.z).length() * 0.95 + 0.03
	# the strap: over the right shoulder, down across the chest and across the back to the left hip
	var mb := MeshBuilder.new()
	var top := Vector3(sx * 0.55, sh + 0.08, 0.0)
	var low := Vector3(-hip - 0.03, belt.y - 0.03, 0.0)
	for zs in [-1.0, 1.0]:
		var pts := PackedVector3Array([top, Vector3(sx * 0.32, sh - 0.02, zs * front * 0.85), Vector3(sx * 0.05, sh - 0.2, zs * front),
			Vector3(-sx * 0.35, belt.y + 0.15, zs * front), Vector3(-hip - 0.02, belt.y + 0.02, zs * front * 0.55), low])
		mb.add_tube(dark, pts, 0.017, 0.017, 4)
	# a buckle on the chest
	mb.add_box(PSXMat.lit("metal", GadgetModels.BRASS), Transform3D(Basis(Vector3.BACK, 0.75), Vector3(sx * 0.05, sh - 0.2, -front - 0.012)), Vector3(0.05, 0.035, 0.012), 4.0)
	var strap := MeshInstance3D.new()
	strap.name = "GadgetBagStrap"
	strap.mesh = mb.commit()
	strap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	strap.visibility_range_end = 40.0
	body.torso.add_child(strap)
	# the bag on its chain at the left hip, kept off the left thigh
	var sim := SpringChains.new()
	sim.name = "GadgetBag"
	sim.colliders = {"thigh_l": {"node": body.leg_l, "a": Vector3(0, 0.02, 0), "b": Vector3(0, -0.4, 0), "r": 0.1}}
	var root := Vector3(-hip - 0.1, belt.y - 0.04, -0.02)
	var chain := PackedVector3Array([root, root + Vector3(-0.01, -0.14, 0.0), root + Vector3(-0.015, -0.28, 0.0)])
	var bones := sim.add_chain(chain, 0.09, 0.07, 1.0, ["thigh_l"])
	# a round sack: gathered at the neck, full in the belly, slumped at the bottom (wide front to back, flat against the hip)
	var rings: Array = []
	var rb := PackedInt32Array()
	for r in [[0.0, 0.045, 0.07], [-0.04, 0.075, 0.12], [-0.11, 0.1, 0.16], [-0.19, 0.1, 0.155], [-0.25, 0.075, 0.12], [-0.29, 0.02, 0.04]]:
		var y: float = root.y + float(r[0])
		var bulge := 0.03 * float(r[1]) / 0.1
		rings.append([y, float(r[1]), float(r[2]), root.z, root.x - bulge])
		rb.append(bones[0] if float(r[0]) > -0.14 else bones[1])
	sim.mb.add_loft(cloth, Transform3D.IDENTITY, rings, MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, true, true, true, false, false, rb)
	# a darker patch sewn on the outer face
	sim.mb.add_loft(dark, Transform3D.IDENTITY, [[root.y - 0.15, 0.012, 0.05, root.z + 0.03, root.x - 0.128], [root.y - 0.22, 0.012, 0.05, root.z + 0.03, root.x - 0.124]],
		MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, true, true, true, false, false, PackedInt32Array([bones[1], bones[1]]))
	body.torso.add_child(sim)
	sim.finalize()
	body._sims.append(sim)
	# the flap on the bag's top bone: hinged at the neck, hanging over the outer face, a brass toggle at its foot;
	# opened, it's thrown up and over and the gadgets show in the mouth
	var att := BoneAttachment3D.new()
	att.name = "Top"
	att.bone_name = sim.skel.get_bone_name(bones[0])
	sim.skel.add_child(att)
	var hinge := Node3D.new()
	hinge.name = "Flap"
	hinge.position = Vector3(-0.04, 0.02, 0.0)
	att.add_child(hinge)
	var fb := MeshBuilder.new()
	var flap_pts: Array = []
	for i in range(4):
		var u := float(i) / 3.0
		flap_pts.append([-u * 0.17, 0.008, 0.13 + 0.035 * sin(u * PI), 0.0, -0.025 - 0.085 * sqrt(u)])
	fb.add_loft(PSXMat.lit("canvas", col.darkened(0.22)), Transform3D.IDENTITY, flap_pts, PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]), 3.0, Color.WHITE, true, true)
	fb.add_blob(PSXMat.lit("metal", GadgetModels.BRASS), Transform3D(Basis(), Vector3(-0.118, -0.165, 0.0)), Vector3(0.014, 0.024, 0.014), RandomNumberGenerator.new(), 0.0, 3, 5, 4.0)
	var flap := MeshInstance3D.new()
	flap.mesh = fb.commit()
	flap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hinge.add_child(flap)
	var inside := MeshInstance3D.new()
	inside.name = "Inside"
	inside.mesh = _inside()
	inside.position = Vector3(-0.06, 0.04, 0.0)
	inside.scale = Vector3(1.4, 1.4, 1.4)
	inside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	att.add_child(inside)
	for m in [flap, inside]:
		(m as MeshInstance3D).visibility_range_end = 40.0
	set_open(body, open, true)


## The gadgets poking up out of the open mouth: a canister, a pellet, a coil of rope, a hook.
static func _inside() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.add_cylinder(PSXMat.lit("metal", GadgetModels.BRASS), Transform3D(Basis(Vector3.BACK, 0.2), Vector3(-0.01, -0.06, 0.04)), 0.022, 0.022, 0.11, 6, 4.0)
	mb.add_blob(PSXMat.flat(GadgetModels.CLAY), Transform3D(Basis(), Vector3(-0.02, 0.02, -0.03)), Vector3(0.03, 0.03, 0.03), RandomNumberGenerator.new(), 0.0, 3, 5, 4.0)
	mb.add_cylinder(PSXMat.lit("rope"), Transform3D(Basis(Vector3.RIGHT, 1.2), Vector3(-0.015, -0.01, 0.0)), 0.035, 0.035, 0.02, 7, 4.0)
	mb.add_tube(PSXMat.lit("metal", GadgetModels.IRON), MeshBuilder.curve_points(Vector3(0.0, -0.04, -0.06), Vector3(-0.01, 0.06, -0.07), Vector3(-0.04, 0.05, -0.05), 4), 0.007, 0.006, 4)
	return mb.commit()


static func _flap(body: Humanoid) -> Node3D:
	var sim := body.torso.get_node_or_null("GadgetBag")
	return sim.get_node("Skeleton/Top/Flap") if sim else null


## Open or clasp the flap (`snap`: at once, else it swings there: Humanoid ticks it while it moves).
static func set_open(body: Humanoid, open: bool, snap := false) -> void:
	body.bag_open = open
	var f := _flap(body)
	if f == null:
		return
	var inside: Node3D = f.get_parent().get_node("Inside")
	inside.visible = open
	if snap:
		f.rotation.z = FLAP_OPEN if open else 0.0
		return
	var tw := f.create_tween()
	tw.tween_property(f, "rotation:z", FLAP_OPEN if open else 0.0, absf((FLAP_OPEN if open else 0.0) - f.rotation.z) / FLAP_SPEED).set_trans(Tween.TRANS_BACK if open else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Whether the flap is thrown open now (tests).
static func is_open(body: Humanoid) -> bool:
	var f := _flap(body)
	return f != null and absf(f.rotation.z) > absf(FLAP_OPEN) * 0.5 and body.bag_open
