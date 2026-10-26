class_name Drills
extends CanvasLayer
## Vey's drills (1.23 tutorial; Story step "vey_drills"): a checklist on the left of the screen, each combat button
## with its key (read from the input map, so a rebind shows), ticked as the captain does it in the yard. All ticked:
## Vey's done with you (Story.complete), off to the smugglers' camp to try it for real. Only the local captain's.

## [id, what, input action] in order. `id` is how it's recognised (on_state / the draw toggle).
const ITEMS := [
	["light", "Cut: %s, twice in a row (a combo)", "light_attack"],
	["heavy", "Lunge: %s", "heavy_attack"],
	["dodge", "Roll out of the way: %s", "dodge"],
	["parry", "Parry a blow: tap %s", "parry"],
	["block", "Block: hold %s", "parry"],
	["air", "Strike from the air: %s, then a cut", "jump"],
	["draw", "Sheathe and draw your blade: %s", "ready_weapon"],
]
const LIGHTS := 2

var done := {}
var _rows := {}
var _armed_seen := -1
var _sheathed := false
var _last := ""
var _p: Player


static func start(tree: SceneTree) -> void:
	if not tree.get_nodes_in_group("drills").is_empty():
		return
	var d := Drills.new()
	d.add_to_group("drills")
	tree.root.add_child(d)


static func key_of(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return OS.get_keycode_string((e as InputEventKey).physical_keycode if (e as InputEventKey).keycode == 0 else (e as InputEventKey).keycode)
		if e is InputEventMouseButton:
			return {MOUSE_BUTTON_LEFT: "left click", MOUSE_BUTTON_RIGHT: "right click"}.get((e as InputEventMouseButton).button_index, "a mouse button")
	return action


func _ready() -> void:
	layer = 20
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIStyle.chrome("slate", 10, 7))
	pc.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	pc.offset_left = 10.0
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	pc.add_child(vb)
	vb.add_child(UIStyle.label("Vey's drills", 12, UIStyle.ACCENT))
	for it in ITEMS:
		var l := UIStyle.label("", 8, UIStyle.TEXT)
		vb.add_child(l)
		_rows[it[0]] = l
	_refresh()


func _refresh() -> void:
	for it in ITEMS:
		var l: Label = _rows[it[0]]
		var ok := done.has(it[0])
		l.text = ("[x] " if ok else "[ ] ") + (str(it[1]) % key_of(str(it[2])))
		l.add_theme_color_override("font_color", UIStyle.GOOD if ok else UIStyle.TEXT)


func tick(id: String) -> void:
	if done.has(id):
		return
	done[id] = true
	UIStyle.sfx("confirm")
	_refresh()
	if done.size() >= ITEMS.size():
		get_tree().call_group("hud", "show_banner", "Vey: \"Good. Now do it to someone who hits back.\"", "Drive the smugglers out of the south cove.", true)
		var s := get_node_or_null("/root/Story")
		if s:
			s.complete("vey_drills")
		queue_free()


func _physics_process(_d: float) -> void:
	if _p == null or not is_instance_valid(_p):
		_p = get_tree().get_first_node_in_group("player") as Player
		if _p == null:
			return
	var s := get_node_or_null("/root/Story")
	if s and str(s.step) != "vey_drills":
		queue_free()
		return
	var st := _p.current_state_name()
	if st != _last:
		match st:
			"LightAttack":
				if not _p.is_on_floor():
					tick("air")
			"HeavyAttack":
				tick("heavy")
			"Dodge":
				tick("dodge")
			"Parry":
				tick("parry")
			"Block":
				tick("block")
			"Plunge":
				tick("air")
		_last = st
	# the combo's third cut (the state stays LightAttack through a combo: its combo_index counts the cuts)
	if st == "LightAttack":
		var la := _p.state_machine.get_node_or_null("LightAttack")
		if la and int(la.get("combo_index")) >= LIGHTS - 1:
			tick("light")
	# sheathed, then drawn again
	var armed := 1 if _p.armed else 0
	if _armed_seen == 1 and armed == 0:
		_sheathed = true
	elif _armed_seen == 0 and armed == 1 and _sheathed:
		tick("draw")
	_armed_seen = armed
