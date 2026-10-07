extends PanelContainer
## Tackett's yard (GameMenu screen "yard", opened by talking to the shipwright
## at Brinehollow): refits bought with gold, and her paint, sails, flag and
## figurehead (free: change them as often as you like). In co-op it's the
## host's ship, so only the host orders work.

var _menu: Node
var _gold: Label
var _note: Label
var _buy: Dictionary = {}
var _cycles: Array = []
var _flag: TextureRect

## [kit key, row name, choices ([name, colour] or names)]
const LOOKS := [
	["hull", "Hull paint", ShipKit.HULL_PAINT], ["sail", "Sails", ShipKit.SAILS], ["field", "Flag", ShipKit.FIELDS],
	["emblem", "Emblem", ShipKit.EMBLEMS], ["mark", "Emblem colour", ShipKit.MARKS], ["figure", "Figurehead", ShipKit.FIGURES],
]


func _init(menu: Node) -> void:
	_menu = menu
	# a column down the left: the ship turns slowly on the right (_preview)
	custom_minimum_size = Vector2(272, 0)
	set_anchors_preset(Control.PRESET_CENTER_LEFT)
	offset_left = 10
	offset_right = 282
	grow_vertical = Control.GROW_DIRECTION_BOTH
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 8, 2))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	add_child(vb)
	var top := HBoxContainer.new()
	top.add_child(UIStyle.title("Tackett's Yard"))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	_gold = UIStyle.label("", 12, UIStyle.ACCENT)
	top.add_child(_gold)
	vb.add_child(top)
	vb.add_child(UIStyle.label("Refits", 14, UIStyle.ACCENT))
	for r in ShipKit.REFITS:
		var row := HBoxContainer.new()
		var txt := VBoxContainer.new()
		txt.add_theme_constant_override("separation", -2)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_child(UIStyle.label(r[1], 12))
		txt.add_child(UIStyle.label(r[2], 8, UIStyle.TEXT_DIM))
		row.add_child(txt)
		var b := UIStyle.button("", 56)
		var id: String = r[0]
		b.pressed.connect(func(): buy(id))
		row.add_child(b)
		_buy[id] = b
		vb.add_child(row)
	vb.add_child(HSeparator.new())
	var looks := HBoxContainer.new()
	var lt := UIStyle.label("Paint & colours", 14, UIStyle.ACCENT)
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	looks.add_child(lt)
	_flag = TextureRect.new()
	_flag.custom_minimum_size = Vector2(ShipKit.FLAG_W, ShipKit.FLAG_H)
	_flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flag.stretch_mode = TextureRect.STRETCH_SCALE
	looks.add_child(_flag)
	vb.add_child(looks)
	for l in LOOKS:
		var row := HBoxContainer.new()
		var name_l := UIStyle.label(l[1], 12)
		name_l.custom_minimum_size = Vector2(96, 0)
		row.add_child(name_l)
		var b := UIStyle.button("", 160)
		var key: String = l[0]
		b.pressed.connect(func(): cycle(key))
		b.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				cycle(key, -1))
		row.add_child(b)
		_cycles.append([key, b, l[2]])
		vb.add_child(row)
	# the foot
	_note = UIStyle.label("", 8, UIStyle.TEXT_DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.custom_minimum_size = Vector2(256, 0)
	vb.add_child(_note)
	var done := UIStyle.button("Done", 120)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func(): _menu.close())
	vb.add_child(done)


func on_open() -> void:
	_note.text = "This is the host's ship: only they can order work on her." if Net.is_client() \
		else "Refits are for good. Paint and colours are free (right-click goes back)."
	_refresh()
	_start_preview()
	for c in find_children("*", "Button", true, false):
		if not (c as Button).disabled:
			(c as Button).call_deferred("grab_focus")
			return


# --------------------------------------------------------------------------
# The ship on show: a camera circling her slowly, framed right of the panel
# --------------------------------------------------------------------------
var _cam: Camera3D
var _was_cam: Camera3D
var _orbit: float = 0.0


func _start_preview() -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	if ship == null or _cam:
		return
	_was_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.name = "YardCamera"
	_cam.fov = 55.0
	_cam.far = 1500.0
	_cam.h_offset = -9.5
	_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	get_tree().root.add_child(_cam)
	_cam.current = true
	_orbit = 0.6
	_pose_preview(ship)


## (GameMenu, leaving the yard) back to the camera we had.
func end_preview() -> void:
	if _cam == null:
		return
	if _was_cam and is_instance_valid(_was_cam):
		_was_cam.current = true
	_cam.queue_free()
	_cam = null


func _pose_preview(ship: Node3D) -> void:
	var xf := ship.global_transform
	_cam.global_position = xf * Vector3(sin(_orbit) * 26.0, 9.5, cos(_orbit) * 26.0)
	_cam.look_at(xf * Vector3(0, 4.5, 0), Vector3.UP)


func _process(delta: float) -> void:
	if _cam and visible:
		_orbit += delta * 0.18
		_pose_preview(get_tree().get_first_node_in_group("ship") as Node3D)


func _kit() -> Dictionary:
	return ShipKit.merged(GameManager.ship_kit)


func _gold_now() -> int:
	var p = _menu.call("_player")
	return p.inventory_component.count("gold") if p else 0


func _refresh() -> void:
	var kit := _kit()
	var guest := Net.is_client()
	_gold.text = "%d gold" % _gold_now()
	for r in ShipKit.REFITS:
		var b: Button = _buy[r[0]]
		b.text = "Fitted" if kit[r[0]] else "%d g" % int(r[3])
		b.disabled = guest or bool(kit[r[0]])
	for c in _cycles:
		var names: Array = c[2]
		var v: Variant = names[int(kit[c[0]])]
		(c[1] as Button).text = "< %s >" % (v[0] if v is Array else v)
		(c[1] as Button).disabled = guest
	_flag.texture = ImageTexture.create_from_image(ShipKit.flag_image(kit))


## Order a refit: the gold's gone, the work's done.
func buy(id: String) -> void:
	var kit := _kit()
	var r := ShipKit.refit(id)
	if Net.is_client() or kit[id]:
		return
	var cost := int(r[3])
	if _gold_now() < cost:
		_note.text = "\"%d gold, Captain, and not a copper less.\" (you have %d)" % [cost, _gold_now()]
		return
	var p = _menu.call("_player")
	p.inventory_component.remove_item(ItemDB.get_item("gold"), cost)
	kit[id] = true
	Net.set_ship_kit(kit)
	SaveGame.save(p)
	_note.text = "%s: done. She'll thank you for it." % r[1]
	_menu.call("_play")
	_refresh()


func cycle(key: String, step: int = 1) -> void:
	if Net.is_client():
		return
	var kit := _kit()
	for c in _cycles:
		if c[0] == key:
			kit[key] = posmod(int(kit[key]) + step, (c[2] as Array).size())
	Net.set_ship_kit(kit)
	_menu.call("_play")
	_refresh()
