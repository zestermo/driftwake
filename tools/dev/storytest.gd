extends SceneTree
## The story (Story): off in a session that isn't a new game; begin() locks the
## ship and the skill map; waking on the beach (lying, the gull lands, caws and
## flies off, standing up, the first objective on the HUD); every talk step
## starts at the NPC's story line and moves on (Tackett busy before his turn);
## the smugglers, Grell, the queen and Morrow count when beaten near you;
## Vey's free point opens the skill map, Tackett's keel gives you the ship;
## the end; saved and restored mid-story.
var t := 0.0
var wait := 0.0
var step := 0
var fails := 0
var p
var isl
var ship
var dm
var gull
var points0 := 0


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func hud():
	return root.get_tree().get_first_node_in_group("hud")


func story():
	return root.get_node("Story")


func _put(at: Vector3) -> void:
	p.health_component.heal(9999.0)
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _npc(n: String) -> Node3D:
	for c in root.get_tree().get_nodes_in_group("npcs"):
		if c.npc_name == n:
			return c
	return null


## Talk to `who` (dialogue `id`) through to the end; returns the first line.
func _talk(id: String, who: String) -> String:
	dm._cooldown = 0.0
	var npc := _npc(who)
	_put(npc.global_position + Vector3(0, 0.2, 1.5))
	dm.start(id, npc)
	var first := str(dm._pages[0]) if dm.active else ""
	for i in range(30):
		if not dm.active:
			break
		if dm._box.has_choices():
			dm._close()
			break
		dm._advance()
	if dm.active:
		dm._close()
	dm._cooldown = 0.0
	return first


func _kill(e) -> void:
	e.health.take_damage(999999.0)


func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 2.5:
				return false
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			p = root.get_tree().get_first_node_in_group("player")
			isl = root.get_node("World/Islands/Brinehollow")
			ship = root.get_tree().get_first_node_in_group("ship")
			dm = root.get_node("Dialogue")
			check("no story in a session that isn't a new game", not story().active())
			check("  so the skill map is open", story().skills_open())
			check("  and the ship is yours", ship.owned())
			story().begin()
			check("a new game: the story starts at the beach", story().step == "find_town")
			check("  the ship is moored, not yours", not ship.owned())
			root.get_node("GameMenu").open("skills")
			check("  the skill map is locked", root.get_node("GameMenu")._current != "skills")
			ship._on_helm_interacted(p)
			check("  the helm refuses", p.current_state_name() != "Helm")
			check("  summoning refuses", p.try_summon() == "You have no ship")
			var spot: Array = isl.wake_spot()
			var sp: Vector3 = isl.to_local(spot[0])
			check("the wake spot is on the sand by the sea (%.1f m up)" % sp.y, sp.y > 0.3 and sp.y < 3.0)
			check("  west of the quay", sp.x < isl.port_x0)
			p.wake_on_beach()
			check("waking: the Wake state", p.current_state_name() == "Wake")
			wait = 1.2
			step = 1
		1:
			check("lying on your back", absf(p.body_model.pivot.rotation.x) > 1.0)
			check("  the pelvis near the sand", p.body_model.hips.global_position.y - p.global_position.y < 0.5)
			check("  pressing nothing moves you", p.input_locked)
			check("  the skill bar is hidden", not hud()._skill_bar.visible)
			for n in root.find_children("*", "Seagull", true, false):
				gull = n
			check("a gull lands by your head", gull != null and gull.global_position.distance_to(p.global_position) < 9.0)
			wait = 2.0
			step = 2
		2:
			check("  perched beside your head", gull != null and gull.state == 1 and gull.global_position.distance_to(p.global_position) < 2.2)
			wait = 1.0
			step = 3
		3:
			check("  it caws and you jolt (head turned)", absf(p.body_model.head.rotation.y) > 0.3 or absf(p.body_model.torso.rotation.x) > 0.2)
			check("  then it flies off", is_instance_valid(gull) and gull.state == 2)
			wait = 3.8
			step = 4
		4:
			check("standing again", p.current_state_name() == "Idle" and absf(p.body_model.pivot.rotation.x) < 0.25)
			check("  you can move", not p.input_locked)
			check("the objective is on the HUD", hud()._objective._box.visible and hud()._objective._goal.text == story().goal())
			check("  and points at Old Pell", story().target_pos().distance_to(_npc("Old Pell").global_position) < 3.0)
			check("Tackett's busy before his turn", _talk("tackett", "Shipwright Tackett").begins_with("Busy."))
			check("  and has no yard to offer", dm.has_flag("ship_not_owned"))
			check("Pell: the story line", _talk("pell", "Old Pell").begins_with("Easy, easy"))
			check("  sends you to Gus", story().step == "see_gus")
			check("Gus: the story line", _talk("gus", "Gus Brannock").begins_with("Pell sent you"))
			check("  sends you to Nessa", story().step == "see_nessa")
			check("Nessa: the story line", _talk("nessa", "Nessa").begins_with("Gus sent you"))
			check("  sends you to Vey", story().step == "see_vey")
			check("Vey: the story line", _talk("vey", "Sergeant Vey").begins_with("Nessa sent you"))
			check("  sends you after the smugglers", story().step == "smugglers")
			check("  who are marked", story().target_pos().distance_to(isl.place_of("smugglers")) < 0.1)
			check("Vey while they're still there: a reminder", _talk("vey", "Sergeant Vey").begins_with("The smugglers are still"))
			_put(isl.place_of("smugglers") + Vector3(0, 1, 6))
			for g in isl.smugglers.grunts:
				_kill(g)
			wait = 1.5
			step = 5
		5:
			check("smugglers beaten: back to Vey", story().step == "vey_skills")
			check("  the skill map's still locked", not story().skills_open())
			points0 = p.progression.skill_points
			check("Vey: skills", _talk("vey", "Sergeant Vey").begins_with("Back already"))
			check("  a free skill point", p.progression.skill_points == points0 + 1)
			check("  the skill map opens", story().skills_open())
			root.get_node("GameMenu").open("skills")
			check("  (K works)", root.get_node("GameMenu")._current == "skills")
			root.get_node("GameMenu").close()
			check("  next: Grell", story().step == "grell")
			_put(isl.place_of("den") + Vector3(0, 1, 8))
			for g in isl.den.grunts:
				if g.captain:
					_kill(g)
			wait = 1.5
			step = 6
		6:
			check("Grell beaten: tell Odile", story().step == "see_odile")
			check("Odile: the story line", _talk("odile", "Harbormaster Odile").begins_with("Grell? Dead?"))
			check("Tackett: the story line", _talk("tackett", "Shipwright Tackett").begins_with("Odile sent you"))
			check("  next: the queen", story().step == "queen")
			_put(isl.place_of("cave") + Vector3(0, 0, 4))
			_kill(isl.cave.queen)
			wait = 1.5
			step = 7
		7:
			check("the queen slain: back to Tackett", story().step == "tackett_ship")
			check("  still no ship", not ship.owned())
			check("Tackett: the keel", _talk("tackett", "Shipwright Tackett").begins_with("Is that"))
			check("  she's yours", ship.owned())
			check("  and so is his yard", not dm.has_flag("ship_not_owned"))
			_put(ship.helm_position.global_position + Vector3(0, 0.3, 0))
			ship._on_helm_interacted(p)
			check("  the helm takes you", p.current_state_name() == "Helm")
			p.state_machine.force_state("Idle", {})
			check("Gus: Redtide", _talk("gus", "Gus Brannock").begins_with("Heard Tackett"))
			check("  next: Morrow", story().step == "morrow")
			var fort = root.get_tree().get_first_node_in_group("forts")
			_put(story().place_pos("redtide") + Vector3(0, 1, 4))
			_kill(fort.boss)
			wait = 1.5
			step = 8
		8:
			check("Morrow defeated: the story's done", not story().active())
			check("  the objective is gone", not hud()._objective._box.visible)
			# saved and restored mid-story
			story().from_dict({"step": "grell", "won": ["smugglers"]})
			var dd: Dictionary = story().to_dict()
			story().reset()
			story().from_dict(dd)
			check("restored mid-story: on Grell", story().step == "grell" and story().won.has("smugglers"))
			check("  with the skill map open", story().skills_open())
			check("a save without a story has none", (func(): story().from_dict({}); return not story().active()).call())
			print("RESULT %s" % ("OK" if fails == 0 else "FAILED (%d)" % fails))
			quit(fails)
	return false
