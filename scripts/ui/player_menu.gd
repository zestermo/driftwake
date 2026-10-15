extends CanvasLayer
## The menu between captains: stand within REACH of another captain, facing them, and F opens Trade,
## Inspect and Duel (click, or 1-3). Esc, a click outside or walking off closes it. Every other captain
## gets an Interactable ("Meet") for the prompt; the local captain owns this (Player._ready).
## Trade is the crew's way of trading: drop things (the inventory opens) and they pick up the sack.

const REACH := 2.5
const KEEP := 3.5
const FACING := 0.5
const INSPECT := "res://scripts/ui/inspect_panel.gd"
const ENTRIES := ["trade", "inspect", "duel"]

var player: Node
var target: Node3D
var _canvas: PixelCanvas
var _root: Control
var _panel: PanelContainer
var _title: Label
var _buttons: Dictionary = {}
var _inspect: Control
var _scan_t := 0.0


func _ready() -> void:
	layer = 6
	Duel.ensure(get_tree()).kit_received.connect(_on_kit)
	_canvas = PixelCanvas.new()
	_canvas.visible = false
	add_child(_canvas)
	_root = Control.new()
	_root.name = "Catcher"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close())
	_canvas.ui.add_child(_root)
	_panel = PanelContainer.new()
	_panel.name = "Menu"
	_panel.add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG, UIStyle.BORDER, 8))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_panel.add_child(vb)
	_title = UIStyle.label("", 16, UIStyle.ACCENT)
	_title.add_theme_font_override("font", load("res://assets/fonts/PixelifySans-SemiBold.woff2"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)
	for i in range(ENTRIES.size()):
		var id: String = ENTRIES[i]
		var b := UIStyle.button(id.capitalize(), 120)
		b.pressed.connect(func(): choose(id))
		vb.add_child(b)
		_buttons[id] = b
	var hints := HBoxContainer.new()
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	hints.add_theme_constant_override("separation", 8)
	hints.add_child(UIStyle.key_hint("1-3", "PICK"))
	hints.add_child(UIStyle.key_hint("ESC", "CLOSE"))
	vb.add_child(hints)
	_root.add_child(_panel)


func is_open() -> bool:
	return target != null


func open_for(p: Node3D) -> void:
	if target == p:
		close()
		return
	target = p
	_title.text = str(p.display_name())
	_panel.visible = true
	if _inspect:
		_inspect.visible = false
	_refresh()
	_canvas.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_buttons["trade"] as Button).grab_focus.call_deferred()


func close() -> void:
	if target == null:
		return
	target = null
	_canvas.visible = false
	if not GameMenu.is_open():
		Settings.capture_mouse()


## "trade", "inspect" or "duel" for the captain we're facing.
func choose(id: String) -> void:
	if target == null or (_buttons[id] as Button).disabled:
		return
	var who := target
	var duel := Duel.ensure(get_tree())
	match id:
		"trade":
			close()
			var to: Vector3 = who.global_position - player.global_position
			player.player_model.rotation.y = atan2(-to.x, -to.z)
			GameMenu.open("inventory")
			get_tree().call_group("hud", "show_toast", "Drop what you're giving %s (drag it out of the bag, or X): they pick up the sack" % who.display_name())
		"inspect":
			if _inspect == null:
				_inspect = load(INSPECT).new()
				_inspect.viewer = player
				_root.add_child(_inspect)
			_inspect.clear(str(who.display_name()))
			_inspect.visible = true
			_panel.visible = false
			duel.ask_kit(duel.id_of(who))
		"duel":
			close()
			duel.challenge(duel.id_of(who))


func _on_kit(id: int, k: Dictionary) -> void:
	if target and _inspect and _inspect.visible and Duel.inst.id_of(target) == id:
		_inspect.show_kit(k)


func _refresh() -> void:
	var duel := Duel.ensure(get_tree())
	var b := _buttons["duel"] as Button
	var me := duel.id_of(player)
	var them := duel.id_of(target)
	if duel.asking(me) == them:
		b.text = "Challenge sent"
		b.disabled = true
	elif not duel.duel_of(me).is_empty() or not duel.duel_of(them).is_empty():
		b.text = "Duel (busy)"
		b.disabled = true
	else:
		b.text = "Duel"
		b.disabled = false


func _process(delta: float) -> void:
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.25
		_scan()
	if target == null:
		return
	if not is_instance_valid(target) or not target.is_inside_tree() or GameMenu.is_open() or not target.is_standing() \
			or Vector2(target.global_position.x - player.global_position.x, target.global_position.z - player.global_position.z).length() > KEEP:
		close()
		return
	_refresh()
	# right of the middle, clear of the captain you're facing and the skill bar
	var vs := _canvas.canvas
	for c in [_panel, _inspect]:
		if c and c.visible:
			c.reset_size()
			c.position = Vector2(roundf(vs.x * 0.5 + 36.0), roundf(minf((vs.y - c.size.y) * 0.45, vs.y - 78.0 - c.size.y))).max(Vector2(4, 4))


## Every other captain gets the prompt (their name), off while they're down or either of you is duelling.
func _scan() -> void:
	var duel := Duel.ensure(get_tree())
	var mine_busy := not duel.duel_of(duel.id_of(player)).is_empty()
	for p in get_tree().get_nodes_in_group("players"):
		if p == player:
			continue
		var it := p.get_node_or_null("Meet") as Interactable
		if it == null:
			it = _meet(p)
		it.prompt_text = str(p.display_name())
		it.enabled = p.is_standing() and not mine_busy and duel.duel_of(duel.id_of(p)).is_empty()


func _meet(p: Node3D) -> Interactable:
	var it := Interactable.new()
	it.name = "Meet"
	it.collision_layer = 512
	it.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.6
	cs.shape = sph
	cs.position = Vector3(0, 1.0, 0)
	it.add_child(cs)
	it.reach_test = func(feet: Vector3) -> bool: return in_reach(p, feet)
	it.interacted.connect(func(_by): open_for(p))
	p.add_child(it)
	return it


## Close enough and facing them.
func in_reach(p: Node3D, feet: Vector3) -> bool:
	var d := p.global_position - feet
	var flat := Vector3(d.x, 0.0, d.z)
	if flat.length() > REACH or absf(d.y) > 1.8:
		return false
	var fwd: Vector3 = -player.player_model.global_basis.z
	fwd.y = 0.0
	return flat.length() < 0.3 or fwd.normalized().dot(flat.normalized()) >= FACING


func _input(event: InputEvent) -> void:
	if target == null:
		return
	if event.is_action_pressed("pause"):
		if _inspect and _inspect.visible:
			_inspect.visible = false
			_panel.visible = true
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and _panel.visible:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_3:
			choose(ENTRIES[k - KEY_1])
			get_viewport().set_input_as_handled()
