extends Control
## Cooking (GameMenu screen "galley", open_galley): the recipes down the left (lit when the bag holds
## what one needs), the picked dish's card on the right (what it does and for how long, what it needs
## and what of yours it would use) with Cook. Food has the recipes and does the cooking.

const W_LIST := 150
const W_CARD := 220

## Portions of each dish from one set of ingredients (the ship's galley line).
var portions := 1
var _menu: Node
var _panel: PanelContainer
var _level: Label
var _list: VBoxContainer
var _card: VBoxContainer
var _cook_btn: Button
var _hints: HBoxContainer
var _buttons: Dictionary = {}
var _sel := ""
var _flash_t := 0.0


func _init(menu: Node) -> void:
	_menu = menu
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG, UIStyle.BORDER, 8))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	vb.add_child(head)
	var t := UIStyle.title("The Galley")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(t)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	_level = InventoryScreen.small("", UIStyle.ACCENT)
	_level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_level)
	vb.add_child(InventoryScreen._rule())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	vb.add_child(body)
	var c1 := VBoxContainer.new()
	c1.add_theme_constant_override("separation", 3)
	c1.custom_minimum_size = Vector2(W_LIST, 0)
	body.add_child(c1)
	c1.add_child(InventoryScreen.small("RECIPES", UIStyle.BORDER))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	c1.add_child(_list)
	for id in Food.ORDER:
		var b := UIStyle.button("", W_LIST)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.expand_icon = false
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func(): _pick(id))
		b.focus_entered.connect(func(): _pick(id))
		_list.add_child(b)
		_buttons[id] = b
	var c2 := VBoxContainer.new()
	c2.add_theme_constant_override("separation", 3)
	c2.custom_minimum_size = Vector2(W_CARD, 0)
	body.add_child(c2)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 2)
	_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c2.add_child(_card)
	_cook_btn = UIStyle.button("Cook", 90)
	_cook_btn.pressed.connect(cook_selected)
	c2.add_child(_cook_btn)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	vb.add_child(foot)
	_hints = HBoxContainer.new()
	_hints.add_theme_constant_override("separation", 10)
	_hints.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_hints)
	var leave := UIStyle.button("Leave", 80)
	leave.pressed.connect(func(): _menu.close())
	foot.add_child(leave)


## Cooking on the action wheel: aboard (the galley's portions) or by a camp's fire (one). (Method callables,
## not lambdas: a lambda from another script left in ActionWheel's static table crashes Godot at exit.)
func register_wheel() -> void:
	ActionWheel.register("cook", "Cook", "res://assets/textures/icons/fish_stew.png", _cook_ok, _cook, 30)


func _cook_ok(p):
	if not ActionWheel.on_foot(p):
		return false
	return ActionWheel.busy(p) if ActionWheel.place(p) == "ship" or Camp.near(p) != null else "At a galley or campfire"


func _cook(p) -> void:
	_menu.open_galley(get_node("/root/GameManager").galley_portions() if ActionWheel.place(p) == "ship" else 1)


func _player() -> Player:
	return _menu.call("_player")


func on_open() -> void:
	_flash_t = 0.0
	_set_hints()
	if _sel == "":
		_sel = Food.ORDER[0]
	_refresh()
	(_buttons[_sel] as Button).call_deferred("grab_focus")


func _pick(id: String) -> void:
	_sel = id
	_refresh()


func _refresh() -> void:
	var pl := _player()
	var pr := pl.progression
	var inv := pl.inventory_component
	_level.text = "COOKING LV %d" % pr.mastery_level("cook")
	for id in Food.ORDER:
		var b: Button = _buttons[id]
		var known := Food.known(pr, id)
		var ready := known and not Food.picks(inv, id).is_empty()
		b.text = str(Food.MEALS[id]["name"]) if known else "???"
		b.icon = ItemDB.get_item(id).icon if known else null
		b.add_theme_color_override("font_color", UIStyle.GOOD if ready else (UIStyle.TEXT if known else UIStyle.TEXT_DISABLED))
	_show_card()


func _show_card() -> void:
	InventoryScreen._clear(_card)
	var pl := _player()
	var pr := pl.progression
	var inv := pl.inventory_component
	var m: Dictionary = Food.MEALS[_sel]
	if not Food.known(pr, _sel):
		_card.add_child(InventoryScreen._text("An unknown recipe", UIStyle.TEXT_DIM, InventoryScreen.BOLD))
		var l := InventoryScreen.small("SOMEONE OUT THERE COULD TEACH IT TO YOU", UIStyle.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(W_CARD, 0)
		_card.add_child(l)
		_cook_btn.disabled = true
		return
	var it := ItemDB.get_item(_sel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var ic := TextureRect.new()
	ic.texture = it.icon
	ic.custom_minimum_size = Vector2(24, 24)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(ic)
	var name_l := InventoryScreen._text(it.display_name, it.rarity_color(), InventoryScreen.BOLD)
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_l)
	_card.add_child(row)
	_line(str(m["desc"]), UIStyle.TEXT_DIM)
	_card.add_child(InventoryScreen._rule())
	_line(("%d min: %s" % [roundi(Food.seconds(pr, _sel) / 60.0), Food.buff_text(_sel, Food.strength(pr))]).to_upper(), Color(1.0, 0.85, 0.45))
	_line("HEALS %d WHEN EATEN" % int(it.heal_amount), UIStyle.TEXT)
	_card.add_child(InventoryScreen._rule())
	var r: Dictionary = m["recipe"]
	for tag in r.keys():
		var have := Food.have(inv, tag)
		_line("%d %s  (YOU HAVE %d)" % [int(r[tag]), str(Food.TAG_NAMES[tag]).to_upper(), have], UIStyle.GOOD if have >= int(r[tag]) else UIStyle.DANGER_TEXT)
	var use := Food.picks(inv, _sel)
	if not use.is_empty():
		var names: Array = []
		for u in use:
			names.append("%d %s" % [int(u[1]), (u[0] as ItemData).display_name])
		_line("USES " + ", ".join(names).to_upper(), UIStyle.TEXT_DIM)
	_line("MAKES %d" % portions, UIStyle.ACCENT)
	_cook_btn.disabled = use.is_empty() or inv.room_for(it) < portions


func _line(text: String, col: Color) -> void:
	var l := InventoryScreen.small(text, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W_CARD, 0)
	_card.add_child(l)


## Cook the picked dish (portions of it) out of the bag.
func cook_selected() -> void:
	var pl := _player()
	var lv := pl.progression.mastery_level("cook")
	var why := Food.cook(pl, _sel, portions)
	if why != "":
		_flash(why, true)
		return
	UIStyle.sfx("sizzle")
	var name_ := str(Food.MEALS[_sel]["name"])
	# aboard, a pot of several portions goes on the galley table for the crew (the cook keeps one)
	if portions > 1 and GalleyTable.of(get_tree()) != null:
		pl.inventory_component.remove_item(ItemDB.get_item(_sel), portions - 1)
		Net.table_serve(_sel, portions - 1, pl.display_name(), Food.strength(pl.progression), Food.seconds(pl.progression, _sel))
		_flash("Cooked %s: one for you, %d on the galley table" % [name_, portions - 1], false)
		_refresh()
		return
	_flash("Cooked %s%s" % [name_, " x%d" % portions if portions > 1 else ""], false)
	if pl.progression.mastery_level("cook") > lv:
		UIStyle.sfx("level_up")
		_flash("Cooking %d! Cooked %s" % [pl.progression.mastery_level("cook"), name_], false)
	_refresh()


func _set_hints() -> void:
	InventoryScreen._clear(_hints)
	for p in [["LMB", "PICK"], ["ESC", "LEAVE"]]:
		_hints.add_child(UIStyle.key_hint(p[0], p[1]))


func _flash(text: String, bad: bool) -> void:
	InventoryScreen._clear(_hints)
	var l := InventoryScreen.small(text.to_upper(), UIStyle.DANGER_TEXT if bad else UIStyle.GOOD)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hints.add_child(l)
	_flash_t = 2.5
	if bad:
		UIStyle.sfx("deny")


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _flash_t <= 0.0:
		return
	_flash_t -= delta
	if _flash_t <= 0.0:
		_set_hints()
