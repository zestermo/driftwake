class_name StoryRack
extends RefCounted
## Vey's rack (1.25.4, Story step "vey_rack"): every weapon kind in a row in the training yard. While that's the step
## the captain takes any one down (it goes in the bag and the hands, the one taken before goes back up), tries it on
## the dummies, and keeps the one they like, which finishes the step: a new captain's mastery starts on the weapon they
## chose, and the other kinds are Haldor's to sell. Each captain's own (their bag, their story); the rack is the
## island's, built the same on every machine.

## [item id, the group it's under in the talk].
const KINDS := [["cutlass", "blades"], ["katana", "blades"], ["dagger", "blades"], ["boarding_axe", "blades"],
	["spear", "heavy"], ["warhammer", "heavy"], ["greatsword", "heavy"],
	["pistol", "guns"], ["musket", "guns"], ["hand_cannon", "guns"], ["slingshot", "guns"]]
const GROUPS := [["blades", "Blades"], ["heavy", "Two-handed weapons"], ["guns", "Guns and the sling"]]
const GAP := 0.34


## The rack: posts, rails and a weapon of each kind standing in it (local +Z its front), with its Interactable.
static func build() -> Node3D:
	var body := StaticBody3D.new()
	body.name = "StoryRack"
	var w := GAP * KINDS.size() + 0.3
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	for x in [-w * 0.5, w * 0.5]:
		mb.add_box(wood, Transform3D(Basis(), Vector3(x, 0.8, 0)), Vector3(0.12, 1.6, 0.34), 1.0)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(w, 0.1, 0.36), 1.0)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 1.25, -0.08)), Vector3(w, 0.08, 0.08), 1.0)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 1.62, 0)), Vector3(w + 0.2, 0.08, 0.4), 1.0)
	body.add_child(mb.to_instance("Frame"))
	for i in range(KINDS.size()):
		var it := ItemDB.get_item(str(KINDS[i][0]))
		var mi := MeshInstance3D.new()
		mi.name = "Rack_" + it.id
		mi.mesh = Props.weapon_mesh(it.model())
		mi.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-w * 0.5 + 0.3 + GAP * i, 0.38, 0.05))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 70.0
		body.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, 1.6, 0.4)
	cs.shape = box
	cs.position = Vector3(0, 0.8, 0)
	body.add_child(cs)
	var inter := Interactable.new()
	inter.name = "Take"
	inter.collision_layer = 512
	inter.collision_mask = 0
	inter.prompt_text = "Vey's weapon rack"
	inter.gesture = "reach"
	var ics := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.6
	ics.shape = sph
	ics.position = Vector3(0, 1.0, 1.0)
	inter.add_child(ics)
	body.add_child(inter)
	inter.interacted.connect(func(p: Player): talk(p, body))
	return body


## The rack's talk: while the story's on the rack, take any kind down or keep the one in hand; else it's Vey's.
static func talk(p: Player, rack: Node) -> void:
	var dlg := p.get_node("/root/Dialogue")
	var story := p.get_node("/root/Story")
	if not dlg.dialogue_event.is_connected(_on_event):
		dlg.dialogue_event.connect(_on_event)
	var held := str(story.trial)
	var nodes := {}
	if story.step != "vey_rack":
		nodes["menu"] = {"text": ["Vey's rack: a weapon of every kind a sailor swings, oiled and racked by the size.",
			"\"Those are the yard's,\" Vey calls over. \"Haldor sells the like. West of the plaza.\""], "next": "end"}
		dlg.define("story_rack", {"speaker": "Weapon rack", "start": "menu", "nodes": nodes})
		dlg.start("story_rack", rack)
		return
	var menu: Array = []
	for g in GROUPS:
		menu.append({"text": str(g[1]), "next": str(g[0])})
	if held != "":
		menu.append({"text": "Keep the %s." % ItemDB.get_item(held).display_name, "next": "keep"})
	menu.append({"text": "Step away.", "next": "end"})
	nodes["menu"] = {"text": "Every kind of weapon on the sea. Take one down and try it on the dummies; keep the one your hands like." if held == ""
		else "You've the %s in hand. Take another down, or keep it." % ItemDB.get_item(held).display_name, "choices": menu}
	for g in GROUPS:
		var ch: Array = []
		for k in KINDS:
			if k[1] != g[0]:
				continue
			var it := ItemDB.get_item(str(k[0]))
			ch.append({"text": it.display_name + (" (in your hands)" if it.id == held else ""), "next": "take_" + it.id})
			nodes["take_" + it.id] = {"text": ["You lift the %s down. %s" % [it.display_name, it.description], "Try it on the dummies."],
				"event": "rack:take:" + it.id, "next": "end"}
		ch.append({"text": "Back.", "next": "menu"})
		nodes[str(g[0])] = {"text": str(g[1]) + ".", "choices": ch}
	if held != "":
		nodes["keep"] = {"text": ["The %s it is." % ItemDB.get_item(held).display_name,
			"\"Good choice,\" says Vey, the way he'd say it about any choice. \"Now show me you can use it.\""], "event": "rack:keep", "next": "end"}
	dlg.define("story_rack", {"speaker": "Weapon rack", "start": "menu", "nodes": nodes})
	dlg.start("story_rack", rack)


static func _on_event(ev: String) -> void:
	if not ev.begins_with("rack:"):
		return
	var tree := Engine.get_main_loop() as SceneTree
	var p := tree.get_first_node_in_group("player") as Player
	if p == null:
		return
	if ev == "rack:keep":
		keep(p)
	elif ev.begins_with("rack:take:"):
		take(p, ev.substr(10))


## Take kind `id` down: the one taken before goes back up, this one goes in the bag and the hands.
static func take(p: Player, id: String) -> void:
	var story := p.get_node("/root/Story")
	if story.step != "vey_rack":
		return
	var it := ItemDB.get_item(id)
	if str(story.trial) == id:
		return
	_put_back(p)
	p.inventory_component.add_item(it, 1)
	p.equip_weapon(it, true)
	story.trial = id
	p.get_node("/root/FX").sfx("clack", p.global_position + Vector3.UP, -8.0, 0.05, 1.1)


## Keep the one in hand: the step's done.
static func keep(p: Player) -> void:
	var story := p.get_node("/root/Story")
	if str(story.trial) == "":
		return
	var it := ItemDB.get_item(str(story.trial))
	story.trial = ""
	p.get_tree().call_group("hud", "show_banner", "The %s is yours" % it.display_name, "Its mastery starts here. The other kinds are Haldor's to sell.", true)
	story.complete("vey_rack")


static func _put_back(p: Player) -> void:
	var story := p.get_node("/root/Story")
	var was := str(story.trial)
	if was == "":
		return
	p.inventory_component.remove_item(ItemDB.get_item(was), 1)
	p.check_equipped()
	story.trial = ""
