extends Node
## The story (autoload "Story"): a chain of steps from waking on the beach by
## the quay to beating Captain Morrow, right across Brinehollow (1.25.4: the
## lighthouse, the quay brawl, Vey's rack, the shrine, the ruins, the old forest).
## Each step names who or where to go (the HUD's objective and marker) and what
## finishes it: a talk (a dialogue node with "event": "story:<id>"; that NPC's
## JSON says where the talk starts while the step is current, under "story"), a
## fight won near you, or a bout (ArenaBout, asked for as you come near its
## place: the quay brawl, Tomo's spar) won.
## Only a new game from the title screen plays it (begin()); every other
## session (tests, the editor's run) has it done with nothing locked.
## Per captain, saved in your slot; in co-op each captain follows their own,
## and the ship's lock is the host's (it lives in the ship kit).

signal changed

const STEPS := [
	{"id": "find_town", "goal": "Head into town: find someone who knows this place", "npc": "Old Pell", "who": "Pell"},
	{"id": "see_gus", "goal": "Find Gus at the Salted Gull", "npc": "Gus Brannock", "who": "Gus"},
	{"id": "see_nessa", "goal": "See Nessa at the market", "npc": "Nessa", "who": "Nessa"},
	{"id": "lighthouse", "goal": "Take Nessa's parcel up to the lighthouse keeper", "npc": "Keeper Ambrose", "who": "Ambrose"},
	{"id": "brawl", "goal": "Deal with the dock toughs on the quay: fists only", "place": "brawl", "bout": "brawl", "who": "The quay"},
	{"id": "see_vey", "goal": "Find Sergeant Vey at the training yard", "npc": "Sergeant Vey", "who": "Vey"},
	{"id": "vey_rack", "goal": "Try the blades on Vey's rack and keep one", "place": "rack", "who": "Weapon rack"},
	{"id": "vey_drills", "goal": "Show Vey every move on the training dummies", "npc": "Sergeant Vey", "who": "Vey"},
	{"id": "smugglers", "goal": "Drive the smugglers out of the south cove", "place": "smugglers", "who": "Smugglers' camp"},
	{"id": "vey_skills", "goal": "Report back to Sergeant Vey", "npc": "Sergeant Vey", "who": "Vey"},
	{"id": "shrine", "goal": "Climb the long stair: Master Isao at the shrine reads your Edy", "npc": "Master Isao", "who": "Isao"},
	{"id": "tomo", "goal": "Spar with Tomo on the shrine terrace", "place": "spar", "bout": "master:black_leg", "who": "Tomo"},
	{"id": "ruins", "goal": "Examine the standing stone in the old ruins", "place": "ruins", "who": "The ruins"},
	{"id": "grell", "goal": "Defeat Captain Grell at the pirate den", "place": "den", "who": "Pirate den"},
	{"id": "see_odile", "goal": "Tell Harbormaster Odile that Grell is beaten", "npc": "Harbormaster Odile", "who": "Odile"},
	{"id": "see_tackett", "goal": "Ask Shipwright Tackett about a ship", "npc": "Shipwright Tackett", "who": "Tackett"},
	{"id": "forest", "goal": "Cut seasoned timber in the old forest for Tackett", "place": "forest", "who": "Old forest"},
	{"id": "queen", "goal": "Slay the Brood Queen in the forest cave", "place": "cave", "who": "Brood cave"},
	{"id": "tackett_ship", "goal": "Bring the timber and the queen's chitin to Tackett", "npc": "Shipwright Tackett", "who": "Tackett"},
	{"id": "see_gus_redtide", "goal": "Ask Gus who rules these waters", "npc": "Gus Brannock", "who": "Gus"},
	{"id": "morrow", "goal": "Sail to Redtide Rock and defeat Captain Morrow", "place": "redtide", "who": "Redtide Rock"},
]
const DONE := "done"
## Saves before 1.25.4: every old step id is on the new list, so a captain mid-story resumes where they were (and
## skips the new steps before it); an id the list no longer knows lands here (none so far), else the story's done.
const OLD := {}
## Fights count when you're this close to them as they're won (m).
const NEAR := {"smugglers": 70.0, "den": 90.0, "cave": 60.0, "redtide": 140.0}
## A bout step asks for its bout this close to its place (m), again once you've been twice as far or it's lost.
const BOUT_R := {"brawl": 13.0, "master:black_leg": 16.0}
const REARM_SECS := 6.0

var step: String = DONE
## Fights won so far (place -> true): a step whose fight you already won
## finishes as soon as it comes up.
var won: Dictionary = {}
## The kind taken down from Vey's rack and not yet kept (StoryRack: the next one taken puts it back).
var trial := ""
var _poll: float = 0.0
var _island: Node
var _bout_armed := true
var _rearm_t := 0.0


func active() -> bool:
	return step != DONE


func index_of(id: String) -> int:
	for i in range(STEPS.size()):
		if STEPS[i]["id"] == id:
			return i
	return STEPS.size()


func current() -> Dictionary:
	var i := index_of(step)
	return STEPS[i] if i < STEPS.size() else {}


func goal() -> String:
	return str(current().get("goal", ""))


## Past step `id` (or no story at all).
func passed(id: String) -> bool:
	return index_of(step) > index_of(id)


## Whether a line, choice or bark gated on the story is on: {"after": step}
## once that step's done (or with no story), {"before": step} only until then.
func allows(d: Dictionary) -> bool:
	if d.has("after") and not passed(str(d["after"])):
		return false
	if d.has("before") and passed(str(d["before"])):
		return false
	return true


func skills_open() -> bool:
	return passed("vey_skills")


## A new game: you wake on the beach with nothing but your name (and no blade: Vey's rack gives you one).
func begin() -> void:
	step = STEPS[0]["id"]
	won.clear()
	trial = ""
	_bout_armed = true
	Dialogue.set_flag("ship_not_owned")
	_unarm(_player())
	# (a guest's new captain doesn't take the host's ship away)
	if not Net.is_client():
		var gm := get_node("/root/GameManager")
		var kit: Dictionary = gm.ship_kit.duplicate()
		kit["owned"] = false
		Net.set_ship_kit(kit)
	changed.emit()


## Every weapon out of the bag and the hands (a new captain's starting cutlass).
func _unarm(p: Player) -> void:
	if p == null:
		return
	var inv := p.inventory_component
	for st in inv.get_all_items().duplicate():
		if (st as ItemStack).item.is_weapon():
			inv.remove_item(st.item, st.quantity)
	p.check_equipped()


func reset() -> void:
	step = DONE
	won.clear()
	trial = ""
	changed.emit()


func to_dict() -> Dictionary:
	return {"step": step, "won": won.keys(), "trial": trial}


func from_dict(d: Dictionary) -> void:
	step = map_old(str(d.get("step", DONE)))
	trial = str(d.get("trial", ""))
	won.clear()
	for k in d.get("won", []):
		won[str(k)] = true
	_bout_armed = true
	changed.emit()


## A saved step id on today's list (see OLD).
static func map_old(id: String) -> String:
	if id == DONE:
		return DONE
	for s in STEPS:
		if s["id"] == id:
			return id
	return str(OLD.get(id, DONE))


## Finish step `id` if it's the one you're on: what it unlocks, the next
## objective on screen, a save.
func complete(id: String) -> void:
	if step != id:
		return
	var p := _player()
	match id:
		"vey_skills":
			if p:
				p.progression.drill()
		"tackett_ship":
			Dialogue.set_flag("ship_not_owned", false)
			var gm := get_node("/root/GameManager")
			var kit: Dictionary = gm.ship_kit.duplicate()
			kit["owned"] = true
			if not Net.is_client():
				Net.set_ship_kit(kit)
	var i := index_of(id) + 1
	step = STEPS[i]["id"] if i < STEPS.size() else DONE
	_bout_armed = true
	changed.emit()
	_drills()
	if step == DONE:
		UIStyle.sfx("quest_done")
		get_tree().call_group("hud", "show_banner", "The sea is yours", "Sail where you like, Captain")
	else:
		get_tree().call_group("hud", "show_objective_banner", goal(), true)
	if p:
		SaveGame.save(p)
	_check_won()


## A bout this captain asked for is over (ArenaBout.result, on their own machine): won finishes its step, lost
## asks again a little later.
func bout_done(kind: String, ok: bool) -> void:
	if str(current().get("bout", "")) != kind:
		return
	if ok:
		complete(step)
	else:
		_rearm_t = REARM_SECS


## Vey's drills (Drills: the yard's checklist) while that's the step.
func _drills() -> void:
	if step == "vey_drills":
		Drills.start(get_tree())


func _ready() -> void:
	changed.connect(_drills)
	Dialogue.dialogue_event.connect(func(ev: String):
		if ev.begins_with("story:"):
			complete(ev.substr(6)))


## The talk's first node for dialogue `id` while the current step has one there
## ("<step>", or "until:<step>" for every step before that one).
func dialogue_entry(_id: String, data: Dictionary) -> String:
	if not active():
		return ""
	var hooks: Dictionary = data.get("story", {})
	if hooks.has(step):
		return str(hooks[step])
	for k in hooks.keys():
		if str(k).begins_with("until:") and index_of(step) < index_of(str(k).substr(6)):
			return str(hooks[k])
	return ""


func _process(delta: float) -> void:
	if not active():
		return
	if _rearm_t > 0.0:
		_rearm_t -= delta
		if _rearm_t <= 0.0:
			_bout_armed = true
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.5
	var p := _player()
	if p == null:
		return
	for place in NEAR.keys():
		if not won.has(place) and _beaten(place) and p.global_position.distance_to(place_pos(place)) < float(NEAR[place]):
			won[place] = true
	_check_won()
	_bout_near(p)


## A bout step: ask for the bout as the captain comes near its place (the host runs it: Net.request_arena).
func _bout_near(p: Player) -> void:
	var c := current()
	var kind := str(c.get("bout", ""))
	if kind == "":
		return
	if kind == "master:black_leg" and p.knows_black_leg():
		complete(step)
		return
	var at := place_pos(str(c["place"]))
	if at == Vector3.INF:
		return
	var d := p.global_position.distance_to(at)
	var r := float(BOUT_R[kind])
	if d < r and _bout_armed and _rearm_t <= 0.0:
		_bout_armed = false
		if kind == "brawl":
			get_tree().call_group("hud", "show_banner", "\"Oi. You. Grell owes us, and you'll do.\"",
				"A dock tough squares up. Fists only: %s to raise them, %s to punch." % [Drills.key_of("ready_weapon"), Drills.key_of("light_attack")], true)
		Net.request_arena(kind, 0)
	elif d > r * 2.0 and _rearm_t <= 0.0:
		_bout_armed = true


func _check_won() -> void:
	var c := current()
	if c.has("place") and won.has(str(c["place"])):
		complete(step)


## Is the fight at `place` won right now (on this screen: guests see the
## host's enemies' states)?
func _beaten(place: String) -> bool:
	var isl := island()
	match place:
		"smugglers":
			return isl != null and isl.smugglers != null and not isl.smugglers.grunts.is_empty() and isl.smugglers.alive_count() == 0
		"den":
			if isl == null or isl.den == null:
				return false
			for g in isl.den.grunts:
				if is_instance_valid(g) and g.captain and g.state == PirateGrunt.S.DEAD:
					return true
			return false
		"cave":
			return isl != null and isl.cave != null and is_instance_valid(isl.cave.queen) and isl.cave.queen.state == Scuttlebug.S.DEAD
		"redtide":
			var fort := get_tree().get_first_node_in_group("forts")
			return fort != null and is_instance_valid(fort.boss) and fort.boss.state == PirateGrunt.S.DEAD
	return false


## Where the objective is: the NPC to talk to, or the place.
func target_pos() -> Vector3:
	var c := current()
	if c.has("npc"):
		for n in get_tree().get_nodes_in_group("npcs"):
			if (n as NPC).npc_name == str(c["npc"]):
				return (n as Node3D).global_position + Vector3.UP * 2.2
		return Vector3.INF
	if c.has("place"):
		var isl := island()
		var p := _player()
		if isl and p and str(c["place"]) != "redtide":
			return isl.guide_to(str(c["place"]), p.global_position)
		return place_pos(str(c["place"]))
	return Vector3.INF


func place_pos(place: String) -> Vector3:
	if place == "redtide":
		var fort := get_tree().get_first_node_in_group("forts") as Node3D
		return fort.to_global(RedtideFort.ARENA) if fort else Vector3.INF
	var isl := island()
	return isl.place_of(place) if isl else Vector3.INF


func island() -> StarterIsland:
	if _island == null or not is_instance_valid(_island):
		var found := get_tree().current_scene.find_children("*", "StarterIsland", true, false) if get_tree().current_scene else []
		_island = found[0] if not found.is_empty() else null
	return _island as StarterIsland


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player
