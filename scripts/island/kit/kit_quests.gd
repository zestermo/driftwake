class_name KitQuests
extends Node
## An island's small quests (IslandLife plans them from its POIs and fills their texts), in the crew's
## shared Journal: each is `register`ed there with this node as its source (where each step is, how far
## along it is). Ids carry the island's seed, so chain seeds don't share them. Kinds, each a few steps and
## always turned in to whoever gave it: lost (an item dropped at a POI: pick it up, bring it back), scout
## (go and see a POI, tell them), deliver (a parcel to another named villager, then tell the giver), fetch
## (bring items: handed over at the turn-in), clear (a POI whose "clear" Callable says it's cleared: a roost,
## a roaming beast). Rewards are gold, items, a map, a discount or a favour (QuestRewards), never XP.
## `offer` adds a quest to its giver's dialogue tree, `hand_over` to a deliver quest's recipient's.

const TICK := 0.5
const KINDS := ["lost", "scout", "deliver", "fetch", "clear"]
const GOLD := {"lost": [25, 12], "scout": [20, 10], "deliver": [15, 8], "fetch": [35, 15], "clear": [45, 20], "bounty": [40, 20], "lair": [30, 15], "beast": [80, 35]}
## The notice board's kinds (IslandVillage.jobs: camp, lair, beast), each turned in to whoever posted it.
const NOTICES := {"camp": "bounty", "lair": "lair", "beast": "beast"}
## Each kind's steps: [what it is, the journal's goal]. The last is the turn-in.
const STEPS := {
	"lost": [["pickup", "Find the {thing} {place}"], ["turnin", "Bring the {thing} back to {who}"]],
	"scout": [["reach", "{Look}"], ["turnin", "Tell {who} what you saw"]],
	"deliver": [["talk", "Take {parcel} to {recipient}, {where}"], ["turnin", "Tell {who} it's delivered"]],
	"fetch": [["turnin", "Bring {what} to {who}"]],
	"clear": [["clear", "{Verb} {name}"], ["turnin", "Tell {who} it's done"]],
	"bounty": [["clear", "Defeat {name} at the pirate camp"], ["turnin", "Report to {poster}"]],
	"lair": [["clear", "Clear every creature from {name}"], ["turnin", "Report to {poster}"]],
	"beast": [["clear", "Slay {name}"], ["turnin", "Report to {poster}"]],
}
const NOTICE_TITLE := {"bounty": "Bounty: {name}", "lair": "Clear {name}", "beast": "Slay {name}"}
## A person to talk to: the marker floats this far over their head.
const HEAD := 2.2

## {"id", "kind", "title", "giver", "giver_i", "isle", "pos", "src", "steps", "reward", "cost", the texts (ask,
## plea, accept, decline, taken, remind_choice, remind, done, thanks, favour_ask, favour_thanks, found), and by
## kind: lost "at" "yaw" "search"; scout "point" "r"; deliver "recipient" "recipient_i" "hand" "got"; clear "clear" "poi"}
var quests: Array = []
var _marks := {}
var _people := {}
var _t := 0.0
var _glint_t := 0.0


func _ready() -> void:
	Dialogue.dialogue_event.connect(_on_event)


## The index of `q`'s first step of kind `what` (-1: none).
static func step_index(q: Dictionary, what: String) -> int:
	var steps: Array = q["steps"]
	for i in range(steps.size()):
		if steps[i]["do"] == what:
			return i
	return -1


## Adds `q` (texts filled) to the journal's quests and what it needs in the world: a lost thing to pick up.
func add(q: Dictionary, isl: GenIsland) -> void:
	quests.append(q)
	Journal.register(q, self)
	if q["kind"] == "scout":
		q["point"] = isl.to_global(Vector3(q["at"].x, float(q["y"]), q["at"].y))
	if q.has("poi_at"):
		var a: Vector2 = q["poi_at"]
		q["poi"] = isl.to_global(Vector3(a.x, isl.hv(a) + 1.5, a.y))
	if step_index(q, "pickup") < 0:
		return
	var n := Node3D.new()
	n.name = "Lost_%s" % q["id"]
	var mi := MeshInstance3D.new()
	mi.mesh = Props.sack_mesh()
	mi.scale = Vector3.ONE * 0.6
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 120.0
	n.add_child(mi)
	var it := Interactable.new()
	it.name = "Search"
	it.collision_layer = NPC.INTERACT_LAYER
	it.collision_mask = 0
	it.prompt_text = str(q["search"])
	it.gesture = "pickup"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.4
	cs.shape = sph
	cs.position = Vector3(0, 0.5, 0)
	it.add_child(cs)
	n.add_child(it)
	it.interacted.connect(func(_p): _pick_up(q))
	isl.place(n, isl, q["at"], float(q["yaw"]))
	_marks[q["id"]] = n
	_show_mark(q)


func mark(q: Dictionary) -> Node3D:
	return _marks[q["id"]]


## The giver's choices and nodes for `q` (into its menu and its nodes).
func offer(q: Dictionary, menu: Array, nodes: Dictionary) -> void:
	var id: String = q["id"]
	var n := "q_" + id
	var cost: Array = q.get("cost", [])
	menu.append({"text": q["ask"], "next": n + "_offer", "if": func(): return not Journal.has(id)})
	nodes[n + "_offer"] = {"text": q["plea"], "choices": [{"text": q["accept"], "next": n + "_take"}, {"text": q["decline"], "next": "menu"}]}
	nodes[n + "_take"] = {"text": q["taken"], "event": "isle_q:%s:take" % id, "next": "menu"}
	menu.append({"text": q["remind_choice"], "next": n + "_remind",
		"if": func(): return Journal.has(id) and not Journal.is_done(id) and not (Journal.at_turnin(id) and _can_pay(cost))})
	nodes[n + "_remind"] = {"text": q["remind"], "next": "menu"}
	menu.append({"text": q["done"], "next": n + "_pay", "if": func(): return Journal.at_turnin(id) and _can_pay(cost)})
	nodes[n + "_pay"] = {"text": q["thanks"] + ["(%s)" % QuestRewards.text(q["reward"])], "event": "isle_q:%s:pay" % id, "next": "menu"}
	_favour(q, menu, nodes)


## A quest that left its giver owing the crew a favour: called in once.
func _favour(q: Dictionary, choices: Array, nodes: Dictionary) -> void:
	var id: String = q["id"]
	if q["reward"].has("favour"):
		choices.append({"text": q["favour_ask"], "next": "q_%s_favour" % id, "if": func(): return Journal.favour_owed(id)})
		nodes["q_%s_favour" % id] = {"text": q["favour_thanks"], "event": "isle_q:%s:favour" % id, "next": "menu"}


## Whoever a found quest is for (a dead man's note): the turn-in, nothing to offer or remind.
func receive(q: Dictionary, choices: Array, nodes: Dictionary) -> void:
	var id: String = q["id"]
	choices.append({"text": q["done"], "next": "q_%s_pay" % id, "if": func(): return Journal.at_turnin(id)})
	nodes["q_%s_pay" % id] = {"text": q["thanks"] + ["(%s)" % QuestRewards.text(q["reward"])], "event": "isle_q:%s:pay" % id, "next": "menu"}


## A deliver quest's recipient: the parcel handed over.
func hand_over(q: Dictionary, menu: Array, nodes: Dictionary) -> void:
	var id: String = q["id"]
	var n := "q_" + id
	var at := step_index(q, "talk")
	menu.append({"text": q["hand"], "next": n + "_got", "if": func(): return Journal.step_of(id) == at and not Journal.is_done(id)})
	nodes[n + "_got"] = {"text": q["got"], "event": "isle_q:%s:step:%d" % [id, at], "next": "menu"}


## A notice on the board (into the board's choices and nodes): read it and it's the crew's.
func post(q: Dictionary, choices: Array, nodes: Dictionary) -> void:
	var id: String = q["id"]
	var n := "q_" + id
	choices.append({"text": "%s  (%s)" % [q["title"], QuestRewards.text(q["reward"])], "next": n + "_notice", "if": func(): return not Journal.has(id)})
	nodes[n + "_notice"] = {"text": [q["notice"], "You tear the notice down and pocket it."], "event": "isle_q:%s:take" % id, "next": "end"}


## Whoever posted a notice: the report once it's done (and a word while it isn't).
func report(q: Dictionary, choices: Array, nodes: Dictionary) -> void:
	var id: String = q["id"]
	var n := "q_" + id
	choices.append({"text": "About your notice: %s" % q["title"], "next": n + "_remind", "if": func(): return Journal.has(id) and not Journal.is_done(id) and not Journal.at_turnin(id)})
	nodes[n + "_remind"] = {"text": [q["notice"]], "next": "menu"}
	choices.append({"text": "Your notice: %s. It's done." % q["title"], "next": n + "_pay", "if": func(): return Journal.at_turnin(id)})
	nodes[n + "_pay"] = {"text": [q["posted"], "(%s)" % QuestRewards.text(q["reward"])], "event": "isle_q:%s:pay" % id, "next": "menu"}
	_favour(q, choices, nodes)


func _can_pay(cost: Array) -> bool:
	var me := get_tree().get_first_node_in_group("player") as Player
	return cost.is_empty() or (me != null and QuestRewards.can_pay(cost, me))


func _pick_up(q: Dictionary) -> void:
	Journal.advance(q["id"], step_index(q, "pickup"))
	_show_mark(q)


func _show_mark(q: Dictionary) -> void:
	var n: Node3D = _marks[q["id"]]
	var on := Journal.step_of(q["id"]) == step_index(q, "pickup") and not Journal.is_done(q["id"])
	n.visible = on
	(n.get_node("Search") as Interactable).collision_layer = NPC.INTERACT_LAYER if on else 0


func _on_event(ev: String) -> void:
	if not ev.begins_with("isle_q:"):
		return
	var parts := ev.split(":")
	var q := find(parts[1])
	# (every standing island hears every island's events)
	if q.is_empty():
		return
	match parts[2]:
		"take":
			Journal.take(q["id"])
			_t = 0.0
		"step":
			Journal.advance(q["id"], int(parts[3]))
		"pay":
			Journal.turn_in(q["id"], (get_tree().get_first_node_in_group("player") as Node3D).global_position)
		"favour":
			Journal.call_favour(q["id"])


func find(id: String) -> Dictionary:
	for q in quests:
		if q["id"] == id:
			return q
	return {}


# --------------------------------------------------------------------------
# The journal's source: where a step is and how far along it is
# --------------------------------------------------------------------------
func target(q: Dictionary, step: int) -> Vector3:
	var s: Dictionary = q["steps"][step]
	match str(s["do"]):
		"pickup":
			return mark(q).global_position + Vector3(0, 0.5, 0)
		"reach":
			return q["point"]
		"clear":
			return q["poi"]
		"talk":
			return _person_at(str(s["who"]))
	return _person_at(str(q["giver"]))


func is_person(q: Dictionary, step: int) -> bool:
	return q["steps"][step]["do"] in ["talk", "turnin"]


## A turn-in that takes items: how many of them you have.
func progress(q: Dictionary, step: int) -> String:
	var cost: Array = q.get("cost", [])
	if q["steps"][step]["do"] != "turnin" or cost.is_empty():
		return ""
	var me := get_tree().get_first_node_in_group("player") as Player
	var have := me.inventory_component.count(str(cost[0][0])) if me else 0
	return " (%d/%d)" % [mini(have, int(cost[0][1])), int(cost[0][1])]


func _person_at(who: String) -> Vector3:
	var n = _people.get(who)
	if not is_instance_valid(n):
		n = null
		for p in get_tree().get_nodes_in_group("npcs"):
			if (p as NPC).npc_name == who:
				n = p
		_people[who] = n
	return (n as Node3D).global_position + Vector3.UP * HEAD if n and (n as Node3D).visible else Vector3.INF


## Twice a second for the local captain: a place reached, a POI cleared (the host says), lost things shown.
func _process(delta: float) -> void:
	_t -= delta
	_glint_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me == null:
		return
	var glint := _glint_t <= 0.0
	if glint:
		_glint_t = 2.5
	for q in quests:
		var id: String = q["id"]
		if _marks.has(id):
			_show_mark(q)
		if not Journal.has(id) or Journal.is_done(id):
			continue
		var step := Journal.step_of(id)
		match str(q["steps"][step]["do"]):
			"reach":
				if me.global_position.distance_to(q["point"]) < float(q["r"]):
					Journal.advance(id, step)
			"clear":
				if Net.is_host() and (q["clear"] as Callable).call():
					Journal.advance(id, step)
			"pickup":
				var n: Node3D = _marks[id]
				if glint and me.global_position.distance_to(n.global_position) < 40.0:
					FX.glint(n.global_position + Vector3(0, 0.35, 0), Color(1.0, 0.9, 0.55), 0.5)
