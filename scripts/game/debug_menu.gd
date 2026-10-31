class_name DebugMenu
extends CanvasLayer
## The debug menu (1.27, Zach): F4 in a debug build (any run from the editor) opens a panel to give yourself items and
## gold, level the Captain and any tree (weapons, fruits, adventure), eat any Driftfruit, spawn grunts, and set off
## events (the stronghold's stages, weather, time). Made by DevCapture, debug builds only; nothing of it ships.
## Our own captain only: in co-op, world events go through Net like the game's own.

const KEY := KEY_F4

var _panel: PanelContainer
var _items: OptionButton
var _qty: SpinBox
var _trees: OptionButton
var _fruits: OptionButton
var _spawns: OptionButton
var _warps: OptionButton
var _gadgets: OptionButton
var _gtier: OptionButton
var _status: Label
## The spawn list: [label, Callable(at: Vector3, yaw: float)] filled by _refill (every theme's beasts, then
## extra_spawns()). The warp list: [label, chain node id].
var _spawn_list: Array = []
var _warp_list: Array = []


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY:
		get_viewport().set_input_as_handled()
		_panel.visible = not _panel.visible
		if _panel.visible:
			_refill()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Settings.capture_mouse()


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _say(t: String) -> void:
	_status.text = t
	print("[debug] ", t)


# --------------------------------------------------------------------------
# The panel
# --------------------------------------------------------------------------
func _build() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(8, 8)
	_panel.custom_minimum_size = Vector2(300, 0)
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 430)
	_panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(286, 0)
	scroll.add_child(v)
	var title := Label.new()
	title.text = "DEBUG (F4)"
	v.add_child(title)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.custom_minimum_size = Vector2(280, 0)
	v.add_child(_status)
	# items
	_head(v, "Items")
	_items = OptionButton.new()
	v.add_child(_items)
	var row := HBoxContainer.new()
	v.add_child(row)
	_qty = SpinBox.new()
	_qty.min_value = 1
	_qty.max_value = 999
	_qty.value = 1
	row.add_child(_qty)
	_btn(row, "Give", _give_item)
	_btn(v, "+1000 gold", func(): _give("gold", 1000))
	# the Captain and the trees
	_head(v, "Levels")
	row = HBoxContainer.new()
	v.add_child(row)
	_btn(row, "Captain +1", func(): _levels(1))
	_btn(row, "Captain +5", func(): _levels(5))
	_trees = OptionButton.new()
	v.add_child(_trees)
	row = HBoxContainer.new()
	v.add_child(row)
	_btn(row, "Tree +5", func(): _tree_levels(5))
	_btn(row, "Tree to 30", func(): _tree_levels(30))
	_btn(v, "Everything maxed (master_all)", _max_all)
	# fruits
	_head(v, "Driftfruit")
	_fruits = OptionButton.new()
	for f in DevilFruits.FRUITS.keys():
		_fruits.add_item(str(f))
	v.add_child(_fruits)
	row = HBoxContainer.new()
	v.add_child(row)
	_btn(row, "Eat it", _eat)
	_btn(row, "Full ult", func(): _player().power.ult = PowerComponent.ULT_MAX)
	# the captain
	_head(v, "You")
	row = HBoxContainer.new()
	v.add_child(row)
	_btn(row, "Heal", _heal)
	_btn(row, "Energy", func(): _player().power.energy = _player().power.max_energy())
	_btn(row, "Cooldowns", func(): _player().power.cooldowns.clear(); _player().gadgets.ready_at.clear())
	# (1.28) gadgets
	_head(v, "Gadgets")
	row = HBoxContainer.new()
	v.add_child(row)
	_gadgets = OptionButton.new()
	for g in GadgetData.GADGETS.keys():
		_gadgets.add_item(str(g))
	row.add_child(_gadgets)
	_gtier = OptionButton.new()
	for t in GadgetData.TIER_NAMES:
		_gtier.add_item(str(t))
	row.add_child(_gtier)
	row = HBoxContainer.new()
	v.add_child(row)
	_btn(row, "Build it", _give_gadget)
	_btn(row, "Refill all", _refill_gadgets)
	_btn(row, "All blueprints", _all_blueprints)
	# spawns
	_head(v, "Spawn (ahead of you)")
	row = HBoxContainer.new()
	v.add_child(row)
	_btn(row, "Grunt", func(): _spawn(["sword"]))
	_btn(row, "Rifleman", func(): _spawn(["rifle"]))
	_btn(row, "Squad of 4", func(): _spawn(["sword", "sword", "rifle", "sword"]))
	_spawns = OptionButton.new()
	v.add_child(_spawns)
	_btn(v, "Spawn it", _spawn_picked)
	# warps
	_head(v, "Warp (the crew and the ship)")
	_warps = OptionButton.new()
	v.add_child(_warps)
	_btn(v, "Go", _warp_picked)
	# events
	_head(v, "Events")
	_btn(v, "Stronghold: on the chart", func(): _flag("stronghold_known"))
	_btn(v, "Stronghold: both seals (keep opens)", func(): _flag("sh_seal_arsenal"); _flag("sh_seal_prison"))
	_btn(v, "Stronghold: Commodore falls (the Scouring)", func(): _flag("sh_seal_keep"))
	row = HBoxContainer.new()
	v.add_child(row)
	_btn(row, "Next weather (F6)", func(): _key(KEY_F6))
	_btn(row, "+2 hours (F7)", func(): _key(KEY_F7))
	_btn(v, "Close", func(): _panel.visible = false; Settings.capture_mouse())


func _head(v: Control, t: String) -> void:
	v.add_child(HSeparator.new())
	var l := Label.new()
	l.text = t
	v.add_child(l)


func _btn(parent: Control, t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(f)
	parent.add_child(b)
	return b


## The lists that depend on the game as it is now: every item on disk, every tree.
func _refill() -> void:
	_items.clear()
	var ids: Array = []
	var d := DirAccess.open("res://resources/items")
	if d:
		for f in d.get_files():
			if f.ends_with(".tres"):
				ids.append(f.get_basename())
	ids.sort()
	for id in ids:
		_items.add_item(str(id))
	_spawns.clear()
	_spawn_list = []
	for th in IslandThemes.all():
		for kind in (th as ThemeDef).beasts.keys():
			_spawn_list.append(["%s: %s" % [th.name, kind], _spawn_beast.bind(th.name, str(kind))])
	_spawn_list.append_array(extra_spawns())
	for s in _spawn_list:
		_spawns.add_item(str(s[0]))
	_warps.clear()
	_warp_list = []
	var w := get_tree().get_first_node_in_group("world_gen")
	if w and w.chain():
		var c: Chain = w.chain()
		for n in c.nodes:
			_warp_list.append(["%s (%s, lv %d)" % [n["name"], n["theme"], int(n["level"])], int(n["id"])])
		if c.stronghold_id() >= 0:
			_warp_list.append(["%s (the stronghold)" % c.stronghold["name"], c.stronghold_id()])
	for wp in _warp_list:
		_warps.add_item(str(wp[0]))
	_trees.clear()
	for t in SkillTrees.nodes().values().map(func(n): return str(n["tree"])).reduce(func(acc, t): return acc if t in acc else acc + [t], []):
		_trees.add_item(str(t))


# --------------------------------------------------------------------------
# What the buttons do
# --------------------------------------------------------------------------
func _give(id: String, n: int) -> void:
	var it := ItemDB.get_item(id)
	if it == null or _player() == null:
		_say("No item %s" % id)
		return
	_player().inventory_component.add_item(it, n)
	_say("Gave %d %s" % [n, id])


func _give_item() -> void:
	if _items.selected >= 0:
		_give(_items.get_item_text(_items.selected), int(_qty.value))


func _levels(n: int) -> void:
	var pr := _player().progression
	for i in range(n):
		pr.add_xp(Progression.xp_to_next(pr.level) - pr.xp)
	_say("Captain level %d" % pr.level)


func _tree_levels(n: int) -> void:
	if _trees.selected < 0:
		return
	var t := _trees.get_item_text(_trees.selected)
	var pr := _player().progression
	var lv := int((pr.mastery.get(t, {"lv": 1}) as Dictionary).get("lv", 1))
	lv = mini(30, n if n >= 30 else lv + n)
	pr.mastery[t] = {"lv": lv, "xp": 0}
	pr.call("_sync_tree", t, false)
	pr.changed.emit()
	_say("%s mastery %d" % [t, lv])


func _max_all() -> void:
	_player().progression.master_all()
	_player().call("_recalc_stats")
	_say("Everything maxed")


func _eat(_x = null) -> void:
	var f := _fruits.get_item_text(_fruits.selected)
	_player().power.eat(f)
	_say("Ate the %s fruit" % f)


func _give_gadget() -> void:
	var g := _gadgets.get_item_text(_gadgets.selected)
	_player().gadgets.give(g, _gtier.selected)
	_say("Built %s %s onto the belt" % [g, GadgetData.TIER_NAMES[_gtier.selected]])


func _refill_gadgets() -> void:
	var b: GadgetBelt = _player().gadgets
	for g in b.owned.keys():
		b.refill(g)
	b.ready_at.clear()
	_say("Gadgets refilled")


func _all_blueprints() -> void:
	for b in Gadgets.blueprint_ids():
		Gadgets.teach(_player(), b)
	_say("Every blueprint learned")


func _heal() -> void:
	var hc := _player().health_component
	hc.current_health = hc.max_health
	hc.health_changed.emit(hc.current_health, hc.max_health)
	_say("Healed")


func _spawn(roles: Array) -> void:
	var p := _player()
	if not get_node("/root/Net").is_host():
		_say("Spawns are the host's")
		return
	var camp := GruntCamp.new()
	camp.name = "DebugCamp%d" % Engine.get_physics_frames()
	var fwd := -p.player_model.global_basis.z
	fwd.y = 0.0
	for i in range(roles.size()):
		camp.add_grunt({"post": fwd.normalized() * 6.0 + Vector3((i - roles.size() * 0.5) * 1.5, 0, 0), "role": roles[i], "seed": randi()})
	(get_tree().current_scene if get_tree().current_scene else p.get_parent()).add_child(camp)
	camp.global_position = p.global_position
	_say("Spawned %d" % roles.size())


## More for the spawn list: [label, Callable(at: Vector3, yaw: float)]. New kinds of things to spawn (leviathans, ships,
## sea stops) add a line here.
func extra_spawns() -> Array:
	return []


func _spawn_picked() -> void:
	var p := _player()
	if _spawns.selected < 0 or p == null:
		return
	if not get_node("/root/Net").is_host():
		_say("Spawns are the host's")
		return
	var fwd := -p.player_model.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var s: Array = _spawn_list[_spawns.selected]
	(s[1] as Callable).call(p.global_position + fwd * 12.0, atan2(-fwd.x, -fwd.z) + PI)
	_say("Spawned %s" % s[0])


## A theme's beast, woken, the way BeastArena and the tests make one.
func _spawn_beast(at: Vector3, yaw: float, theme: String, kind: String) -> void:
	var info: Dictionary = IslandThemes.of(theme).beasts[kind]
	var b: Node3D = load(str(info["script"])).new()
	b.name = "Debug_%s_%d" % [kind, Engine.get_physics_frames()]
	b.setup({"post": at, "yaw": yaw, "level": maxi(1, _player().progression.level), "name": (info["names"] as Array)[0]})
	(get_tree().current_scene if get_tree().current_scene else _player().get_parent()).add_child(b)
	b.global_position = at
	if b.has_method("alert"):
		b.alert()


func _warp_picked() -> void:
	if _warps.selected < 0 or _player() == null:
		return
	var wp: Array = _warp_list[_warps.selected]
	_player().debug_to_island(int(wp[1]))
	_say("Warping to %s" % wp[0])


func _flag(f: String) -> void:
	get_node("/root/Net").world_flag(f)
	_say("World flag: %s" % f)


## A debug key pressed for you (the weather's F6 and F7 stay the one way they work).
func _key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)
	_say("Pressed %s" % OS.get_keycode_string(k))
