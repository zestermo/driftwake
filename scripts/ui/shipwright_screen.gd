extends PanelContainer
## A shipwright's yard (GameMenu screen "yard", opened by talking to a shipwright: Tackett
## at Brinehollow, or the cities' own: set_yard names it). Refits: the ship's upgrade lines (ShipLines) as a tree,
## grouped, each line's levels as pips and the next level's price on its
## button (hover or focus it for what it does). Paint: her paint, sails, flag
## and figurehead (free: change them as often as you like). In co-op it's the
## host's ship, so only the host orders work.

var _menu: Node
var _gold: Label
var _note: Label
var _buy: Dictionary = {}
var _pips: Dictionary = {}
var _cycles: Array = []
var _flag: TextureRect
var _refits: VBoxContainer
var _paint: VBoxContainer
var _tabs: Dictionary = {}
var tab: String = "refits"
## Whose yard this is (its title and the lines the note says): Tackett's by default.
var who := "Tackett"
var _title: Label
## The lines this yard does (a harbour vendor's few: HarbourVendor), or [] for all of them.
var only: Array = []
var _rows: Dictionary = {}
var _heads: Dictionary = {}

## [kit key, row name, choices ([name, colour] or names)]
const LOOKS := [
	["hull", "Hull paint", ShipKit.HULL_PAINT], ["sail", "Sails", ShipKit.SAILS], ["field", "Flag", ShipKit.FIELDS],
	["emblem", "Emblem", ShipKit.EMBLEMS], ["mark", "Emblem colour", ShipKit.MARKS], ["figure", "Figurehead", ShipKit.FIGURES],
]
const SILK := preload("res://assets/fonts/Silkscreen-Regular.woff2")


func _init(menu: Node) -> void:
	_menu = menu
	# a column down the left: the ship turns slowly on the right (_preview)
	custom_minimum_size = Vector2(300, 0)
	set_anchors_preset(Control.PRESET_CENTER_LEFT)
	offset_left = 10
	offset_right = 310
	grow_vertical = Control.GROW_DIRECTION_BOTH
	add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG, UIStyle.BORDER, 8))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	add_child(vb)
	var top := HBoxContainer.new()
	_title = UIStyle.title("%s's Yard" % who)
	top.add_child(_title)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	for t in [["refits", "Refits"], ["paint", "Paint"]]:
		var b := _small_button(t[1], 44)
		var id: String = t[0]
		b.pressed.connect(func(): show_tab(id))
		_tabs[id] = b
		top.add_child(b)
	vb.add_child(top)
	_gold = UIStyle.label("", 8, UIStyle.ACCENT)
	_gold.add_theme_font_override("font", SILK)
	vb.add_child(_gold)
	_refits = VBoxContainer.new()
	_refits.add_theme_constant_override("separation", 0)
	vb.add_child(_refits)
	_build_tree()
	_paint = VBoxContainer.new()
	_paint.add_theme_constant_override("separation", 2)
	vb.add_child(_paint)
	_build_paint()
	# the foot: the note (what a line does, what Tackett says) beside Done
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	_note = UIStyle.label("", 8, UIStyle.TEXT_DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.custom_minimum_size = Vector2(190, 30)
	foot.add_child(_note)
	var done := UIStyle.button("Done", 64)
	done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func(): _menu.close())
	foot.add_child(done)
	vb.add_child(foot)
	show_tab("refits")


## A short plank button in Silkscreen 8 (a row of the tree is 16 px high).
func _small_button(text: String, w: float) -> Button:
	var b := UIStyle.button(text, w)
	b.add_theme_font_override("font", SILK)
	b.add_theme_font_size_override("font_size", 8)
	for st in [["normal", "plank"], ["hover", "plank_hover"], ["pressed", "plank_pressed"], ["disabled", "plank_dim"], ["focus", "plank_focus"]]:
		b.add_theme_stylebox_override(st[0], UIStyle.chrome(st[1], 4, 1))
	return b


## The lines, grouped: a header per group, a branch off its trunk to each line.
func _build_tree() -> void:
	for g in ShipLines.GROUPS:
		var ids: Array = ShipLines.ORDER.filter(func(id): return ShipLines.line(id)["group"] == g)
		var head := UIStyle.label(str(g).to_upper(), 8, UIStyle.ACCENT)
		head.add_theme_font_override("font", SILK)
		_heads[g] = head
		_refits.add_child(head)
		for i in range(ids.size()):
			var id: String = ids[i]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			row.custom_minimum_size = Vector2(0, 16)
			var branch := Control.new()
			branch.custom_minimum_size = Vector2(10, 16)
			var last := i == ids.size() - 1
			branch.draw.connect(func():
				branch.draw_line(Vector2(3, 0), Vector2(3, 8 if last else 16), UIStyle.BORDER_DIM, 1.0)
				branch.draw_line(Vector2(3, 8), Vector2(10, 8), UIStyle.BORDER_DIM, 1.0))
			row.add_child(branch)
			var nm := UIStyle.label(str(ShipLines.line(id)["name"]), 12)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nm)
			var pips := Control.new()
			pips.custom_minimum_size = Vector2(ShipLines.max_level(id) * 7, 16)
			pips.draw.connect(func(): _draw_pips(pips, id))
			row.add_child(pips)
			_pips[id] = pips
			var b := _small_button("", 58)
			b.pressed.connect(func(): buy(id))
			b.mouse_entered.connect(func(): _describe(id))
			b.focus_entered.connect(func(): _describe(id))
			row.add_child(b)
			_buy[id] = b
			_rows[id] = row
			_refits.add_child(row)


func _draw_pips(c: Control, id: String) -> void:
	var lv := ShipLines.level(_kit(), id)
	for k in range(ShipLines.max_level(id)):
		var r := Rect2(k * 7 + 1, 5, 5, 5)
		if k < lv:
			c.draw_rect(r, UIStyle.ACCENT)
		else:
			c.draw_rect(r, UIStyle.BG_DARK)
			c.draw_rect(r, UIStyle.BORDER_DIM, false, 1.0)


func _build_paint() -> void:
	var looks := HBoxContainer.new()
	var lt := UIStyle.label("Paint & colours", 14, UIStyle.ACCENT)
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	looks.add_child(lt)
	_flag = TextureRect.new()
	_flag.custom_minimum_size = Vector2(ShipKit.FLAG_W, ShipKit.FLAG_H) * 0.5
	_flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flag.stretch_mode = TextureRect.STRETCH_SCALE
	looks.add_child(_flag)
	_paint.add_child(looks)
	# two columns, each a name over its button
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 1)
	_paint.add_child(grid)
	for l in LOOKS:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(UIStyle.label(l[1], 8, UIStyle.TEXT_DIM))
		var b := UIStyle.stepper()
		b.tooltip_text = "Click the left or right half (or arrow keys) to change it. Free."
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = l[0]
		b.connect("stepped", func(d: int): cycle(key, d))
		cell.add_child(b)
		_cycles.append([key, b, l[2]])
		grid.add_child(cell)


func show_tab(id: String) -> void:
	tab = id
	_refits.visible = id == "refits"
	_paint.visible = id == "paint"
	for k in _tabs.keys():
		(_tabs[k] as Button).modulate = Color.WHITE if k == id else Color(1, 1, 1, 0.6)
	_note.text = _default_note()


func _default_note() -> String:
	if tab == "refits":
		return "Any of the crew can pay for her refits, and every one is for good." if Net.coop() else "Every refit is for good. Paint is free."
	return "Her colours are the host's to choose." if Net.is_client() else "Paint, sails and colours are free."


func on_open() -> void:
	_note.text = _default_note()
	_refresh()
	_start_preview()
	for c in find_children("*", "Button", true, false):
		if not (c as Button).disabled and (c as Button).is_visible_in_tree():
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
	_was_cam = get_tree().root.get_camera_3d()
	_cam = Camera3D.new()
	_cam.name = "YardCamera"
	_cam.fov = 55.0
	_cam.far = 1500.0
	_cam.h_offset = -10.5
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
	_cam.global_position = xf * Vector3(sin(_orbit) * 27.0, 9.5, cos(_orbit) * 27.0)
	_cam.look_at(xf * Vector3(0, 4.5, 0), Vector3.UP)


func _process(delta: float) -> void:
	if _cam and visible:
		_orbit += delta * 0.18
		_pose_preview(get_tree().get_first_node_in_group("ship") as Node3D)


## The ship's kit as it is (the host's in co-op: what's on her).
func _kit() -> Dictionary:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	return ShipKit.merged(ship.kit if ship else GameManager.ship_kit)


func _inv() -> InventoryComponent:
	return (_menu.call("_player") as Player).inventory_component


func _refresh() -> void:
	var kit := _kit()
	var guest := Net.is_client()
	var inv := _inv()
	var have: Array = ["%d gold" % inv.count("gold")]
	for k in Salvage.KINDS:
		have.append("%d %s" % [inv.count(k), k])
	_gold.text = "  ".join(have)
	for id in ShipLines.ORDER:
		var b: Button = _buy[id]
		var entry := ShipLines.next(kit, id)
		if entry.is_empty():
			b.text = "MAX"
			b.disabled = true
		else:
			b.text = "%dg%s" % [int(entry[2]), "+" if not (entry[3] as Dictionary).is_empty() else ""]
			b.disabled = false
			b.modulate = Color.WHITE if ShipLines.short_of(inv, entry) == "" else Color(1, 1, 1, 0.55)
		(_pips[id] as Control).queue_redraw()
	for c in _cycles:
		var names: Array = c[2]
		var v: Variant = names[int(kit[c[0]])]
		(c[1] as Button).text = UIStyle.stepper_text(v[0] if v is Array else v)
		(c[1] as Button).disabled = guest
	_flag.texture = ImageTexture.create_from_image(ShipKit.flag_image(kit))


## The note says what the line's next level is and costs.
func _describe(id: String) -> void:
	var kit := _kit()
	var entry := ShipLines.next(kit, id)
	var ln := ShipLines.line(id)
	if entry.is_empty():
		_note.text = "%s: all %d done. She can't take any more." % [ln["name"], ShipLines.max_level(id)]
		return
	_note.text = "%s %d, %s: %s. %s.\n%s." % [ln["name"], ShipLines.level(kit, id) + 1, entry[0], entry[1], ShipLines.effect_text(entry[4]), ShipLines.cost_text(entry)]


## Order a line's next level: the price comes out of your bag and the host puts it on her (any
## captain can pay: Net.request_upgrade). Single player and the host get the answer straight away.
func buy(id: String) -> void:
	var kit := _kit()
	if ShipLines.next(kit, id).is_empty():
		return
	order(id, ShipLines.level(kit, id))


## Pay for the level after `lv` (the level she has as you pay: the host checks nobody beat you to it).
func order(id: String, lv: int) -> void:
	var entry := ShipLines.entry(id, lv)
	var short := ShipLines.short_of(_inv(), entry)
	if short != "":
		_note.text = "\"%s, Captain, and not a copper less.\" (you need %s)" % [ShipLines.cost_text(entry), short]
		UIStyle.sfx("deny")
		return
	ShipLines.pay(_inv(), entry)
	_note.text = "%s gets to work..." % who
	Net.request_upgrade(id, lv)


## (Net) The host's answer: done, or a crewmate paid for that level first (the price comes back).
func upgrade_done(id: String, lv: int, ok: bool) -> void:
	var entry := ShipLines.entry(id, lv)
	if ok:
		_note.text = "%s: done. %s. She'll thank you for it." % [entry[0], ShipLines.effect_text(entry[4])]
		UIStyle.sfx("buy")
	else:
		_inv().add_item(ItemDB.get_item("gold"), int(entry[2]))
		var mats: Dictionary = entry[3]
		for m in mats.keys():
			_inv().add_item(ItemDB.get_item(m), int(mats[m]))
		_note.text = "\"A crewmate's already paid for that one.\" You get your %s back." % ShipLines.cost_text(entry)
		UIStyle.sfx("deny")
	SaveGame.save(_menu.call("_player"))
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


## Whose yard opens next (GameMenu, from the dialogue event "shipwright:<name>"; plain "shipwright" is Tackett's) and the
## lines it does ("shipwright:<name>|<line>,<line>": a harbour vendor's, no paint; [] every line), and whether it paints.
func set_yard(shipwright: String, lines: Array = [], paint: bool = true) -> void:
	who = shipwright
	only = lines
	for id in _rows:
		(_rows[id] as Control).visible = only.is_empty() or only.has(id)
	for g in _heads:
		(_heads[g] as Control).visible = only.is_empty() or ShipLines.ORDER.any(func(id): return only.has(id) and ShipLines.line(id)["group"] == g)
	if _tabs.has("paint"):
		(_tabs["paint"] as Control).visible = paint
		if not paint:
			show_tab("refits")
	if _title:
		_title.text = "%s's Yard" % who
