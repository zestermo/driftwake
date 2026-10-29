class_name StoryDeadfall
extends RefCounted
## The old forest's ironwood deadfall (1.25.4, Story step "forest"): fallen trunks beside the forest's paths. While
## that's the step, splitting one gives a length of timber (once each: a Dialogue flag per trunk, so each captain
## splits their own); COUNT of them and Tackett has his knees. The trunks are the island's, the same on every
## machine.

const COUNT := 3


## A fallen trunk with its root plate and a couple of split lengths beside it, and its Interactable. `i` names it.
static func build(i: int, seed_value: int) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := StaticBody3D.new()
	body.name = "Deadfall%d" % i
	var mb := MeshBuilder.new()
	var bark := PSXMat.lit("bark", Color(0.62, 0.55, 0.5))
	var heart := PSXMat.lit("logs", Color(0.9, 0.7, 0.5))
	var len := rng.randf_range(5.5, 7.0)
	var r := rng.randf_range(0.42, 0.52)
	var lie := Basis(Vector3.FORWARD, PI * 0.5)
	mb.add_cylinder(bark, Transform3D(lie, Vector3(0, r, 0)), r, r * 0.8, len, 8, 1.0)
	mb.add_cylinder(heart, Transform3D(lie, Vector3(len * 0.5 + 0.01, r, 0)), r * 0.8, r * 0.8, 0.02, 8, 1.0)
	mb.add_blob(PSXMat.lit("dirt", Color(0.6, 0.5, 0.4)), Transform3D(Basis(), Vector3(-len * 0.5 - 0.2, r + 0.3, 0)), Vector3(0.5, 1.1, 1.2), rng, 0.25, 2, 6, 1.0)
	for k in range(2):
		var p := Vector3(rng.randf_range(-1.5, 1.5), 0.16, r + 0.7 + k * 0.38)
		mb.add_cylinder(heart, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)) * lie, p), 0.15, 0.15, 1.3, 6, 1.0)
	var mi := mb.to_instance("Mesh")
	mi.visibility_range_end = 160.0
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(len, r * 2.0, r * 2.0)
	cs.shape = box
	cs.position = Vector3(0, r, 0)
	body.add_child(cs)
	var inter := Interactable.new()
	inter.name = "Split"
	inter.collision_layer = 512
	inter.collision_mask = 0
	inter.prompt_text = "Ironwood deadfall"
	inter.gesture = "reach"
	var ics := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.4
	ics.shape = sph
	ics.position = Vector3(0, 0.8, 0.6)
	inter.add_child(ics)
	body.add_child(inter)
	inter.interacted.connect(func(p: Player): split(p, i))
	return body


static func flag(i: int) -> String:
	return "deadfall_%d" % i


## How many trunks this captain has split.
static func split_count(dlg: Node) -> int:
	var n := 0
	for i in range(COUNT):
		if dlg.has_flag(flag(i)):
			n += 1
	return n


## Split trunk `i` for the captain's story: a length of timber, and the step done once they have COUNT.
static func split(p: Player, i: int) -> void:
	var dlg := p.get_node("/root/Dialogue")
	var story := p.get_node("/root/Story")
	var hud := p.get_tree()
	if story.step != "forest" or dlg.has_flag(flag(i)):
		hud.call_group("hud", "show_toast", "Ironwood, storm-felled years back. Tackett's wood." if story.step != "forest" else "You've split this one already.")
		return
	dlg.set_flag(flag(i))
	p.inventory_component.add_item(ItemDB.get_item("timber"), 1)
	p.get_node("/root/Net").fx("sfx", ["chop", p.global_position + Vector3.UP, -6.0, 0.08, 0.8])
	var n := split_count(dlg)
	if n >= COUNT:
		story.complete("forest")
	else:
		hud.call_group("hud", "show_toast", "Seasoned ironwood split: %d of %d for Tackett." % [n, COUNT])
