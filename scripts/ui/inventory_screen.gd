class_name InventoryScreen
extends Control
## The inventory over the paused game (built by GameMenu): your captain on the left between
## the gear and weapon slots, the bag, quick slots and item details in a panel on the right,
## a chest or bag's contents in place of the paper doll. Weapons in hand and quick-slot items
## show only in their slots. Drawn into a SubViewport shown at a whole multiple of its pixels
## (_fit_canvas), so the pixel fonts and icons stay crisp at any window size.

const SLOT := 28
const GAP := 2
const COLS := 5
const PANEL_W := 304
const INFO_W := 130
const TIP_W := 150
const SMALL := preload("res://assets/fonts/Silkscreen-Regular.woff2")
const BOLD := preload("res://assets/fonts/PixelifySans-SemiBold.woff2")
const LIGHT := preload("res://scripts/player_states/light_attack_state.gd")
const HEAVY := preload("res://scripts/player_states/heavy_attack_state.gd")
const SHOOT := preload("res://scripts/player_states/shoot_state.gd")
const DOLL := [["head", "torso", "vest", "coat", "belt"], ["hands", "legs", "feet", "acc1", "acc2"]]
const TAGS := {"head": "HEAD", "torso": "BODY", "vest": "VEST", "coat": "COAT", "belt": "BELT", "hands": "HAND",
	"legs": "LEGS", "feet": "FEET", "acc1": "ACC", "acc2": "ACC", "weapon": "MAIN", "offhand": "OFF"}
const HEAVY_NAMES := {"thrust": "Lunging thrust", "whirl": "Whirlwind", "slam": "Leaping slam"}
## Item cards from these places compare with what you hold or wear.
const COMPARE := ["bag", "loot", "shop"]
const UP := Color(0.45, 0.95, 0.4)
const DOWN := Color(1.0, 0.4, 0.33)


class Slot extends Button:
	var item: ItemData
	var data: Dictionary
	var tex: TextureRect
	var count: Label
	var key: Label
	var tag: Label

	func _init(tag_text: String, d: Dictionary) -> void:
		data = d
		custom_minimum_size = Vector2(SLOT, SLOT)
		size = custom_minimum_size
		pivot_offset = custom_minimum_size * 0.5
		focus_mode = Control.FOCUS_ALL
		add_theme_stylebox_override("hover", InventoryScreen.slot_box(UIStyle.BG_LIGHT, UIStyle.ACCENT, true))
		add_theme_stylebox_override("pressed", InventoryScreen.slot_box(UIStyle.TEAL, UIStyle.CREAM, true))
		add_theme_stylebox_override("focus", InventoryScreen.slot_box(Color(0, 0, 0, 0), UIStyle.ACCENT, true))
		tag = InventoryScreen.small(tag_text, Color(UIStyle.BORDER_DIM, 0.8))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(tag)
		tex = TextureRect.new()
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tex.size = Vector2(24, 24)
		tex.pivot_offset = Vector2(12, 12)
		tex.position = Vector2(2, 2)
		add_child(tex)
		count = InventoryScreen.small("", UIStyle.TEXT)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 2)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.position = Vector2(0, SLOT - 10)
		count.size = Vector2(SLOT - 2, 8)
		add_child(count)
		key = InventoryScreen.small("", UIStyle.ACCENT)
		key.add_theme_color_override("font_outline_color", Color.BLACK)
		key.add_theme_constant_override("outline_size", 2)
		key.position = Vector2(2, 0)
		add_child(key)
		for c in [tag, count, key]:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouse_entered.connect(func(): tex.position.y = 1)
		mouse_exited.connect(func(): tex.position.y = 2)
		show_item(null, 0)

	func show_item(it: ItemData, qty: int, key_text: String = "", lit: bool = false) -> void:
		item = it
		tex.texture = it.icon if it else null
		tex.modulate = Color(1, 1, 1, 1.0 if qty > 0 else 0.35)
		count.text = str(qty) if it and (qty > 1 or (it.stackable and qty != 1)) else ""
		key.text = key_text
		tag.visible = it == null
		var bg := UIStyle.BG_DARK
		var border := UIStyle.BORDER_DIM
		if lit:
			bg = UIStyle.SUN.darkened(0.55)
			border = UIStyle.ACCENT
		elif it and it.rarity == ItemData.Rarity.SUPREME:
			# (black on black: a pale slot behind it)
			bg = Color(0.45, 0.45, 0.42, 0.9)
			border = Color(0.02, 0.02, 0.02)
		elif it and it.rarity > ItemData.Rarity.COMMON:
			var rc := it.rarity_color()
			bg = UIStyle.BG_DARK.lerp(rc.darkened(0.3), 0.3)
			border = rc.darkened(0.15)
		add_theme_stylebox_override("normal", InventoryScreen.slot_box(bg, border, false))

	func bounce() -> void:
		tex.scale = Vector2(1.4, 1.4)
		tex.rotation = 0.24
		var tw := create_tween().set_parallel()
		tw.tween_property(tex, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(tex, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			tex.self_modulate.a = 1.0


var menu: Node  # GameMenu (close / blip)
var _svc: PixelCanvas
var _ui: Control
var _canvas := Vector2(640, 360)
var _cx := 160.0
var _tab := "inventory"
var _tab_buttons: Dictionary = {}
var _pages: Dictionary = {}
var _grid: GridContainer
var _bag: Array[Slot] = []
var _quick: Array[Slot] = []
var _doll: Dictionary = {}  # slot id -> Slot
var _weapon_slot: Slot
var _offhand_slot: Slot
var _doll_nodes: Array[Control] = []
var _name_label: Label
var _stats_label: Label
var _gold_label: Label
var _panel: PanelContainer
var _details: VBoxContainer
var _tip: PanelContainer
var _tip_box: VBoxContainer
var _hints: HBoxContainer
var _sheet: VBoxContainer
var _drag_area: Control
var _loot_panel: PanelContainer
var _loot_title: Label
var _loot_grid: GridContainer
var _loot_slots: Array[Slot] = []
var _container: Node = null
var _view: Array[int] = []
var _selected := -1
var _sel: ItemData = null
var _hover: Slot = null
var _tip_t := 0.0
var _flash_t := 0.0
var _slide := 0.0
var _turning := false
## control -> [home position, parallax depth (px at the screen's edge), slides in on open]
var _par: Dictionary = {}
var _body_was_mode := Node.PROCESS_MODE_INHERIT
var _confirm: PanelContainer


func _init(owner_menu: Node) -> void:
	menu = owner_menu
	name = "Inventory"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_svc = PixelCanvas.new()
	add_child(_svc)
	_ui = _svc.ui
	_build()
	_svc.refit.connect(func():
		_canvas = _svc.canvas
		if visible:
			_layout())


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null


static func slot_box(bg: Color, border: Color, glow: bool) -> StyleBoxTexture:
	return UIStyle.frame(bg, border, 0, "well", glow)


static func small(text: String, color: Color = UIStyle.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", SMALL)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	return l


static func _text(text: String, color: Color = UIStyle.TEXT, font: Font = null) -> Label:
	var l := UIStyle.label(text, 12, color)
	l.add_theme_constant_override("line_spacing", -4)
	if font:
		l.add_theme_font_override("font", font)
	return l


static var _arrows: Dictionary = {}


static func _arrow(up: bool) -> Texture2D:
	if not _arrows.has(up):
		var img := Image.create(5, 3, false, Image.FORMAT_RGBA8)
		for lvl in range(3):
			for x in range(lvl, 5 - lvl):
				img.set_pixel(x, 2 - lvl if up else lvl, UP if up else DOWN)
		_arrows[up] = ImageTexture.create_from_image(img)
	return _arrows[up]


# ==========================================================================
# Build
# ==========================================================================
func _build() -> void:
	# drag on the captain to turn them; drop items here to put them on the ground
	_drag_area = Control.new()
	_drag_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_drag_area.gui_input.connect(_on_turn_input)
	_drag_area.set_drag_forwarding(Callable(), _can_drop_world, _drop_world)
	_ui.add_child(_drag_area)
	_build_doll()
	_build_panel()
	_build_loot()
	_hints = HBoxContainer.new()
	_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_hints.add_theme_constant_override("separation", 10)
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hints)
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip_box = VBoxContainer.new()
	_tip_box.add_theme_constant_override("separation", 2)
	_tip.add_child(_tip_box)
	_ui.add_child(_tip)


func _slot(tag: String, d: Dictionary) -> Slot:
	var s := Slot.new(tag, d)
	s.mouse_entered.connect(func(): _on_hover(s))
	s.focus_entered.connect(func(): _pick(s))
	s.pressed.connect(func(): _pick(s))
	s.mouse_exited.connect(func():
		if _hover == s:
			_hover = null
			_tip.visible = false
			_set_hints(_hints_for("", null)))
	s.set_drag_forwarding(func(_at: Vector2): return _drag_from(s),
		func(_at: Vector2, d2) -> bool: return _can_drop_on(_resolve(s.data), d2),
		func(_at: Vector2, d2) -> void:
			_drop_on(_resolve(s.data), d2)
			s.bounce())
	return s


func _build_doll() -> void:
	for col in DOLL:
		for slot in col:
			var id: String = slot
			var s := _slot(TAGS[id], {"src": "doll", "slot": id})
			s.pressed.connect(func(): _on_doll_pressed(id))
			_ui.add_child(s)
			_doll[id] = s
			_doll_nodes.append(s)
	_weapon_slot = _slot(TAGS["weapon"], {"src": "weapon"})
	_weapon_slot.pressed.connect(_put_away.bind(false))
	_offhand_slot = _slot(TAGS["offhand"], {"src": "offhand"})
	_offhand_slot.pressed.connect(_put_away.bind(true))
	for s in [_weapon_slot, _offhand_slot]:
		_ui.add_child(s)
		_doll_nodes.append(s)
	_name_label = _text("", UIStyle.ACCENT, BOLD)
	_name_label.add_theme_font_size_override("font_size", 16)
	_stats_label = small("", UIStyle.TEXT)
	for l in [_name_label, _stats_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
		l.add_theme_constant_override("outline_size", 4)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(l)
		_doll_nodes.append(l)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG, UIStyle.BORDER, 6))
	_ui.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	_panel.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	vb.add_child(head)
	for t in [["inventory", "INVENTORY"], ["character", "CHARACTER"]]:
		var id: String = t[0]
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", SMALL)
		b.add_theme_font_size_override("font_size", 8)
		var flat := StyleBoxEmpty.new()
		flat.content_margin_bottom = 2
		var line := StyleBoxFlat.new()
		line.bg_color = Color(0, 0, 0, 0)
		line.border_width_bottom = 1
		line.border_color = UIStyle.ACCENT
		line.content_margin_bottom = 2
		b.add_theme_stylebox_override("normal", flat)
		b.add_theme_stylebox_override("hover", flat)
		b.add_theme_stylebox_override("pressed", line)
		b.add_theme_stylebox_override("hover_pressed", line)
		b.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
		b.add_theme_color_override("font_hover_color", UIStyle.TEXT)
		b.add_theme_color_override("font_pressed_color", UIStyle.ACCENT)
		b.add_theme_color_override("font_hover_pressed_color", UIStyle.ACCENT)
		b.pressed.connect(func(): menu._play(); show_tab(id))
		head.add_child(b)
		_tab_buttons[id] = b
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	_gold_label = small("", UIStyle.ACCENT)
	_gold_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_gold_label)
	vb.add_child(_rule())

	var inv := HBoxContainer.new()
	inv.add_theme_constant_override("separation", 8)
	vb.add_child(inv)
	_pages["inventory"] = inv
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	inv.add_child(left)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	left.add_child(_grid)
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", GAP)
	left.add_child(qrow)
	var ql := small("QUICK", UIStyle.TEXT_DIM)
	ql.custom_minimum_size = Vector2(SLOT * 2 + GAP, 0)
	ql.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qrow.add_child(ql)
	for k in range(InventoryComponent.HOTBAR_SIZE):
		var qi := k
		var q := _slot("", {"src": "quick", "idx": qi})
		q.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				_clear_quick(qi))
		qrow.add_child(q)
		_quick.append(q)
	_details = VBoxContainer.new()
	_details.custom_minimum_size = Vector2(INFO_W, 0)
	_details.add_theme_constant_override("separation", 2)
	inv.add_child(_details)

	var ch := ScrollContainer.new()
	ch.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ch.custom_minimum_size = Vector2(0, SLOT * 5 + GAP * 3 + 6)
	vb.add_child(ch)
	_pages["character"] = ch
	_sheet = VBoxContainer.new()
	_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet.add_theme_constant_override("separation", 2)
	ch.add_child(_sheet)


## Bag cells for at least `n` stacks (more than the bag holds only when quick slots swap).
func _grow_bag(n: int) -> void:
	while _bag.size() < n:
		var cell := _bag.size()
		var b := _slot("", {"src": "bag", "cell": cell})
		b.pressed.connect(func(): _click_bag(cell))
		b.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT and cell < _view.size():
				_offhand_from_bag(_view[cell]))
		_grid.add_child(b)
		_bag.append(b)


static func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(UIStyle.BORDER_DIM, 0.7)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ==========================================================================
# Canvas and layout
# ==========================================================================
func _fit_canvas() -> void:
	_svc.fit()


func _layout() -> void:
	var w := _canvas.x
	var h := _canvas.y
	_panel.size = Vector2(PANEL_W, 0)
	var ph := _panel.get_combined_minimum_size().y
	var pp := Vector2(w - PANEL_W - 10, roundf((h - 18 - ph) * 0.5))
	_par.clear()
	_park(_panel, pp, -3.0, true)
	_cx = roundf((w - PANEL_W - 10) * 0.5)
	var dx := roundf(h * 0.235)
	var y0 := roundf(h * 0.17)
	var step := roundf(h * 0.122)
	for c in range(2):
		for r in range(5):
			var x := _cx - dx - SLOT if c == 0 else _cx + dx
			_park(_doll[DOLL[c][r]], Vector2(x, y0 + step * r), 2.0, false)
	var wy := y0 + step * 5
	_park(_weapon_slot, Vector2(_cx - SLOT - 2, wy), 2.0, false)
	_park(_offhand_slot, Vector2(_cx + 2, wy), 2.0, false)
	for l in [_name_label, _stats_label]:
		l.size = Vector2(260, 0)
	_park(_name_label, Vector2(_cx - 130, y0 - 42), 1.0, false)
	_park(_stats_label, Vector2(_cx - 130, y0 - 22), 1.0, false)
	_loot_panel.size = Vector2.ZERO
	var ls := _loot_panel.get_combined_minimum_size()
	_park(_loot_panel, Vector2(_cx - roundf(ls.x * 0.5), roundf((h - 18 - ls.y) * 0.5)), 2.0, false)
	_drag_area.position = Vector2.ZERO
	_drag_area.size = Vector2(w - PANEL_W - 14, h - 20)
	_hints.position = Vector2(0, h - 16)
	_hints.size = Vector2(w, 12)


func _park(c: Control, home: Vector2, depth: float, slides: bool) -> void:
	c.position = home
	_par[c] = [home, depth, slides]


## Where the captain stands, as a fraction of the screen's width: between the slot columns.
func doll_center_x() -> float:
	return _cx / _canvas.x


# ==========================================================================
# Open / close
# ==========================================================================
func on_open() -> void:
	var pl := _player()
	if pl == null:
		return
	_fit_canvas()
	pl.reset_squash()
	var body := pl.body_model
	if body:
		body.stop_action()
		body.ground_speed = 0.0
		body.move_speed = 0.0
		body.grounded = true
		_body_was_mode = body.process_mode
		body.process_mode = Node.PROCESS_MODE_ALWAYS  # keeps breathing / looking while paused
	var rig := _rig()
	if rig:
		rig.set_showcase(true, pl.player_model.global_rotation.y, doll_center_x())
	_hover = null
	_tip.visible = false
	var inv := pl.inventory_component
	_sel = pl.equipped_weapon
	if _sel == null and not inv.bag_view().is_empty():
		_sel = inv.items[inv.bag_view()[0]].item
	show_tab(_tab)
	refresh()
	_layout()
	_animate_open()


func _animate_open() -> void:
	_svc.modulate = Color(1, 1, 1, 0)
	_slide = 28.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_svc, "modulate:a", 1.0, 0.12)
	tw.tween_property(self, "_slide", 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var i := 0
	for n in _doll_nodes:
		if n is Slot:
			n.scale = Vector2(0.4, 0.4)
			tw.tween_property(n, "scale", Vector2.ONE, 0.16).set_delay(0.03 + i * 0.012) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			i += 1


## (GameMenu.close) a quick fade; `done` hides the menu once it's out.
func fade_out(done: Callable) -> void:
	_tip.visible = false
	var tw := create_tween().set_parallel()
	tw.tween_property(_svc, "modulate:a", 0.0, 0.09)
	tw.tween_property(self, "_slide", 18.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(done)


func focus_bag() -> void:
	if _tab == "inventory" and not _bag.is_empty():
		_bag[0].call_deferred("grab_focus")


func on_close() -> void:
	set_container(null)
	var pl := _player()
	if pl and pl.body_model:
		pl.body_model.process_mode = _body_was_mode
	var rig := _rig()
	if rig:
		rig.set_showcase(false)


func _rig() -> Node:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam and cam.get_parent() and cam.get_parent().get_parent() and cam.get_parent().get_parent().has_method("set_showcase"):
		return cam.get_parent().get_parent()
	return null


func _process(delta: float) -> void:
	if not visible:
		return
	# keep the captain's eyes on the viewer while the world is paused
	var pl := _player()
	var cam := get_viewport().get_camera_3d()
	if pl and pl.body_model and cam:
		pl.body_model.look_target = cam.global_position
		pl.body_model.look_weight = 0.55
	var m := _ui.get_local_mouse_position()
	var v := ((m - _canvas * 0.5) / (_canvas * 0.5)).clamp(-Vector2.ONE, Vector2.ONE)
	for c in _par.keys():
		var e: Array = _par[c]
		(c as Control).position = (e[0] as Vector2) + (v * float(e[1])).round() + (Vector2(roundf(_slide), 0) if e[2] else Vector2.ZERO)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_show_slot(_hover)
	if _hover and _hover.item and not _ui.get_viewport().gui_is_dragging():
		_tip_t += delta
		_tip.visible = _tip_t > 0.15
		if _tip.visible:
			_tip.size = Vector2.ZERO
			var sz := _tip.get_combined_minimum_size()
			# beside the cursor, never over the details panel: left of the panel when over it
			var edge := _panel.position.x - 6
			var p := m + Vector2(12, 10)
			if m.x > edge or p.x + sz.x > edge:
				p.x = minf(m.x, edge) - sz.x - 10
			p.y = clampf(p.y - 20, 4, _canvas.y - sz.y - 20)
			_tip.position = p.round()
	else:
		_tip.visible = false


func show_tab(id: String) -> void:
	_tab = id
	for k in _pages.keys():
		(_pages[k] as Control).visible = (k == id)
		(_tab_buttons[k] as Button).set_pressed_no_signal(k == id)
	if id == "character":
		_fill_sheet()
	if is_inside_tree():
		_layout()


func _on_turn_input(ev: InputEvent) -> void:
	var pl := _player()
	if pl == null:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_turning = ev.pressed
	elif ev is InputEventMouseMotion and _turning:
		pl.player_model.rotation.y += ev.relative.x * 0.016


# ==========================================================================
# Refresh
# ==========================================================================
func refresh() -> void:
	var pl := _player()
	if pl == null:
		return
	var inv := pl.inventory_component
	_view = inv.bag_view()
	var cells := maxi(inv.max_slots, ceili(_view.size() / float(COLS)) * COLS)
	_grow_bag(cells)
	for k in range(_bag.size()):
		if k < _view.size():
			var st := inv.items[_view[k]]
			_bag[k].show_item(st.item, st.quantity)
		else:
			_bag[k].show_item(null, 0)
		_bag[k].visible = k < cells
	for slot in _doll.keys():
		var it := pl.equipment.get_item(slot)
		_doll[slot].show_item(it, 1 if it else 0)
	_weapon_slot.show_item(pl.equipped_weapon, 1 if pl.equipped_weapon else 0, "", pl.armed and pl.equipped_weapon != null)
	_offhand_slot.show_item(pl.offhand_weapon, 1 if pl.offhand_weapon else 0, "", pl.armed and pl.offhand_weapon != null)
	for k in range(_quick.size()):
		var qid: String = inv.hotbar[k]
		var qit: ItemData = inv.get_hotbar_item(k) if qid != "" else null
		_quick[k].show_item(qit, inv.count(qid) if qit else 0, str(k + 5))
	_refresh_loot()
	_gold_label.text = "%d G" % inv.count("gold")
	_name_label.text = str(pl.body_model.look.get("name", "Captain")) if pl.body_model else "Captain"
	_stats_label.text = "LV %d    DEF %d    DMG x%.2f" % [pl.progression.level, int(pl.defense()), pl.damage_multiplier()]
	if _tab == "character":
		_fill_sheet()
	_show_slot(_hover)
	_show_details()


## A slot's data with a bag cell turned into its bag position.
func _resolve(data: Dictionary) -> Dictionary:
	if str(data["src"]) == "bag" and data.has("cell"):
		var k := int(data["cell"])
		return {"src": "bag", "idx": _view[k] if k < _view.size() else _player().inventory_component.items.size()}
	return data


## The mouse over a slot: its tooltip (after a moment) and its hints.
func _on_hover(s: Slot) -> void:
	_hover = s
	_tip_t = 0.0
	_tip.visible = false
	_show_slot(s)


## Focus or a click: the slot's item becomes the one in the details panel.
func _pick(s: Slot) -> void:
	var it := _item_of(_resolve(s.data))
	if it:
		_sel = it
	_show_slot(s)
	_show_details()


## The tooltip, the hint bar and the bag position X / 5-7 act on, for a slot (null: none).
func _show_slot(s: Slot) -> void:
	var it: ItemData = null
	var d := {}
	if s:
		d = _resolve(s.data)
		it = _item_of(d)
	_selected = int(d["idx"]) if it and str(d["src"]) == "bag" else -1
	if it == null:
		_tip.visible = false
		if _flash_t <= 0.0:
			_set_hints(_hints_for("", null))
		return
	var src := str(d["src"])
	fill_info(_tip_box, it, _qty_of(d), src, TIP_W, _player())
	var border := it.rarity_color() if it.rarity != ItemData.Rarity.SUPREME else Color(0.85, 0.85, 0.8)
	_tip.add_theme_stylebox_override("panel", UIStyle.frame(UIStyle.BG_DARK, border, 5, "plank"))
	if _flash_t <= 0.0:
		_set_hints(_hints_for(src, it))


func _show_details() -> void:
	var d := _locate(_sel) if _sel else {}
	if d.is_empty():
		_sel = null
		_clear(_details)
		return
	fill_info(_details, _sel, _qty_of(d), str(d["src"]), INFO_W, _player())


## Where an item is now (it moves when equipped, taken off or taken): {} when it's gone.
func _locate(it: ItemData) -> Dictionary:
	var pl := _player()
	var inv := pl.inventory_component
	if it == pl.equipped_weapon:
		return {"src": "weapon"}
	if it == pl.offhand_weapon:
		return {"src": "offhand"}
	for slot in _doll.keys():
		if pl.equipment.get_item(slot) == it:
			return {"src": "doll", "slot": slot}
	var q := inv.hotbar.find(it.id)
	if q >= 0 and inv.count(it.id) > 0:
		return {"src": "quick", "idx": q}
	for i in _view:
		if inv.items[i].item == it:
			return {"src": "bag", "idx": i}
	if has_container():
		for j in range(_container.contents.size()):
			if _container.contents[j].item == it:
				return {"src": "loot", "idx": j}
	return {}


func _qty_of(d: Dictionary) -> int:
	var inv := _player().inventory_component
	match str(d["src"]):
		"bag":
			return inv.items[int(d["idx"])].quantity
		"quick":
			return inv.count(inv.hotbar[int(d["idx"])])
		"loot":
			return _container.contents[int(d["idx"])].quantity
	return 1


static func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


# ==========================================================================
# Item info (the details panel and the tooltip)
# ==========================================================================
## An item's card (the details panel, the tooltip; ShopScreen's too): src "bag", "loot" and "shop"
## compare with what `pl` holds or wears.
static func fill_info(box: VBoxContainer, it: ItemData, qty: int, src: String, w: float, pl: Player) -> void:
	_clear(box)
	var title := _text(it.display_name + ("  x%d" % qty if qty > 1 else ""), it.rarity_color(), BOLD)
	title.add_theme_color_override("font_outline_color", it.rarity_outline())
	title.add_theme_constant_override("outline_size", 2)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(w, 0)
	box.add_child(title)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 6)
	sub.add_child(small(("%s %s" % [it.rarity_name(), _kind(it)]).to_upper(), UIStyle.TEXT_DIM))
	var where: String = {"weapon": "IN HAND", "offhand": "OFF HAND", "doll": "WORN", "quick": "QUICK SLOT"}.get(src, "")
	if where != "":
		sub.add_child(small(where, UIStyle.ACCENT))
	box.add_child(sub)
	box.add_child(_rule())
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 1)
	box.add_child(grid)
	var fx: Array = []
	if it.is_weapon():
		var ws := weapon_stats(it)
		var cur := pl.equipped_weapon if src in COMPARE and pl.equipped_weapon and pl.equipped_weapon.id != it.id else null
		var cs := weapon_stats(cur) if cur else {}
		_stat(grid, "DAMAGE", str(int(round(ws["damage"]))), int(round(ws["damage"])) - int(round(cs["damage"])) if cur else 0, true)
		_stat(grid, "SPEED", str(ws["speed"]), signf(snappedf(ws["rate"] - cs["rate"], 0.01)) if cur else 0, false)
		if ws["gun"]:
			_stat(grid, "RANGE", "%d M" % int(SHOOT.RANGE), 0, false)
		else:
			fx.append(["Heavy: " + HEAVY_NAMES[HEAVY.style_for(it.weapon_model)], UIStyle.TEXT])
		if it.poison > 0.0:
			fx.append(["Venom: %d a second for 4 s" % int(it.poison), Color(0.55, 0.95, 0.35)])
		match it.weapon_model:
			"dagger":
				fx.append(["Finisher makes them bleed", DOWN])
			"axe":
				fx.append(["Finisher knocks them down", Color(1.0, 0.75, 0.45)])
			"katana":
				fx.append(["Two-handed", UIStyle.TEXT_DIM])
	elif it.is_gear():
		var cur := pl.equipment.get_item(pl.equipment.slot_for(it)) if src in COMPARE else null
		var arm := int(round(it.armor()))
		_stat(grid, "DEFENSE", str(arm), arm - (int(round(cur.armor())) if cur else 0) if src in COMPARE else 0, true)
	elif it.is_consumable():
		if it.heal_amount > 0.0:
			_stat(grid, "HEALS", str(int(it.heal_amount)), 0, false)
			_stat(grid, "TAKES", "%.2f S" % it.use_time, 0, false)
		if it.devil_fruit != "":
			fx.append(["Eating it is forever", Color(1.0, 0.6, 0.3)])
			fx.append(["Deep water takes you", DOWN])
	if it.id != "gold":
		_stat(grid, "WORTH", "%d G" % it.worth(), 0, false)
	for f in fx:
		var l := small(str(f[0]).to_upper(), f[1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(w, 0)
		box.add_child(l)
	if it.description != "":
		var d := _text(it.description, UIStyle.TEXT_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(w, 0)
		d.max_lines_visible = 3
		d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(d)


## A stat row: name, value and (diff != 0) an arrow against what you have on.
static func _stat(grid: GridContainer, label: String, value: String, diff: float, show_num: bool) -> void:
	var n := small(label, UIStyle.TEXT_DIM)
	n.custom_minimum_size = Vector2(46, 0)
	grid.add_child(n)
	grid.add_child(small(value, UIStyle.TEXT))
	var cmp := HBoxContainer.new()
	cmp.add_theme_constant_override("separation", 2)
	grid.add_child(cmp)
	if diff == 0.0:
		return
	var a := TextureRect.new()
	a.texture = _arrow(diff > 0.0)
	a.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	a.custom_minimum_size = Vector2(5, 8)
	cmp.add_child(a)
	if show_num:
		cmp.add_child(small("%+d" % int(diff), UP if diff > 0.0 else DOWN))


static func _kind(it: ItemData) -> String:
	match it.item_type:
		ItemData.ItemType.WEAPON:
			return it.weapon_model
		ItemData.ItemType.GEAR:
			return Gear.slot_label(it.gear_slot) + " gear"
		ItemData.ItemType.CONSUMABLE:
			return "devil fruit" if it.devil_fruit != "" else "consumable"
	return "treasure"


## What a weapon does on its own: damage (an average light hit, or a shot), hits a second, a word for it.
static func weapon_stats(it: ItemData) -> Dictionary:
	if it.weapon_model in ["pistol", "rifle"]:
		var rate := 1.0 / 0.34
		return {"gun": true, "damage": SHOOT.SINGLE_DAMAGE * it.power(), "rate": rate, "speed": _speed_word(rate)}
	var st: Dictionary = LIGHT.STYLES[{"katana": "katana", "axe": "axe", "dagger": "dagger"}.get(it.weapon_model, "sword")]
	var dmg := 0.0
	for x in st["damages"]:
		dmg += float(x)
	var dur := 0.0
	for x in st["durations"]:
		dur += float(x)
	var n := float((st["damages"] as Array).size())
	return {"gun": false, "damage": dmg / n * it.power(), "rate": n / dur, "speed": _speed_word(n / dur)}


static func _speed_word(rate: float) -> String:
	if rate >= 2.9:
		return "FAST"
	if rate >= 2.5:
		return "QUICK"
	if rate >= 1.7:
		return "STEADY"
	return "SLOW"


# ==========================================================================
# The hint bar
# ==========================================================================
func _hints_for(src: String, it: ItemData) -> Array:
	var out: Array = []
	match src:
		"bag":
			if it.is_weapon():
				out = [["LMB", "EQUIP"], ["RMB", "OFF HAND"]]
			elif it.is_gear():
				out = [["LMB", "WEAR"]]
			elif it.is_consumable():
				out = [["LMB", "EAT" if it.devil_fruit != "" else "USE"]]
				if InventoryComponent.quick_ok(it):
					out.append(["5-7", "QUICK SLOT"])
			out.append(["X", "DROP"])
		"doll":
			out = [["LMB", "TAKE OFF"]]
		"weapon", "offhand":
			out = [["LMB", "PUT AWAY"]]
		"quick":
			out = [["RMB", "CLEAR"]]
		"loot":
			out = [["LMB", "TAKE"], ["SHIFT", "TAKE ONE"]]
		_:
			out = [["DRAG", "MOVE / EQUIP"]]
	if has_container():
		out.append(["F", "TAKE ALL"])
	out.append(["TAB", "CLOSE"])
	return out


func _set_hints(pairs: Array) -> void:
	_clear(_hints)
	for p in pairs:
		_hints.add_child(UIStyle.key_hint(str(p[0]), str(p[1])))


## A short note in place of the hints for a moment (why that didn't work).
func _flash(text: String) -> void:
	_clear(_hints)
	var l := small(text.to_upper(), UIStyle.DANGER_TEXT)
	l.add_theme_color_override("font_outline_color", UIStyle.OUTLINE)
	l.add_theme_constant_override("outline_size", 2)
	_hints.add_child(l)
	_flash_t = 2.5


# ==========================================================================
# Actions
# ==========================================================================
func _click_bag(cell: int) -> void:
	if cell >= _view.size():
		return
	var pl := _player()
	var it := pl.inventory_component.items[_view[cell]].item
	var to: Slot = _weapon_slot if it.is_weapon() else (_doll.get(pl.equipment.slot_for(it)) as Slot if it.is_gear() else null)
	_use(_view[cell])
	if to:
		to.bounce()


func _use(idx: int) -> void:
	var pl := _player()
	if pl == null or idx >= pl.inventory_component.items.size():
		return
	var it := pl.inventory_component.items[idx].item
	if it.is_weapon():
		pl.equip_weapon(it, false)
		menu._play()
		refresh()
	elif it.is_gear():
		if pl.equip_gear_from_bag(idx):
			menu._play()
		refresh()
	elif it.is_consumable() and it.devil_fruit != "":
		_confirm_fruit(it)
	elif it.is_consumable():
		menu.close()
		pl.use_item(it)


## Click a hand slot: back into the bag (the main hand: fight with your fists).
func _put_away(off: bool) -> void:
	var pl := _player()
	var it := pl.offhand_weapon if off else pl.equipped_weapon
	if it == null:
		return
	if not pl.inventory_component.has_room():
		_flash("No room in your bag")
		return
	if off:
		pl.set_offhand(null)
	else:
		pl.unequip_weapon()
	menu._play()
	refresh()
	_bounce_item(it)


func _clear_quick(k: int) -> void:
	var inv := _player().inventory_component
	var it: ItemData = inv.get_hotbar_item(k) if inv.hotbar[k] != "" else null
	inv.clear_hotbar_slot(k)
	menu._play()
	refresh()
	if it:
		_bounce_item(it)


func _bounce_item(it: ItemData) -> void:
	for b in _bag:
		if b.item == it:
			b.bounce()
			return


## Right-click a weapon in the bag: hold it in the off hand (dual wielding).
func _offhand_from_bag(idx: int) -> void:
	var pl := _player()
	if pl == null or idx >= pl.inventory_component.items.size():
		return
	var it := pl.inventory_component.items[idx].item
	if not it.is_weapon():
		return
	if not pl.set_offhand(it):
		_flash("Off hand: a second blade, a second pistol, or a pistol beside a cutlass")
		return
	menu._play()
	refresh()
	_offhand_slot.bounce()


## Eating a Devil Fruit can't be undone: ask first.
func _confirm_fruit(it: ItemData) -> void:
	if _confirm:
		_confirm.queue_free()
	var pl := _player()
	_confirm = PanelContainer.new()
	_confirm.add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG_DARK, UIStyle.CORAL, 8))
	_confirm.set_anchors_preset(Control.PRESET_CENTER)
	_confirm.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_confirm.add_child(v)
	var t := _text("Eat the %s?" % it.display_name, UIStyle.DANGER_TEXT, BOLD)
	t.add_theme_font_size_override("font_size", 16)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var body := "Its power is yours. But a Devil Fruit's curse is forever: you will never swim again, and deep water will drag you under."
	if pl and pl.power.has_fruit():
		body = "You already carry a Devil Fruit's power. A second would kill you."
	var d := _text(body, UIStyle.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(220, 0)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var no := UIStyle.button("Not yet", 80)
	no.pressed.connect(func():
		_confirm.queue_free()
		_confirm = null)
	if not (pl and pl.power.has_fruit()):
		var yes := UIStyle.danger(UIStyle.button("Eat it", 80))
		yes.pressed.connect(func():
			_confirm.queue_free()
			_confirm = null
			menu.close()
			var p2 := _player()
			if p2:
				p2.use_item(it))
		row.add_child(yes)
		yes.call_deferred("grab_focus")
	row.add_child(no)
	_ui.add_child(_confirm)
	menu._play()


func _on_doll_pressed(slot: String) -> void:
	var pl := _player()
	var it := pl.equipment.get_item(slot)
	if pl.unequip_gear(slot):
		menu._play()
	refresh()
	if it and pl.equipment.get_item(slot) == null:
		_bounce_item(it)


func assign_hotbar(slot: int) -> void:
	var pl := _player()
	if pl == null or _selected < 0 or _selected >= pl.inventory_component.items.size():
		return
	var it := pl.inventory_component.items[_selected].item
	if not InventoryComponent.quick_ok(it):
		return
	pl.inventory_component.assign_hotbar(slot, it.id)
	_selected = -1
	menu._play()
	refresh()
	_quick[slot].bounce()


# ==========================================================================
# Character sheet
# ==========================================================================
func _fill_sheet() -> void:
	_clear(_sheet)
	var pl := _player()
	if pl == null:
		return
	_section("Attributes")
	_row("Strength", str(pl.attribute("strength")), "Weapon damage")
	_row("Agility", str(pl.attribute("agility")), "Footwork")
	_row("Endurance", str(pl.attribute("endurance")), "Health and stamina")

	_section("Combat")
	var hc := pl.health_component
	_row("Health", "%d / %d" % [int(hc.current_health), int(hc.max_health)])
	_row("Stamina", "%d" % int(pl.max_stamina))
	var w := pl.equipped_weapon
	_row("Weapon", w.display_name if w else "Fists")
	_row("Damage", "x%.2f" % pl.damage_multiplier())
	_row("Defense", "%d" % int(pl.defense()), "Blocks %d%%" % int(round(pl.damage_reduction() * 100.0)))
	_row("Speed", "%.1f m/s" % pl.move_speed, "Sprint %.1f" % pl.sprint_speed)

	_section("Progress")
	var pr := pl.progression
	_row("Level", str(pr.level), "%d / %d XP" % [pr.xp, Progression.xp_to_next(pr.level)])
	_row("Skill points", str(pr.skill_points), "Skill map: K")
	_row("Air jumps", str(pl.max_jumps - 1))
	_row("Style", pl.style().replace("_", " ").capitalize())
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		_row("Ship's chest", "%d gold" % gm.stored_count("gold"), "%d treasure" % gm.stored_count("treasure"))

	_section("Devil Fruit")
	if pl.power.has_fruit():
		var fd := pl.power.fruit_data()
		_sheet.add_child(_text("%s (%s)" % [fd["name"], DevilFruits.type_name(pl.power.fruit)], fd["color"]))
		_note(str(fd["passive"][0]), str(fd["passive"][1]))
		_note(str(DevilFruits.CURSE[0]), str(DevilFruits.CURSE[1]))
	else:
		_sheet.add_child(small("NONE", UIStyle.TEXT_DIM))

	_section("Skill bar")
	for i in range(5):
		var sk := pl.power.skill(i)
		var key := "R" if i == 4 else str(i + 1)
		if sk.is_empty():
			_row(key, "-")
		else:
			var cost := "Ultimate" if i == 4 else "%d energy" % int(sk["cost"])
			_row(key, str(sk["name"]), "%s, %ss" % [cost, str(snappedf(float(sk["cooldown"]), 0.1))])


func _note(title: String, body: String) -> void:
	_sheet.add_child(small(title.to_upper(), UIStyle.ACCENT))
	var d := _text(body, UIStyle.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(270, 0)
	_sheet.add_child(d)


func _section(text: String) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 2)
	_sheet.add_child(sp)
	_sheet.add_child(small(text.to_upper(), UIStyle.BORDER))
	_sheet.add_child(_rule())


func _row(label_text: String, value: String, note: String = "") -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var l := small(label_text.to_upper(), UIStyle.TEXT_DIM)
	l.custom_minimum_size = Vector2(78, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(l)
	var v := _text(value, UIStyle.TEXT)
	v.custom_minimum_size = Vector2(92, 0)
	v.clip_text = true
	hb.add_child(v)
	if note != "":
		var n := small(note.to_upper(), UIStyle.TEXT_DIM)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		n.clip_text = true
		hb.add_child(n)
	_sheet.add_child(hb)


# ==========================================================================
# Drag and drop
# ==========================================================================
func _item_of(data: Dictionary) -> ItemData:
	var pl := _player()
	if pl == null:
		return null
	var inv := pl.inventory_component
	match str(data.get("src", "")):
		"bag":
			var i := int(data["idx"])
			return inv.items[i].item if i < inv.items.size() else null
		"doll":
			return pl.equipment.get_item(str(data["slot"]))
		"weapon":
			return pl.equipped_weapon
		"offhand":
			return pl.offhand_weapon
		"quick":
			var q := int(data["idx"])
			return inv.get_hotbar_item(q) if inv.hotbar[q] != "" else null
		"loot":
			var j := int(data["idx"])
			if has_container() and j < _container.contents.size():
				return _container.contents[j].item
	return null


func _drag_from(s: Slot):
	var d := _resolve(s.data)
	var it := _item_of(d)
	if it == null:
		return null
	_tip.visible = false
	var prev := TextureRect.new()
	prev.texture = it.icon
	prev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prev.size = Vector2(24, 24)
	prev.position = Vector2(-12, -12)
	prev.pivot_offset = Vector2(12, 12)
	var holder := Control.new()
	holder.add_child(prev)
	s.set_drag_preview(holder)
	prev.scale = Vector2(1.45, 1.45)
	prev.rotation = -0.3
	var tw := _ui.create_tween().set_parallel()
	tw.tween_property(prev, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(prev, "rotation", 0.0, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	s.tex.self_modulate.a = 0.3
	d = d.duplicate()
	d["item"] = it
	return d


func _can_drop_on(target: Dictionary, d) -> bool:
	if not (d is Dictionary) or not (d as Dictionary).has("src"):
		return false
	var pl := _player()
	if pl == null:
		return false
	var it: ItemData = d.get("item")
	var src := str(d["src"])
	match str(target.get("src", "")):
		"bag":
			return src in ["bag", "doll", "weapon", "offhand", "quick", "loot"]
		"doll":
			return src == "bag" and it != null and it.is_gear() and pl.equipment.slot_for(it) == str(target["slot"])
		"weapon", "offhand":
			return src == "bag" and it != null and it.is_weapon()
		"quick":
			return (src == "bag" or src == "quick") and InventoryComponent.quick_ok(it)
		"loot":
			return src == "bag" and has_container()
	return false


func _drop_on(target: Dictionary, d) -> void:
	var pl := _player()
	if pl == null or not _can_drop_on(target, d):
		return
	var inv := pl.inventory_component
	var src := str(d["src"])
	var it: ItemData = d["item"]
	match str(target["src"]):
		"bag":
			var to := int(target["idx"])
			match src:
				"bag":
					inv.move_stack(int(d["idx"]), to)
				"doll":
					pl.unequip_gear(str(d["slot"]))
				"weapon", "offhand":
					if not inv.has_room():
						_flash("No room in your bag")
						return
					if src == "weapon":
						pl.unequip_weapon()
					else:
						pl.set_offhand(null)
				"quick":
					inv.clear_hotbar_slot(int(d["idx"]))
				"loot":
					if has_container():
						_container.take(int(d["idx"]), pl)
		"doll":
			var bi := inv.items.find(_stack_of(inv, int(d["idx"]), it))
			if bi >= 0:
				pl.equip_gear_from_bag(bi)
		"weapon":
			pl.equip_weapon(it, false)
		"offhand":
			if not pl.set_offhand(it):
				_flash("Off hand: a second blade, a second pistol, or a pistol beside a cutlass")
		"quick":
			var tq := int(target["idx"])
			if src == "quick":
				var other: String = inv.hotbar[tq]
				inv.assign_hotbar(tq, it.id)
				if other != "" and other != it.id:
					inv.assign_hotbar(int(d["idx"]), other)
			else:
				inv.assign_hotbar(tq, it.id)
		"loot":
			if has_container():
				_container.store(pl, int(d["idx"]))
	menu._play()
	refresh()


func _stack_of(inv: InventoryComponent, idx: int, it: ItemData) -> ItemStack:
	if idx < inv.items.size() and inv.items[idx].item == it:
		return inv.items[idx]
	for st in inv.items:
		if st.item == it:
			return st
	return null


## Dragging a bag item or a weapon in hand out onto the world: drop it.
func _can_drop_world(_at: Vector2, d) -> bool:
	return d is Dictionary and str((d as Dictionary).get("src", "")) in ["bag", "weapon", "offhand"]


func _drop_world(_at: Vector2, d) -> void:
	var pl := _player()
	if pl == null or not _can_drop_world(_at, d):
		return
	var idx := -1
	match str(d["src"]):
		"bag":
			idx = int(d["idx"])
		"weapon":
			idx = pl.inventory_component.find_index(pl.equipped_weapon.id)
		"offhand":
			for i in range(pl.inventory_component.items.size()):
				if pl.inventory_component.items[i].item.id == pl.offhand_weapon.id:
					idx = i
	pl.drop_from_bag(idx)
	menu._play()
	refresh()


## X over a bag slot: drop that stack (one, with shift).
func drop_selected(one: bool) -> void:
	var pl := _player()
	if pl == null or _selected < 0 or _selected >= pl.inventory_component.items.size():
		return
	pl.drop_from_bag(_selected, 1 if one else -1)
	_selected = -1
	menu._play()
	refresh()


## Select a bag position (as focusing it would).
func _select(idx: int) -> void:
	var k := _view.find(idx)
	if k >= 0:
		_pick(_bag[k])


# ==========================================================================
# Loot window (a chest or bag in place of the paper doll)
# ==========================================================================
func _build_loot() -> void:
	_loot_panel = PanelContainer.new()
	_loot_panel.add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG, UIStyle.ACCENT, 6))
	_loot_panel.visible = false
	_ui.add_child(_loot_panel)
	_loot_panel.set_drag_forwarding(Callable(), func(_at: Vector2, d) -> bool: return _can_drop_on({"src": "loot"}, d),
		func(_at: Vector2, d) -> void: _drop_on({"src": "loot"}, d))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	_loot_panel.add_child(vb)
	_loot_title = _text("Chest", UIStyle.ACCENT, BOLD)
	vb.add_child(_loot_title)
	vb.add_child(_rule())
	_loot_grid = GridContainer.new()
	_loot_grid.columns = COLS
	_loot_grid.add_theme_constant_override("h_separation", GAP)
	_loot_grid.add_theme_constant_override("v_separation", GAP)
	vb.add_child(_loot_grid)
	_grow_loot(20)
	var take := UIStyle.button("Take all", 80)
	take.size_flags_horizontal = Control.SIZE_SHRINK_END
	take.pressed.connect(func(): take_all())
	vb.add_child(take)


func _grow_loot(n: int) -> void:
	while _loot_slots.size() < n:
		var idx := _loot_slots.size()
		var b := _slot("", {"src": "loot", "idx": idx})
		b.pressed.connect(func():
			var pl := _player()
			if pl and has_container() and idx < _container.contents.size():
				var it: ItemData = _container.contents[idx].item
				_container.take(idx, pl, 1 if Input.is_key_pressed(KEY_SHIFT) else -1)
				menu._play()
				if has_container():
					refresh()
					_bounce_item(it))
		_loot_grid.add_child(b)
		_loot_slots.append(b)


func has_container() -> bool:
	return _container != null and is_instance_valid(_container) and not _container.is_queued_for_deletion()


## Show a chest / bag's contents (null: back to the paper doll).
func set_container(c: Node) -> void:
	if _container != null and is_instance_valid(_container):
		if _container.contents_changed.is_connected(_on_container_changed):
			_container.contents_changed.disconnect(_on_container_changed)
		if _container.tree_exiting.is_connected(_on_container_gone):
			_container.tree_exiting.disconnect(_on_container_gone)
	_container = c
	if c:
		c.contents_changed.connect(_on_container_changed)
		c.tree_exiting.connect(_on_container_gone)
		show_tab("inventory")
	_loot_panel.visible = c != null
	for n in _doll_nodes:
		n.visible = c == null
	refresh()
	if is_inside_tree():
		_layout()


func _on_container_changed() -> void:
	if visible:
		refresh()


## Emptied (or picked up by a crewmate): back to the game.
func _on_container_gone() -> void:
	_container = null
	if visible:
		menu.close.call_deferred()


func take_all() -> void:
	var pl := _player()
	if pl and has_container():
		_container.take_all(pl)
		menu._play()
		if has_container():
			refresh()


func _refresh_loot() -> void:
	if not has_container():
		return
	_loot_title.text = str(_container.title())
	var cont: Array = _container.contents
	_grow_loot(cont.size())
	for i in range(_loot_slots.size()):
		if i < cont.size():
			_loot_slots[i].show_item(cont[i].item, cont[i].quantity)
		else:
			_loot_slots[i].show_item(null, 0)
