extends SceneTree
## 1.25.4 Vey's rack (StoryRack, Story step "vey_rack"): it holds every weapon kind; an unarmed new captain takes one
## down (bag and hands), the next one taken puts the last back, so they only ever carry one; keeping it finishes the
## step (on to Vey, then his drills) and leaves exactly that weapon, its tree found; after that the rack gives nothing.
## 1.30: trying the kinds teaches no mastery and finds no tree (no points).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var story
var rack
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


func _weapons() -> Array:
	var out: Array = []
	for st in p.inventory_component.get_all_items():
		if st.item.is_weapon():
			for i in range(st.quantity):
				out.append(st.item.id)
	return out


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var SR = load("res://scripts/game/story_rack.gd")
	match step:
		0:
			p = stage.player
			story = root.get_node("Story")
			rack = SR.build()
			p.get_parent().add_child(rack)
			rack.global_position = p.global_position + Vector3(0, 0, -3)
			var kinds := {}
			for c in rack.get_children():
				if c.name.begins_with("Rack_"):
					kinds[str(c.name).substr(5)] = true
			var models := {}
			for k in SR.KINDS:
				models[ItemDB.get_item(str(k[0])).weapon_model] = true
			check("the rack holds every weapon kind (%d racked, %d kinds)" % [kinds.size(), models.size()], kinds.size() == 14 and models.size() == 14)
			story.begin()
			for id in ["find_town", "see_gus", "see_nessa", "lighthouse", "brawl", "see_vey"]:
				story.complete(id)
			check("(on the rack step, unarmed)", story.step == "vey_rack" and _weapons().is_empty())
			SR.talk(p, rack)
			var dlg = root.get_node("Dialogue")
			check("the rack talks: groups of kinds to take down", dlg.active and dlg._id == "story_rack")
			dlg.dialogue_event.emit("rack:take:katana")
			dlg._close()
			check("a katana taken down: in the bag and the hands", _weapons() == ["katana"] and p.equipped_weapon and p.equipped_weapon.id == "katana")
			SR.take(p, "spear")
			SR.take(p, "musket")
			check("two more tried: only the last one carried (%s)" % [_weapons()], _weapons() == ["musket"] and p.equipped_weapon.id == "musket")
			var pr = p.progression
			var t: String = pr.hand_tree()
			var lv0: Dictionary = pr.mastery_of(t).duplicate()
			var pts0: int = pr.earned("combat")
			pr.found.erase(t)
			for i in range(4):
				pr.on_hit(rack, null)
			check("trying a rack weapon teaches nothing (%s %s -> %s, %d points)" % [t, lv0, pr.mastery_of(t), pr.earned("combat")],
				pr.mastery_of(t) == lv0 and pr.earned("combat") == pts0 and not pr.found.has(t))
			check("no weapon tree found at the start", not load("res://scripts/progression/progression.gd").FOUND_AT_START.has("sword"))
			until = TK.wait_ticks(10)
		1:
			SR.keep(p)
			check("kept: on to see Vey (%s)" % story.step, story.step == "vey_ready")
			check("...and the kept weapon's tree is found", p.progression.found.has(p.progression.hand_tree()))
			root.get_node("Dialogue").dialogue_event.emit("story:vey_ready")
			check("Vey's talk: on to the drills (%s)" % story.step, story.step == "vey_drills")
			check("...with exactly the kept weapon (%s)" % [_weapons()], _weapons() == ["musket"] and p.equipped_weapon.id == "musket")
			SR.take(p, "greatsword")
			check("the rack gives nothing after", _weapons() == ["musket"])
			story.reset()
			return TK.done(fails)
	step += 1
	return false
