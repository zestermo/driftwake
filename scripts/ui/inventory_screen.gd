class_name InventoryScreen
extends Control
## Inventory as an overlay on the game (built by GameMenu). The world pauses,
## the camera swings round to face your captain and frames them on the left,
## and your real in-world character is the paper doll: gear slots flank them,
## with the bag / character sheet in a panel on the right.
##
## Inventory tab: bag, item details, hotbar. Character tab: attributes and the
## numbers that come from them and your gear, plus unlocked abilities.
## Click bag gear to wear it, click a worn slot to take it off. Drag on the
## character to turn them.

## Sized for the game's 640x360 UI canvas (the window scales it up).
const SLOT := 28
const DOLL_SLOT := 30
const TINY_FONT := preload("res://assets/fonts/Silkscreen-Regular.woff2")

var menu: Node  # GameMenu (for close / blip / slot helpers)
var _tab := "inventory"
var _tab_buttons: Dictionary = {}
var _pages: Dictionary = {}
var _bag: Array[Button] = []
var _hotbar: Array[Button] = []
var _doll: Dictionary = {}  # slot id -> Button
var _weapon_slot: Button
var _defense_label: Label
var _name_label: Label
var _info_name: Label
var _info_type: Label
var _info_desc: Label
var _info_stats: Label
var _info_hint: Label
var _footer: Label
var _sheet: VBoxContainer
var _selected := -1
var _dragging := false
var _body_was_mode := Node.PROCESS_MODE_INHERIT


func _init(owner_menu: Node) -> void:
	menu = owner_menu
	name = "Inventory"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null


# ==========================================================================
# Build
# ==========================================================================
func _build() -> void:
	# soft shade behind the panel only; the left of the screen stays the game
	var shade := TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0.01, 0.015, 0.03, 0.72))
	g.set_offset(0, 0.38)
	g.set_offset(1, 0.62)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(shade)

	# drag-to-turn area over the character
	var drag := Control.new()
	drag.anchor_right = 0.5
	drag.anchor_bottom = 1.0
	drag.mouse_filter = Control.MOUSE_FILTER_STOP
	drag.gui_input.connect(_on_drag_input)
	add_child(drag)

	_build_doll()
	_build_panel()


func _build_doll() -> void:
	var left := [["head", 0], ["torso", 1], ["vest", 2], ["coat", 3], ["belt", 4]]
	var right := [["hands", 0], ["legs", 1], ["feet", 2], ["acc1", 3], ["acc2", 4]]
	for col in [[left, 0.05], [right, 0.33]]:
		for e in col[0]:
			var slot: String = e[0]
			var label := ""
			for s in Gear.SLOTS:
				if s[0] == slot:
					label = s[1]
			_doll[slot] = _doll_slot(label, col[1], 0.15 + float(e[1]) * 0.135, func(): _on_doll_pressed(slot), func(): _show_worn(slot))
	_weapon_slot = _doll_slot("Weapon", 0.05, 0.83, func(): pass, func(): _show_weapon())
	_defense_label = UIStyle.label("", 16, UIStyle.ACCENT)
	_defense_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	_defense_label.add_theme_constant_override("outline_size", 4)
	_defense_label.anchor_left = 0.33
	_defense_label.anchor_top = 0.845
	add_child(_defense_label)
	_name_label = UIStyle.title("")
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.anchor_left = 0.0
	_name_label.anchor_right = 0.5
	_name_label.anchor_top = 0.86
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)


func _doll_slot(text: String, ax: float, ay: float, on_press: Callable, on_hover: Callable) -> Button:
	var holder := VBoxContainer.new()
	holder.anchor_left = ax
	holder.anchor_top = ay
	holder.add_theme_constant_override("separation", 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var b: Button = _small_slot(DOLL_SLOT)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(on_press)
	b.mouse_entered.connect(on_hover)
	b.focus_entered.connect(on_hover)
	holder.add_child(b)
	var l := _tiny(text, UIStyle.TEXT)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(DOLL_SLOT, 0)
	holder.add_child(l)
	# center the column on the slot, not on the (wider) label
	holder.offset_left = -max(0.0, l.get_minimum_size().x - DOLL_SLOT) * 0.5
	return b


func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.985
	panel.anchor_top = 0.05
	panel.anchor_bottom = 0.95
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.04, 0.05, 0.09, 0.88), UIStyle.BORDER, 6, 1))
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	vb.add_child(tabs)
	for t in [["inventory", "Inventory"], ["character", "Character"]]:
		var b := UIStyle.button(t[1])
		b.add_theme_font_size_override("font_size", 12)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = t[0]
		b.pressed.connect(func(): menu._play(); show_tab(id))
		tabs.add_child(b)
		_tab_buttons[id] = b

	# ---- inventory page
	var inv := VBoxContainer.new()
	inv.add_theme_constant_override("separation", 6)
	inv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(inv)
	_pages["inventory"] = inv
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	inv.add_child(hb)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	hb.add_child(grid)
	for i in range(20):
		var b: Button = _small_slot(SLOT)
		var idx := i
		b.mouse_entered.connect(func(): _select(idx))
		b.focus_entered.connect(func(): _select(idx))
		b.pressed.connect(func(): _use(idx))
		grid.add_child(b)
		_bag.append(b)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	hb.add_child(info)
	info.custom_minimum_size = Vector2(110, 0)
	_info_name = UIStyle.label("", 12, UIStyle.ACCENT)
	_info_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_type = _tiny("", UIStyle.TEXT_DIM)
	_info_desc = UIStyle.label("", 12)
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_stats = UIStyle.label("", 12, Color(0.6, 0.85, 0.6))
	_info_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_hint = _tiny("", UIStyle.TEXT_DIM)
	_info_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l in [_info_name, _info_type, _info_desc, _info_stats, _info_hint]:
		(l as Label).custom_minimum_size = Vector2(110, 0)
		info.add_child(l)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv.add_child(grow)
	inv.add_child(HSeparator.new())
	var hot := HBoxContainer.new()
	hot.add_theme_constant_override("separation", 3)
	inv.add_child(hot)
	hot.add_child(_tiny("Hotbar ", UIStyle.TEXT_DIM))
	for i in range(InventoryComponent.HOTBAR_SIZE):
		var b: Button = _small_slot(26)
		var idx := i
		b.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				var pl := _player()
				if pl:
					pl.inventory_component.clear_hotbar_slot(idx)
					refresh())
		b.tooltip_text = "Right-click to clear"
		hot.add_child(b)
		_hotbar.append(b)
	_footer = _tiny("", UIStyle.TEXT_DIM)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inv.add_child(_footer)

	# ---- character page
	var ch := ScrollContainer.new()
	ch.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(ch)
	_pages["character"] = ch
	_sheet = VBoxContainer.new()
	_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet.add_theme_constant_override("separation", 2)
	ch.add_child(_sheet)

	var bottom := HBoxContainer.new()
	vb.add_child(bottom)
	bottom.add_child(_tiny("Tab / I: close\nDrag your captain to turn them", UIStyle.TEXT_DIM))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp)
	var close_b := UIStyle.button("Close", 56)
	close_b.add_theme_font_size_override("font_size", 12)
	close_b.pressed.connect(func(): menu.close())
	bottom.add_child(close_b)


# ==========================================================================
# Open / close
# ==========================================================================
func on_open() -> void:
	var pl := _player()
	if pl == null:
		return
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
		rig.set_showcase(true, pl.player_model.global_rotation.y)
	show_tab(_tab)
	refresh()


func focus_bag() -> void:
	if _tab == "inventory" and not _bag.is_empty():
		_bag[0].call_deferred("grab_focus")


func on_close() -> void:
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


func _process(_delta: float) -> void:
	if not visible:
		return
	# keep the captain's eyes on the viewer while the world is paused
	var pl := _player()
	var cam := get_viewport().get_camera_3d()
	if pl and pl.body_model and cam:
		pl.body_model.look_target = cam.global_position
		pl.body_model.look_weight = 0.55


func show_tab(id: String) -> void:
	_tab = id
	for k in _pages.keys():
		(_pages[k] as Control).visible = (k == id)
		(_tab_buttons[k] as Button).button_pressed = (k == id)
	if id == "character":
		_fill_sheet()


func _on_drag_input(ev: InputEvent) -> void:
	var pl := _player()
	if pl == null:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_dragging = ev.pressed
	elif ev is InputEventMouseMotion and _dragging:
		pl.player_model.rotation.y += ev.relative.x * 0.012


# ==========================================================================
# Refresh
# ==========================================================================
func refresh() -> void:
	var pl := _player()
	if pl == null:
		return
	var inv := pl.inventory_component
	for i in range(_bag.size()):
		if i < inv.items.size():
			var st := inv.items[i]
			menu.set_slot(_bag[i], st.item, st.quantity, "", st.item == pl.equipped_weapon)
		else:
			menu.set_slot(_bag[i], null, 0)
	for i in range(_hotbar.size()):
		var item := inv.get_hotbar_item(i)
		menu.set_slot(_hotbar[i], item, inv.count(item.id) if item else 0, str(i + 1), item != null and item == pl.equipped_weapon)
	for slot in _doll.keys():
		var it := pl.equipment.get_item(slot)
		menu.set_slot(_doll[slot], it, 1 if it else 0)
	menu.set_slot(_weapon_slot, pl.equipped_weapon, 1 if pl.equipped_weapon else 0, "", pl.armed)
	_defense_label.text = "DEF %d" % int(pl.defense())
	_name_label.text = str(pl.body_model.look.get("name", "Captain")) if pl.body_model else "Captain"
	var gm := get_node_or_null("/root/GameManager")
	var bg: int = gm.banked_count("gold") if gm else 0
	var bt: int = gm.banked_count("treasure") if gm else 0
	_footer.text = "Carrying %d loot (unbanked).  Banked: %d gold, %d treasure." % [inv.get_loot_count(), bg, bt]
	if _tab == "character":
		_fill_sheet()
	_select(clampi(_selected, 0, 19) if _selected >= 0 else 0)


func _clear_info() -> void:
	for l in [_info_name, _info_type, _info_desc, _info_stats, _info_hint]:
		(l as Label).text = ""


func _describe(it: ItemData, worn: bool, qty: int = 1) -> void:
	var pl := _player()
	_info_name.text = it.display_name + ("  x%d" % qty if qty > 1 else "")
	_info_desc.text = it.description
	match it.item_type:
		ItemData.ItemType.WEAPON:
			_info_type.text = "Weapon" + ("  (equipped)" if it == pl.equipped_weapon else "")
			_info_stats.text = "Damage x%.1f\nHeavy: %s" % [it.damage_mult, {"thrust": "lunging thrust", "axe": "overhead chop", "slam": "leaping slam"}.get(
				preload("res://scripts/player_states/heavy_attack_state.gd").style_for(it.weapon_model), "slam")]
			_info_hint.text = "Click: equip   1-5: put on hotbar"
		ItemData.ItemType.CONSUMABLE:
			_info_type.text = "Consumable"
			_info_stats.text = "Restores %d health" % int(it.heal_amount)
			_info_hint.text = "Click: use   1-5: put on hotbar"
		ItemData.ItemType.GEAR:
			_info_type.text = Gear.slot_label(it.gear_slot) + ("  (worn)" if worn else "")
			var line := "Defense %d" % int(it.defense)
			if not worn and pl:
				var cur := pl.equipment.get_item(pl.equipment.slot_for(it))
				var d := int(it.defense - (cur.defense if cur else 0.0))
				line += "   (%s%d vs worn)" % ["+" if d >= 0 else "", d]
			_info_stats.text = line
			_info_hint.text = "Click: take off" if worn else "Click: wear"
		_:
			_info_type.text = "Loot"
			_info_stats.text = "Value %d each" % it.value
			_info_hint.text = "Bank it at your ship's chest to keep it."


func _select(idx: int) -> void:
	_selected = idx
	var pl := _player()
	if pl == null:
		return
	var inv := pl.inventory_component
	if idx >= inv.items.size():
		_clear_info()
		_info_name.text = "Empty"
		return
	var st := inv.items[idx]
	_describe(st.item, false, st.quantity)


func _show_worn(slot: String) -> void:
	var pl := _player()
	if pl == null:
		return
	var it := pl.equipment.get_item(slot)
	if it == null:
		_clear_info()
		for s in Gear.SLOTS:
			if s[0] == slot:
				_info_name.text = "%s: empty" % s[1]
		_info_hint.text = "Wear something from your bag."
		return
	_describe(it, true)


func _show_weapon() -> void:
	var pl := _player()
	if pl and pl.equipped_weapon:
		_describe(pl.equipped_weapon, true)
		_info_hint.text = "Pick a different weapon from your bag to swap."


# ==========================================================================
# Actions
# ==========================================================================
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
	elif it.is_consumable():
		menu.close()
		pl.use_item(it)


func _on_doll_pressed(slot: String) -> void:
	var pl := _player()
	if pl and pl.unequip_gear(slot):
		menu._play()
	refresh()
	_show_worn(slot)


func assign_hotbar(slot: int) -> void:
	var pl := _player()
	if pl == null or _selected < 0 or _selected >= pl.inventory_component.items.size():
		return
	var it := pl.inventory_component.items[_selected].item
	if it.is_loot() or it.is_gear():
		return
	pl.inventory_component.assign_hotbar(slot, it.id)
	menu._play()
	refresh()


# ==========================================================================
# Character sheet
# ==========================================================================
func _fill_sheet() -> void:
	for c in _sheet.get_children():
		_sheet.remove_child(c)
		c.queue_free()
	var pl := _player()
	if pl == null:
		return
	var lk: Dictionary = pl.body_model.look if pl.body_model else {}
	_sheet.add_child(UIStyle.label(str(lk.get("name", "Captain")), 16, UIStyle.ACCENT))
	_sheet.add_child(_tiny("Captain of a very small crew", UIStyle.TEXT_DIM))

	_section("Attributes")
	_row("Strength", str(pl.attribute("strength")), "Weapon damage")
	_row("Agility", str(pl.attribute("agility")), "Footwork (skills later)")
	_row("Endurance", str(pl.attribute("endurance")), "Health and stamina")

	_section("Combat")
	var hc := pl.health_component
	_row("Health", "%d / %d" % [int(hc.current_health), int(hc.max_health)])
	_row("Stamina", "%d" % int(pl.max_stamina), "Attacks, dodges and sprinting")
	var w := pl.equipped_weapon
	_row("Weapon", w.display_name if w else "Fists")
	_row("Damage", "x%.2f" % pl.damage_multiplier())
	_row("Defense", "%d" % int(pl.defense()), "Blocks %d%% of incoming damage" % int(round(pl.damage_reduction() * 100.0)))

	_section("Movement")
	_row("Speed", "%.1f m/s" % pl.move_speed)
	_row("Sprint", "%.1f m/s" % pl.sprint_speed)

	_section("Abilities")
	_row("Double jump", "Unlocked" if pl.has_ability("double_jump") else "Locked", "" if pl.has_ability("double_jump") else "Learned later")

	_section("Worn")
	var any := false
	for s in Gear.SLOTS:
		var it := pl.equipment.get_item(s[0])
		if it:
			any = true
			_row(s[1], it.display_name, "DEF %d" % int(it.defense) if it.defense > 0.0 else "")
	if not any:
		_sheet.add_child(UIStyle.label("Nothing but smallclothes.", 12, UIStyle.TEXT_DIM))


func _section(text: String) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 3)
	_sheet.add_child(sp)
	var l := _tiny(text.to_upper(), UIStyle.BORDER)
	_sheet.add_child(l)
	_sheet.add_child(HSeparator.new())


func _row(label_text: String, value: String, note: String = "") -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	var l := UIStyle.label(label_text, 12, UIStyle.TEXT_DIM)
	l.custom_minimum_size = Vector2(66, 0)
	hb.add_child(l)
	var v := UIStyle.label(value, 12, UIStyle.TEXT)
	v.custom_minimum_size = Vector2(76, 0)
	v.clip_text = true
	hb.add_child(v)
	if note != "":
		var n := _tiny(note, UIStyle.TEXT_DIM)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hb.add_child(n)
	_sheet.add_child(hb)


## Small pixel font (crisp at the 640x360 UI canvas).
func _tiny(text: String, color: Color = UIStyle.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", TINY_FONT)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	return l


## Slot with its icon area matched to the 24 px icons.
func _small_slot(size: int) -> Button:
	var b: Button = menu.make_slot(size)
	var icon := b.get_node("Icon") as TextureRect
	var pad := maxi((size - 24) / 2, 1)
	icon.offset_left = pad
	icon.offset_top = pad
	icon.offset_right = -pad
	icon.offset_bottom = -pad
	return b
