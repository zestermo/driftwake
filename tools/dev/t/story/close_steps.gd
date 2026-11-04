extends SceneTree
## 1.30 the opening's new steps on the real Brinehollow: the smugglers beaten, their camp gives up Brann's flour and the
## objective sends you to the windmill in the farmlands (the marker on Brann); his talk takes it back for gold and moves
## on to Vey; after Vey, Wick hands over the Smoke Pellet's parts (the marker moves to his bench) and building it moves
## on to Aldous, whose book (the marker gone, the bag says read it) read moves on to the shrine.
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


func _near(npc_name: String) -> bool:
	for n in root.get_tree().get_nodes_in_group("npcs"):
		if n.npc_name == npc_name:
			return story.target_pos().distance_to(n.global_position + Vector3.UP * 2.2) < 0.1
	return false


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
			story.step = "smugglers"
			var gold0: int = p.inventory_component.count("gold")
			story.complete("smugglers")
			check("the smugglers beaten: Brann's flour in the bag, on to the farm (%s)" % story.step, story.step == "farm" and p.inventory_component.count("flour") == 1)
			check("...the marker on Miller Brann", _near("Miller Brann"))
			var brann_at: Vector3 = isl.to_local(story.target_pos())
			check("...out in the farmlands (%.0f m from the windmill hamlet)" % Vector2(brann_at.x, brann_at.z).distance_to(isl.FARM), Vector2(brann_at.x, brann_at.z).distance_to(isl.FARM) < 60.0)
			_talk("brann")
			check("Brann takes the flour back for %d gold, on to Vey (%s)" % [p.inventory_component.count("gold") - gold0, story.step],
				story.step == "vey_skills" and p.inventory_component.count("flour") == 0 and p.inventory_component.count("gold") == gold0 + story.FARM_GOLD)
			story.complete("vey_skills")
			check("after Vey: the tinker, the marker on Wick (%s)" % story.step, story.step == "tinker" and _near("Wick"))
			_talk("wick")
			check("Wick hands over the Smoke Pellet's parts", p.inventory_component.count("black_powder") >= 2 and p.inventory_component.count("canvas") >= 1)
			var bench: Vector3 = isl.close_rooms["tinker"].find_child("Workbench", false, false).global_position
			check("...the marker moves to his bench", story.target_pos().distance_to(bench + Vector3.UP * 1.5) < 0.1)
			check("...and the objective says build it (%s)" % story.goal(), story.goal().contains("Smoke Pellet"))
			_talk("wick")
			check("...once only", p.inventory_component.count("black_powder") < 4)
			var why: String = load("res://scripts/gadgets/gadgets.gd").build(p, "smoke")
			check("the parts build it at the bench ('%s')" % why, why == "")
			until = TK.wait_secs(1.0)
		1:
			check("built: on to Brother Aldous (%s)" % story.step, story.step == "read" and _near("Brother Aldous"))
			_talk("aldous")
			check("Aldous's book in the bag, no marker, the objective says read it", p.inventory_component.count(story.READ_BOOK) == 1 and story.target_pos() == Vector3.INF and story.goal().contains("Read"))
			load("res://scripts/books/books.gd").read(p, story.READ_BOOK)
			until = TK.wait_secs(1.0)
		2:
			check("read: up the long stair to the shrine (%s)" % story.step, story.step == "shrine")
			story.reset()
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
