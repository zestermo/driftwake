class_name KitQuests
extends Node
## An island's small quests (IslandLife plans them from its POIs and fills their
## texts): each captain's own, like the job board's jobs, kept in Dialogue flags
## "<id>_taken / _got / _paid" (the id carries the island's seed, so chain seeds
## don't share it). Kinds: lost (an item dropped at a POI: pick it up), scout (go
## and see a POI), deliver (a parcel to another named villager), fetch (bring
## items), clear (a POI whose "clear" Callable says it's cleared: a roost, a
## roaming beast). The giver pays. `offer` adds a quest to its giver's dialogue
## tree, `hand_over` to the recipient's.

const TICK := 0.5
const KINDS := ["lost", "scout", "deliver", "fetch", "clear"]
const GOLD := {"lost": [25, 12], "scout": [20, 10], "deliver": [15, 8], "fetch": [35, 15], "clear": [45, 20]}

## {"id", "kind", "title", "giver", "gold", "xp", the texts (ask, plea, accept, decline, taken,
## remind_choice, remind, done, thanks, found), and by kind: lost "at" "search"; scout "at" "y" "r";
## deliver "recipient" "hand" "got"; fetch "item" "count" "short"; clear "clear"}
var quests: Array = []
var _marks := {}
var _t := 0.0
var _glint_t := 0.0


func _ready() -> void:
	Dialogue.dialogue_event.connect(_on_event)


func flag(q: Dictionary, state: String) -> String:
	return "%s_%s" % [q["id"], state]


func has(q: Dictionary, state: String) -> bool:
	return Dialogue.has_flag(flag(q, state))


## Adds `q` (texts filled) and what it needs in the world: a lost thing to pick up.
func add(q: Dictionary, isl: GenIsland) -> void:
	quests.append(q)
	if q["kind"] == "scout":
		q["point"] = isl.to_global(Vector3(q["at"].x, float(q["y"]), q["at"].y))
	if q["kind"] != "lost":
		return
	var n := Node3D.new()
	n.name = "Lost_%s" % q["id"]
	var mi := MeshInstance3D.new()
	mi.mesh = Props.sack_mesh()
	mi.scale = Vector3.ONE * 0.6
	n.add_child(mi)
	var it := Interactable.new()
	it.name = "Search"
	it.collision_layer = NPC.INTERACT_LAYER
	it.collision_mask = 0
	it.prompt_text = str(q["search"])
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
	var n := "q_" + str(q["id"])
	menu.append({"text": q["ask"], "next": n + "_offer", "hide_if": flag(q, "taken")})
	nodes[n + "_offer"] = {"text": q["plea"], "choices": [{"text": q["accept"], "next": n + "_take"}, {"text": q["decline"], "next": "menu"}]}
	nodes[n + "_take"] = {"text": q["taken"], "event": "isle_q:%s:take" % q["id"], "set_flag": flag(q, "taken"), "next": "menu"}
	menu.append({"text": q["remind_choice"], "next": n + "_remind", "requires": flag(q, "taken"), "hide_if": flag(q, "got")})
	nodes[n + "_remind"] = {"text": q["remind"], "next": "menu"}
	menu.append({"text": q["done"], "next": n + "_pay", "requires": flag(q, "got"), "hide_if": flag(q, "paid")})
	nodes[n + "_pay"] = {"text": q["thanks"] + ["(%d gold)" % int(q["gold"])], "event": "isle_q:%s:pay" % q["id"], "set_flag": flag(q, "paid"), "next": "menu"}


## A deliver quest's recipient: the parcel handed over.
func hand_over(q: Dictionary, menu: Array, nodes: Dictionary) -> void:
	var n := "q_" + str(q["id"])
	menu.append({"text": q["hand"], "next": n + "_got", "requires": flag(q, "taken"), "hide_if": flag(q, "got")})
	nodes[n + "_got"] = {"text": q["got"], "event": "isle_q:%s:got" % q["id"], "set_flag": flag(q, "got"), "next": "menu"}


func _pick_up(q: Dictionary) -> void:
	if not has(q, "taken") or has(q, "got"):
		return
	Dialogue.set_flag(flag(q, "got"))
	_show_mark(q)
	get_tree().call_group("hud", "show_toast", str(q["found"]))


func _show_mark(q: Dictionary) -> void:
	var n: Node3D = _marks[q["id"]]
	var on := has(q, "taken") and not has(q, "got")
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
			get_tree().call_group("hud", "show_toast", "New task: %s" % q["title"])
			_t = 0.0
		"got":
			get_tree().call_group("hud", "show_toast", str(q["found"]))
		"pay":
			_pay(q)


func find(id: String) -> Dictionary:
	for q in quests:
		if q["id"] == id:
			return q
	return {}


func _pay(q: Dictionary) -> void:
	var me := get_tree().get_first_node_in_group("player") as Player
	if q["kind"] == "fetch":
		var item := ItemDB.get_item(str(q["item"]))
		if me.inventory_component.count(str(q["item"])) < int(q["count"]):
			Dialogue.set_flag(flag(q, "paid"), false)
			Dialogue.set_flag(flag(q, "got"), false)
			get_tree().call_group("hud", "show_toast", str(q["short"]))
			return
		me.inventory_component.remove_item(item, int(q["count"]))
	me.inventory_component.add_item(ItemDB.get_item("gold"), int(q["gold"]))
	GameManager.award_xp(int(q["xp"]), me.global_position)
	get_tree().call_group("hud", "show_toast", "Done: %s" % q["title"])


## Twice a second for the local captain: a scouted place seen, items to fetch in hand, lost things shown.
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
		if not has(q, "taken") or has(q, "paid"):
			continue
		match str(q["kind"]):
			"scout":
				if not has(q, "got") and me.global_position.distance_to(q["point"]) < float(q["r"]):
					Dialogue.set_flag(flag(q, "got"))
					get_tree().call_group("hud", "show_banner", q["title"], str(q["found"]), true)
			"fetch":
				var enough: bool = (me as Player).inventory_component.count(str(q["item"])) >= int(q["count"])
				if enough != has(q, "got"):
					Dialogue.set_flag(flag(q, "got"), enough)
			"clear":
				if not has(q, "got") and (q["clear"] as Callable).call():
					Dialogue.set_flag(flag(q, "got"))
					get_tree().call_group("hud", "show_toast", str(q["found"]))
			"lost":
				_show_mark(q)
				var n: Node3D = _marks[q["id"]]
				if glint and n.visible and me.global_position.distance_to(n.global_position) < 40.0:
					FX.glint(n.global_position + Vector3(0, 0.35, 0), Color(1.0, 0.9, 0.55), 0.5)
