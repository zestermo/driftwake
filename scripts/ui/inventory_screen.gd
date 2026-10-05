class_name InventoryScreen
extends Control
## Inventory as an overlay on the game (built by GameMenu). The world pauses,
## the camera swings round to face your captain and frames them on the left,
## and your real in-world character is the paper doll: gear slots flank them,
## with the bag / character sheet in a panel on the right.
##
## Inventory tab: bag, quick slots and item details. Character tab:
## attributes and the numbers that come from them and your gear, plus
## unlocked abilities.
## Drag and drop: move items around the bag, onto a gear / weapon slot to
## equip, onto a quick slot (consumables), out of a slot back into the bag,
## or out onto the world to drop them (X drops the hovered stack, shift+X
## one). Click bag gear to wear it, click a worn slot to take it off. Drag on
## the character to turn them.
## Opening a chest or a bag shows its contents in place of the paper doll:
## click to take, F takes everything, drag your own items in to store them.

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
var _offhand_slot: Button
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
var _doll_nodes: Array[Control] = []
var _quick: Array[Button] = []
var _loot_panel: PanelContainer
var _loot_title: Label
var _loot_slots: Array[Button] = []
var _container: Node = null
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
	# ...and drop items out onto the world here
	drag.set_drag_forwarding(Callable(), _can_drop_world, _drop_world)
	add_child(drag)

	_build_doll()
	_build_panel()
	_build_loot()


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
			_drag_slot(_doll[slot], {"src": "doll", "slot": slot})
	_weapon_slot = _doll_slot("Weapon", 0.05, 0.83, func():
		# click: put it away and fight with your fists
		var pl := _player()
		if pl and pl.equipped_weapon:
			pl.unequip_weapon()
			menu._play()
			refresh(), func(): _show_weapon())
	_offhand_slot = _doll_slot("Off-hand", 0.12, 0.83, func():
		var pl := _player()
		if pl and pl.offhand_weapon:
			pl.set_offhand(null)
			menu._play()
			refresh(), func(): _show_weapon(true))
	_drag_slot(_weapon_slot, {"src": "weapon"})
	_drag_slot(_offhand_slot, {"src": "offhand"})
	_defense_label = UIStyle.label("", 16, UIStyle.ACCENT)
	_defense_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	_defense_label.add_theme_constant_override("outline_size", 4)
	_defense_label.anchor_left = 0.33
	_defense_label.anchor_top = 0.845
	add_child(_defense_label)
	_doll_nodes.append(_defense_label)
	_name_label = UIStyle.title("")
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.anchor_left = 0.0
	_name_label.anchor_right = 0.5
	_name_label.anchor_top = 0.86
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)
	_doll_nodes.append(_name_label)


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
	_doll_nodes.append(holder)
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
		b.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				_offhand_from_bag(idx))
		_drag_slot(b, {"src": "bag", "idx": idx})
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
	# quick slots (keys 5-7): drag a consumable here
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 2)
	inv.add_child(qrow)
	var ql := _tiny("QUICK\nITEMS", UIStyle.TEXT_DIM)
	ql.custom_minimum_size = Vector2(36, 0)
	qrow.add_child(ql)
	for k in range(InventoryComponent.HOTBAR_SIZE):
		var qb: Button = _small_slot(SLOT)
		var qi := k
		qb.mouse_entered.connect(func(): _show_quick(qi))
		qb.focus_entered.connect(func(): _show_quick(qi))
		qb.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
				var pl := _player()
				if pl:
					pl.inventory_component.clear_hotbar_slot(qi)
					menu._play()
					refresh())
		_drag_slot(qb, {"src": "quick", "idx": qi})
		qrow.add_child(qb)
		_quick.append(qb)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv.add_child(grow)
	inv.add_child(HSeparator.new())
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
	bottom.add_child(_tiny("Tab / I: close   Drag items to move, equip or drop\nX: drop (shift: one)   Drag your captain to turn", UIStyle.TEXT_DIM))
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
	for slot in _doll.keys():
		var it := pl.equipment.get_item(slot)
		menu.set_slot(_doll[slot], it, 1 if it else 0)
	menu.set_slot(_weapon_slot, pl.equipped_weapon, 1 if pl.equipped_weapon else 0, "", pl.armed)
	menu.set_slot(_offhand_slot, pl.offhand_weapon, 1 if pl.offhand_weapon else 0, "", pl.armed and pl.offhand_weapon != null)
	for k in range(_quick.size()):
		var qid: String = inv.hotbar[k]
		var qit: ItemData = inv.get_hotbar_item(k) if qid != "" else null
		menu.set_slot(_quick[k], qit, inv.count(qid) if qit else 0, str(k + 5))
	_refresh_loot()
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
			_info_hint.text = "Click: equip   Right-click: off hand"
		ItemData.ItemType.CONSUMABLE:
			_info_type.text = "Consumable"
			_info_stats.text = "Restores %d health" % int(it.heal_amount)
			var qs := pl.inventory_component.hotbar.find(it.id) if pl else -1
			_info_hint.text = "Click: use   5-7: quick slot" + ("  (on %d)" % (qs + 5) if qs >= 0 else "")
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


func _show_weapon(off: bool = false) -> void:
	var pl := _player()
	if pl == null:
		return
	var it := pl.offhand_weapon if off else pl.equipped_weapon
	if it:
		_describe(it, true)
		_info_hint.text = "Click to take it out of your hand." if off else "Click to fight unarmed. Click a weapon in your bag to swap, right-click for the off hand."
	else:
		_clear_info()
		_info_name.text = "Off hand: empty" if off else "Fists"
		_info_hint.text = "Right-click a second sword or pistol in your bag to dual wield." if off else "Unarmed: punches and kicks. Click a weapon in your bag to arm yourself."


## Right-click a weapon in the bag: hold it in the off hand (dual wielding).
func _offhand_from_bag(idx: int) -> void:
	var pl := _player()
	if pl == null or idx >= pl.inventory_component.items.size():
		return
	var it := pl.inventory_component.items[idx].item
	if not it.is_weapon():
		return
	if pl.offhand_weapon == it:
		pl.set_offhand(null)
	elif not pl.set_offhand(it):
		_info_hint.text = "The off hand needs the same kind of weapon as your main hand (two swords or two pistols)."
		return
	menu._play()
	refresh()


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
	elif it.is_consumable() and it.devil_fruit != "":
		_confirm_fruit(it)
	elif it.is_consumable():
		menu.close()
		pl.use_item(it)


var _confirm: PanelContainer


## Eating a Devil Fruit can't be undone: ask first.
func _confirm_fruit(it: ItemData) -> void:
	if _confirm:
		_confirm.queue_free()
	var pl := _player()
	_confirm = PanelContainer.new()
	_confirm.add_theme_stylebox_override("panel", UIStyle.box(Color(0.06, 0.03, 0.02, 0.97), Color(1.0, 0.55, 0.2), 10, 2))
	_confirm.set_anchors_preset(Control.PRESET_CENTER)
	_confirm.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_confirm.add_child(v)
	var t := UIStyle.label("Eat the %s?" % it.display_name, 16, Color(1.0, 0.7, 0.35))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var body := "Fire will answer to you. But a Devil Fruit's curse is forever: you will never swim again, and deep water will drag you under."
	if pl and pl.power.has_fruit():
		body = "You already carry a Devil Fruit's power. A second would kill you."
	var d := _tiny(body, UIStyle.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(230, 0)
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
		var yes := UIStyle.button("Eat it", 80)
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
	add_child(_confirm)
	menu._play()


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
	if not InventoryComponent.quick_ok(it):
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

	_section("Progress")
	var pr := pl.progression
	_row("Level", str(pr.level), "%d / %d XP" % [pr.xp, Progression.xp_to_next(pr.level)])
	_row("Skill points", str(pr.skill_points), "Spend them on the skill map (K)")
	_row("Air jumps", str(pl.max_jumps - 1), "" if pl.max_jumps > 1 else "Geppo on the skill map")
	_row("Style", pl.style().replace("_", " ").capitalize(), "")

	_section("Devil Fruit")
	if pl.power.has_fruit():
		var fd := pl.power.fruit_data()
		_sheet.add_child(UIStyle.label("%s (%s)" % [fd["name"], DevilFruits.type_name(pl.power.fruit)], 12, fd["color"]))
		_note(str(fd["passive"][0]), str(fd["passive"][1]))
		_note(str(DevilFruits.CURSE[0]), str(DevilFruits.CURSE[1]))
	else:
		_sheet.add_child(UIStyle.label("None. Rumor has it there are three on this island.", 12, UIStyle.TEXT_DIM))

	_section("Skill bar")
	for i in range(5):
		var sk := pl.power.skill(i)
		var key := "R" if i == 4 else str(i + 1)
		if sk.is_empty():
			_row(key, "-", "")
		else:
			var cost := "ultimate" if i == 4 else "%d energy" % int(sk["cost"])
			_row(key, str(sk["name"]), "%s, %ss" % [cost, str(snappedf(float(sk["cooldown"]), 0.1))])
	_sheet.add_child(_tiny("Learn skills on the skill map (K).", UIStyle.TEXT_DIM))

	_section("Worn")
	var any := false
	for s in Gear.SLOTS:
		var it := pl.equipment.get_item(s[0])
		if it:
			any = true
			_row(s[1], it.display_name, "DEF %d" % int(it.defense) if it.defense > 0.0 else "")
	if not any:
		_sheet.add_child(UIStyle.label("Nothing but smallclothes.", 12, UIStyle.TEXT_DIM))


## A titled line with a wrapped description under it (skills, passives).
func _note(title: String, body: String) -> void:
	_sheet.add_child(_tiny(title, UIStyle.ACCENT))
	var d := _tiny(body, UIStyle.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(200, 0)
	_sheet.add_child(d)


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


# ==========================================================================
# Drag and drop
# ==========================================================================
## Make a slot draggable (with `data` describing where it came from) and a
## drop target.
func _drag_slot(b: Button, data: Dictionary) -> void:
	b.set_drag_forwarding(func(_at: Vector2): return _drag_from(b, data),
		func(_at: Vector2, d) -> bool: return _can_drop_on(data, d),
		func(_at: Vector2, d) -> void: _drop_on(data, d))


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


func _drag_from(b: Button, data: Dictionary):
	var it := _item_of(data)
	if it == null:
		return null
	var prev := TextureRect.new()
	prev.texture = it.icon
	prev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prev.size = Vector2(24, 24)
	prev.position = Vector2(-12, -12)
	prev.modulate = Color(1, 1, 1, 0.85)
	var holder := Control.new()
	holder.add_child(prev)
	b.set_drag_preview(holder)
	var d := data.duplicate()
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
				"weapon":
					pl.unequip_weapon()
				"offhand":
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
				_info_hint.text = "The off hand needs the same kind of weapon as your main hand (two swords or two pistols)."
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


## Dragging a bag item out onto the world: drop it.
func _can_drop_world(_at: Vector2, d) -> bool:
	return d is Dictionary and str((d as Dictionary).get("src", "")) == "bag"


func _drop_world(_at: Vector2, d) -> void:
	var pl := _player()
	if pl and _can_drop_world(_at, d):
		pl.drop_from_bag(int(d["idx"]))
		menu._play()
		refresh()


## X over a bag slot: drop that stack (one, with shift).
func drop_selected(one: bool) -> void:
	var pl := _player()
	if pl == null or _selected < 0 or _selected >= pl.inventory_component.items.size():
		return
	pl.drop_from_bag(_selected, 1 if one else -1)
	menu._play()
	refresh()


func _show_quick(k: int) -> void:
	var pl := _player()
	if pl == null:
		return
	var it: ItemData = pl.inventory_component.get_hotbar_item(k) if pl.inventory_component.hotbar[k] != "" else null
	if it == null:
		_clear_info()
		_info_name.text = "Quick slot %d: empty" % (k + 5)
		_info_hint.text = "Drag a consumable here (or hover one in the bag and press %d)." % (k + 5)
		return
	_describe(it, false, pl.inventory_component.count(it.id))
	_info_hint.text = "Press %d to use it in the world. Right-click: clear." % (k + 5)


# ==========================================================================
# Loot window (a chest or bag beside your bag)
# ==========================================================================
func _build_loot() -> void:
	_loot_panel = PanelContainer.new()
	_loot_panel.anchor_left = 0.03
	_loot_panel.anchor_right = 0.46
	_loot_panel.anchor_top = 0.1
	_loot_panel.anchor_bottom = 0.8
	_loot_panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.06, 0.04, 0.03, 0.9), UIStyle.ACCENT, 6, 1))
	_loot_panel.visible = false
	add_child(_loot_panel)
	_loot_panel.set_drag_forwarding(Callable(), func(_at: Vector2, d) -> bool: return _can_drop_on({"src": "loot"}, d),
		func(_at: Vector2, d) -> void: _drop_on({"src": "loot"}, d))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_loot_panel.add_child(vb)
	_loot_title = UIStyle.label("Chest", 16, UIStyle.ACCENT)
	vb.add_child(_loot_title)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	vb.add_child(grid)
	for i in range(20):
		var b: Button = _small_slot(SLOT)
		var idx := i
		b.mouse_entered.connect(func(): _show_loot(idx))
		b.focus_entered.connect(func(): _show_loot(idx))
		b.pressed.connect(func():
			var pl := _player()
			if pl and has_container():
				_container.take(idx, pl, 1 if Input.is_key_pressed(KEY_SHIFT) else -1)
				menu._play()
				refresh())
		_drag_slot(b, {"src": "loot", "idx": idx})
		grid.add_child(b)
		_loot_slots.append(b)
	var hint := _tiny("Click: take (shift: one)   Drag your items here to store", UIStyle.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(150, 0)
	vb.add_child(hint)
	var take := UIStyle.button("Take all  [F]", 110)
	take.add_theme_font_size_override("font_size", 12)
	take.pressed.connect(func(): take_all())
	vb.add_child(take)


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
	for i in range(_loot_slots.size()):
		if i < cont.size():
			menu.set_slot(_loot_slots[i], cont[i].item, cont[i].quantity)
		else:
			menu.set_slot(_loot_slots[i], null, 0)


func _show_loot(idx: int) -> void:
	if not has_container() or idx >= _container.contents.size():
		_clear_info()
		_info_name.text = "Empty"
		return
	var st = _container.contents[idx]
	_describe(st.item, false, st.quantity)
	_info_hint.text = "Click: take it   Shift+click: take one"
