extends Node
## The crew's journal (autoload "Journal", J opens it): every quest the crew has taken (Active, then Done),
## the rumours they've heard, and what quests earned the crew besides gold and items (`perks`: a discount at
## a shop, a favour someone owes). In co-op it's one journal for the whole crew: the host decides every change
## (a quest taken, a step done, the turn-in, a favour called in, a rumour) and every machine applies it
## (Net.everyone "_all_journal"); it's world state, kept in the host's save and sent to a captain who joins.
## Which quest you track (the objective HUD and its marker) is your own.
##
## Quests are defined by whoever makes them, the same on every machine (KitQuests on a generated island), and
## `register`ed here with their source (where a step's target is, how far along it is). An entry keeps what the
## journal shows (title, giver, island, each step's goal, the reward) so it reads the same once that island's gone.
## A quest def: {"id", "title", "giver" (name), "isle" (island name), "pos" (its middle, world), "src" ("npc" /
## "board" / "found"), "steps": [{"goal": text, "do": "reach" / "pickup" / "talk" / "clear" / "turnin", ...}],
## "reward": QuestRewards data, "cost": [[item id, n]] handed over at the turn-in}. The last step is the turn-in,
## to whoever gave it.

signal changed

## Captains this close to a turn-in get its reward.
## (before 1.22 a reward went only to captains this close to the turn-in; kept for old tests' and tools' sake)
const REWARD_REACH := 40.0
const RUMOURS := 40
## A charted place: the fog lifted this far round it (m).
const CHART_SEE := 28.0
const SCREEN := preload("res://scripts/ui/journal_screen.gd")

## id -> {"id", "title", "giver", "isle", "pos", "src", "goals": [String], "step", "done", "reward", "cost", "order"}
var entries := {}
## [{"text", "who", "isle"}], oldest first
var rumours: Array = []
## "discount:<shop id>" -> fraction; "favour:<quest id>" -> {"who", "gift"} while it's owed
var perks := {}
## "story", a quest id, or "": this captain's own
var tracked := "story"
var _order := 0
var _defs := {}
var _sources := {}
## Lines someone will tell when asked: dialogue event "rumour:<key>" -> [lines, who, island]
var _told := {}
var _layer: CanvasLayer
var _pc: PixelCanvas
var screen: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 29
	add_child(_layer)
	_pc = PixelCanvas.new()
	_pc.visible = false
	_layer.add_child(_pc)
	screen = SCREEN.new(self)
	_pc.ui.add_child(screen)
	Dialogue.dialogue_event.connect(func(ev: String):
		if ev.begins_with("rumour:") and _told.has(ev.substr(7)):
			var r: Array = _told[ev.substr(7)]
			for line in r[0]:
				hear(str(line), str(r[1]), str(r[2])))


# ==========================================================================
# Reading it
# ==========================================================================
func active() -> Array:
	return _sorted(entries.values().filter(func(e): return not e["done"]))


func done() -> Array:
	return _sorted(entries.values().filter(func(e): return e["done"]))


func _sorted(list: Array) -> Array:
	list.sort_custom(func(a, b): return int(a["order"]) > int(b["order"]))
	return list


func has(id: String) -> bool:
	return entries.has(id)


func is_done(id: String) -> bool:
	return entries.has(id) and bool(entries[id]["done"])


## The step the crew is on (-1: not taken).
func step_of(id: String) -> int:
	return int(entries[id]["step"]) if entries.has(id) else -1


## Taken, not done, and on its last step: the giver can be told.
func at_turnin(id: String) -> bool:
	return entries.has(id) and not entries[id]["done"] and int(entries[id]["step"]) == (entries[id]["goals"] as Array).size() - 1


func def(id: String) -> Dictionary:
	return _defs.get(id, {})


## What to do now, with how far along it is ("Bring three fish to Kai (1/3)").
func goal(id: String) -> String:
	var e: Dictionary = entries[id]
	if e["done"]:
		return "Done"
	var g := str(e["goals"][int(e["step"])])
	var src = _sources.get(id)
	return g + (src.progress(_defs[id], int(e["step"])) if is_instance_valid(src) else "")


## Where the current step is (the island's middle while its island isn't here).
func target(id: String) -> Vector3:
	var src = _sources.get(id)
	if is_instance_valid(src):
		return src.target(_defs[id], int(entries[id]["step"]))
	return entries[id]["pos"]


## The current step is a person to talk to (the marker goes once you're beside them).
func target_is_person(id: String) -> bool:
	var src = _sources.get(id)
	return is_instance_valid(src) and src.is_person(_defs[id], int(entries[id]["step"]))


func discount(shop_id: String) -> float:
	return float(perks.get("discount:" + shop_id, 0.0))


func favour_owed(id: String) -> bool:
	return perks.has("favour:" + id)


# ==========================================================================
# Changing it (asked of the host, applied everywhere)
# ==========================================================================
## A quest made by `source` (the same def on every machine).
func register(q: Dictionary, source: Node) -> void:
	_defs[q["id"]] = q
	_sources[q["id"]] = source


func take(id: String) -> void:
	var q: Dictionary = _defs[id]
	_ask("take", [{"id": id, "title": q["title"], "giver": q["giver"], "isle": q["isle"], "pos": q["pos"], "src": q["src"],
		"goals": q["steps"].map(func(s): return str(s["goal"])), "step": 0, "done": false, "reward": q["reward"], "cost": q.get("cost", []),
		"by": Net.my_id()}])


## Drop a quest the crew doesn't want any more (it leaves the journal and the map; it can be taken again).
func abandon(id: String) -> void:
	if _live(id):
		_ask("drop", [id])


## Step `n` of quest `id` is done (by any captain: the host takes the first word of it).
func advance(id: String, n: int) -> void:
	if step_of(id) == n:
		_ask("step", [id, n])


## Told the giver: the reward to every captain in the crew, wherever they are (1.22); the one turning in hands over the cost.
func turn_in(id: String, at: Vector3) -> void:
	if at_turnin(id):
		_ask("done", [id, at, Net.my_id()])


func call_favour(id: String) -> void:
	if favour_owed(id):
		_ask("favour", [id, Net.my_id()])


## `lines` go in the Rumours once `who` tells them (a dialogue node's "event": "rumour:<key>").
func tell(key: String, lines: Array, who: String, isle: String) -> void:
	_told[key] = [lines, who, isle]


func hear(text: String, who: String, isle: String) -> void:
	if not rumours.any(func(r): return r["text"] == text):
		_ask("rumour", [{"text": text, "who": who, "isle": isle}])


func track(id: String) -> void:
	tracked = id
	changed.emit()


func _ask(op: String, args: Array) -> void:
	if Net.is_host():
		decide(op, args)
	else:
		Net.journal_ask(op, args)


## Host: is this change still good (nobody beat them to it)? Then everyone makes it.
func decide(op: String, args: Array) -> void:
	match op:
		"take":
			if entries.has(args[0]["id"]):
				return
		"step":
			if step_of(args[0]) != int(args[1]) or is_done(args[0]):
				return
		"done":
			if not at_turnin(args[0]):
				return
			args = args + [_chart_pick(entries[args[0]], args[1])]
		"favour":
			if not favour_owed(args[0]):
				return
		"drop":
			if not _live(args[0]):
				return
		"rumour":
			if rumours.any(func(r): return r["text"] == args[0]["text"]):
				return
	Net.everyone("_all_journal", [op, args])


## A "chart" reward: the place on the turn-in's island the crew hasn't found that's furthest from them
## ([fog key, spot id, name, fog cells a side, the cells round it]), or [] (nothing left: gold instead).
func _chart_pick(e: Dictionary, at: Vector3) -> Array:
	if not (e["reward"] as Dictionary).get("chart", false):
		return []
	var d := MapIsles.at(get_tree(), Vector2(at.x, at.z))
	if d.is_empty():
		return []
	var lp := Vector2(at.x, at.z) - (d["o"] as Vector2)
	var best := {}
	for s in d["spots"]:
		if not MapFog.found(GameManager, str(d["key"]), str(s["id"])) and (best.is_empty() or lp.distance_to(s["at"]) > lp.distance_to(best["at"])):
			best = s
	if best.is_empty():
		return []
	return [str(d["key"]), str(best["id"]), str(best["name"]), int(d["n"]), MapFog.cells_near(d, best["at"], CHART_SEE)]


## Every machine (Net._all_journal).
func apply(op: String, args: Array) -> void:
	match op:
		"take":
			var e: Dictionary = args[0].duplicate(true)
			_order += 1
			e["order"] = _order
			entries[e["id"]] = e
			# the captain who took it follows it at once (a crewmate's new quest only if you follow nothing)
			if int(e.get("by", -1)) == Net.my_id() or not tracking():
				tracked = e["id"]
			_toast("New quest: %s" % e["title"])
			UIStyle.sfx("quest_accept")
		"step":
			var e: Dictionary = entries[args[0]]
			var n := int(args[1])
			e["step"] = n + 1
			var d := def(e["id"])
			_toast(str(d["steps"][n].get("said", goal(e["id"]))) if not d.is_empty() else goal(e["id"]))
			if tracked == e["id"]:
				get_tree().call_group("hud", "show_objective_banner", goal(e["id"]))
		"done":
			_finish(args[0], args[1], int(args[2]), args[3])
		"favour":
			var f: Dictionary = perks["favour:" + str(args[0])]
			perks.erase("favour:" + str(args[0]))
			var me := _me()
			if int(args[1]) == Net.my_id() and me:
				_toast("%s's favour: %s" % [f["who"], QuestRewards.give({"items": f["gift"]}, me)])
		"drop":
			var title := str(entries[args[0]]["title"]) if entries.has(args[0]) else ""
			entries.erase(args[0])
			if tracked == args[0]:
				var left := active()
				tracked = left[0]["id"] if not left.is_empty() else "story"
			_toast("Quest dropped: %s" % title)
		"rumour":
			rumours.append(args[0])
			if rumours.size() > RUMOURS:
				rumours.pop_front()
	changed.emit()


func _finish(id: String, at: Vector3, by: int, chart: Array) -> void:
	var e: Dictionary = entries[id]
	e["done"] = true
	_order += 1
	e["order"] = _order
	var r: Dictionary = e["reward"]
	if r.has("discount"):
		var k := "discount:" + str(r["discount"][0])
		perks[k] = maxf(float(perks.get(k, 0.0)), float(r["discount"][1]))
	if r.has("favour"):
		perks["favour:" + id] = r["favour"]
	if not chart.is_empty():
		MapFog.apply(GameManager, str(chart[0]), int(chart[3]), chart[4])
		MapFog.find(GameManager, str(chart[0]), str(chart[1]))
		_toast("%s marked %s on your map (M)" % [e["giver"], chart[2]])
	var me := _me()
	if me:
		if by == Net.my_id():
			QuestRewards.pay(e["cost"], me)
		# (1.22: the whole crew's, wherever they are; `at` is only where the giver stood)
		if true:
			var got := QuestRewards.give(r, me)
			if r.get("chart", false) and chart.is_empty():
				me.inventory_component.add_item(ItemDB.get_item("gold"), QuestRewards.MAP_GOLD)
				got += ", %d gold" % QuestRewards.MAP_GOLD
			get_tree().call_group("hud", "show_banner", "Quest done: %s" % e["title"], got, true)
	UIStyle.sfx("quest_done")
	if tracked == id:
		var left := active()
		tracked = left[0]["id"] if not left.is_empty() else "story"


func _live(id: String) -> bool:
	return entries.has(id) and not entries[id]["done"]


## Something to follow: the story while it's on, or a quest not yet done.
func tracking() -> bool:
	return (tracked == "story" and Story.active()) or _live(tracked)


func _me() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _toast(text: String) -> void:
	get_tree().call_group("hud", "show_toast", text)


# ==========================================================================
# Saves and joining
# ==========================================================================
func to_dict() -> Dictionary:
	return {"entries": entries.duplicate(true), "rumours": rumours.duplicate(true), "perks": perks.duplicate(true), "order": _order}


func from_dict(d: Dictionary) -> void:
	entries = (d.get("entries", {}) as Dictionary).duplicate(true)
	rumours = (d.get("rumours", []) as Array).duplicate(true)
	perks = (d.get("perks", {}) as Dictionary).duplicate(true)
	_order = int(d.get("order", 0))
	changed.emit()


func reset() -> void:
	from_dict({})
	tracked = "story"


# ==========================================================================
# The screen (J)
# ==========================================================================
func is_open() -> bool:
	return _pc.visible


func _can_open() -> bool:
	var p := _me()
	return p != null and p.is_local and not p.input_locked and not ChatBox.typing and RadialWheel.shown == null \
		and not GameMenu.is_open() and not Dialogue.active and not CharacterCreator.active \
		and get_tree().get_first_node_in_group("title_screen") == null and get_tree().get_first_node_in_group("hud") != null


func open() -> void:
	_pc.visible = true
	Net.set_paused(true)
	get_tree().call_group("hud", "set_menu_open", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UIStyle.sfx("open")
	screen.on_open()


func close() -> void:
	_pc.visible = false
	Net.set_paused(false)
	get_tree().call_group("hud", "set_menu_open", false)
	UIStyle.sfx("close")
	Settings.capture_mouse()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		if is_open() and event is InputEventKey:
			get_viewport().set_input_as_handled()
		return
	var k: int = event.keycode
	if is_open():
		if k >= KEY_F1 and k <= KEY_F12:
			return
		get_viewport().set_input_as_handled()
		if k == KEY_J or event.is_action_pressed("pause"):
			close()
		else:
			screen.key(event)
	elif k == KEY_J and not event.alt_pressed and not event.ctrl_pressed and _can_open():
		get_viewport().set_input_as_handled()
		open()
