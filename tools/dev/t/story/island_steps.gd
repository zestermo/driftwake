extends SceneTree
## 1.25.4 the opening's places on the real Brinehollow: Nessa's parcel taken up to Ambrose at the lighthouse moves on
## to the brawl, fought on the quay; the old forest has its ironwood deadfall by the paths (the marker leads to the
## nearest unsplit one), each split once for a length of timber, three and Tackett's knees are done (on to the queen);
## the ruins' standing stone, read on that step, sends you on to Grell.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var isl
var story
var dlg
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


func _talk(id: String) -> void:
	dlg._cooldown = 0.0
	dlg.start(id)
	var guard := 0
	while dlg.active and guard < 20:
		guard += 1
		if dlg._node.has("choices") or str(dlg._node.get("next", "end")) == "end":
			dlg._close()
			break
		dlg._goto(str(dlg._node["next"]))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			load("res://scripts/world/actor_sleep.gd").enabled = false
			p = stage.player
			story = root.get_node("Story")
			dlg = root.get_node("Dialogue")
			isl = load("res://scripts/island/starter_island.gd").new()
			isl.name = "Brinehollow"
			isl.position = Vector3(0, 0, 9000)
			stage.add_child(isl)
			isl.build(42)
			story.begin()
			for id in ["find_town", "see_gus", "see_nessa"]:
				story.complete(id)
			_talk("ambrose")
			check("Nessa's parcel up to Ambrose: on to the brawl (%s)" % story.step, story.step == "brawl")
			var b: Vector3 = isl.to_local(isl.ground_of("brawl"))
			check("...fought on the quay (%.2f m up)" % b.y, isl.harbour.on_platform(Vector2(b.x, b.z)))
			story.step = "forest"
			check("the old forest's deadfall: %d trunks" % isl.deadfall.size(), isl.deadfall.size() == 3)
			var near := true
			for d in isl.deadfall:
				near = near and isl.to_local(d.global_position).distance_to(Vector3(isl.FOREST.x, isl.to_local(d.global_position).y, isl.FOREST.y)) < 52.0
			check("...all in the forest", near)
			p.global_position = isl.deadfall[1].global_position + Vector3(0, 1, 3)
			p.reset_physics_interpolation()
			check("the marker leads to the nearest", story.target_pos().distance_to(isl.deadfall[1].global_position + Vector3.UP * 1.5) < 0.1)
			var SD = load("res://scripts/game/story_deadfall.gd")
			SD.split(p, 1)
			SD.split(p, 1)
			check("one split: one length of timber (%d)" % p.inventory_component.count("timber"), p.inventory_component.count("timber") == 1 and story.step == "forest")
			check("...and the marker moves on to another", story.target_pos().distance_to(isl.deadfall[1].global_position + Vector3.UP * 1.5) > 1.0)
			SD.split(p, 0)
			SD.split(p, 2)
			check("three split: Tackett's timber, on to the queen (%s, %d)" % [story.step, p.inventory_component.count("timber")], story.step == "queen" and p.inventory_component.count("timber") == 3)
			story.step = "ruins"
			_talk("driftstone")
			check("the standing stone read on its step: on to Grell (%s)" % story.step, story.step == "grell")
			check("...and it's found", dlg.has_flag("driftstone_found"))
			story.reset()
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
