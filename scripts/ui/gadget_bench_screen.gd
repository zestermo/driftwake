extends Control
## The workbench (GameMenu screen "workbench", opened at a Workbench): the gadgets down the left (lit when the next
## step can be paid for; "???" while the blueprint's unknown), the picked one's card on the right: what it does at its
## tier, the next tier's price against your bag and the Tinkering it needs, Build / Upgrade, its charges and Refill,
## and which belt slot it sits in. Refill all at the foot. Gadgets does the work; this only shows and asks.

const W_LIST := 190
const W_CARD := 320
const LIST_H := 360

var bench: Node3D
var _menu: Node
var _panel: PanelContainer
var _level: Label
var _list: VBoxContainer
var _card: VBoxContainer
var _build_btn: Button
var _refill_btn: Button
var _slot_btns: Array = []
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
	var t := UIStyle.title("Workbench")
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
	c1.add_child(InventoryScreen.small("GADGETS", UIStyle.BORDER))
	# (twenty gadgets: the list scrolls)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(W_LIST + 8, LIST_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c1.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)
	for id in Gadgets.WORKING:
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
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 6)
	c2.add_child(acts)
	_build_btn = UIStyle.button("Build", 96)
	_build_btn.pressed.connect(build_selected)
	acts.add_child(_build_btn)
	_refill_btn = UIStyle.button("Refill", 80)
	_refill_btn.pressed.connect(refill_selected)
	acts.add_child(_refill_btn)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 4)
	c2.add_child(slots)
	slots.add_child(InventoryScreen.small("ON THE BELT:", UIStyle.TEXT_DIM))
	for i in range(GadgetData.BAG_SLOTS):
		var sb := UIStyle.button(str(i + 1), 30)
		sb.pressed.connect(func(): slot_selected(i))
		slots.add_child(sb)
		_slot_btns.append(sb)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	vb.add_child(foot)
	_hints = HBoxContainer.new()
	_hints.add_theme_constant_override("separation", 10)
	_hints.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_hints)
	var all := UIStyle.button("Refill all", 90)
	all.pressed.connect(refill_all)
	foot.add_child(all)
	var leave := UIStyle.button("Leave", 80)
	leave.pressed.connect(func(): _menu.close())
	foot.add_child(leave)


func _player() -> Player:
	return _menu.call("_player")


func on_open() -> void:
	_flash_t = 0.0
	_set_hints()
	if _sel == "":
		_sel = Gadgets.WORKING[0]
	_refresh()
	(_buttons[_sel] as Button).call_deferred("grab_focus")


func _pick(id: String) -> void:
	_sel = id
	_refresh()


func _refresh() -> void:
	var pl := _player()
	_level.text = "TINKERING LV %d   %d GOLD" % [pl.progression.mastery_level("tinker"), pl.inventory_component.count("gold")]
	for id in Gadgets.WORKING:
		var b: Button = _buttons[id]
		var known := Gadgets.knows(pl, id)
		var t: int = pl.gadgets.tier_of(id)
		b.text = ("%s%s" % [GadgetData.GADGETS[id]["name"], " " + GadgetData.TIER_NAMES[t] if t >= 0 else ""]) if known else "???"
		b.icon = GadgetModels.icon(id, maxi(t, 0)) if known else null
		var ready := known and Gadgets.why_not(pl, id) == ""
		b.add_theme_color_override("font_color", UIStyle.GOOD if ready else (UIStyle.TEXT if known else UIStyle.TEXT_DISABLED))
	_show_card()


func _show_card() -> void:
	InventoryScreen._clear(_card)
	var pl := _player()
	var g: Dictionary = GadgetData.GADGETS[_sel]
	var belt: GadgetBelt = pl.gadgets
	if not Gadgets.knows(pl, _sel):
		_card.add_child(InventoryScreen._text("An unknown blueprint", UIStyle.TEXT_DIM, InventoryScreen.BOLD))
		_line("FOUND IN: %s" % str(g["from"]).to_upper(), UIStyle.TEXT_DIM)
		_build_btn.disabled = true
		_refill_btn.disabled = true
		for sb in _slot_btns:
			(sb as Button).disabled = true
		return
	var t := belt.tier_of(_sel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var ic := TextureRect.new()
	ic.texture = GadgetModels.icon(_sel, maxi(t, 0))
	ic.custom_minimum_size = Vector2(28, 28)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(ic)
	var nm := InventoryScreen._text("%s  %s" % [g["name"], GadgetData.TIER_NAMES[t] if t >= 0 else "(not built)"], UIStyle.ACCENT if t == 2 else UIStyle.TEXT, InventoryScreen.BOLD)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(nm)
	_card.add_child(row)
	_line(str(g["desc"]), UIStyle.TEXT_DIM)
	if t >= 0:
		_line(Gadgets.stat_text(_sel, t).to_upper(), Color(1.0, 0.85, 0.45))
	_card.add_child(InventoryScreen._rule())
	var nt := Gadgets.next_tier(pl, _sel)
	if nt < 0:
		_line("FULLY UPGRADED", UIStyle.ACCENT)
		_build_btn.text = "Mk III"
		_build_btn.disabled = true
	else:
		_line("%s %s: %s" % ["BUILD" if nt == 0 else "UPGRADE TO", GadgetData.TIER_NAMES[nt].to_upper(), Gadgets.stat_text(_sel, nt).to_upper()], UIStyle.TEXT)
		var need: int = GadgetData.TIER_TINKER[nt]
		_line("NEEDS TINKERING %d" % need, UIStyle.GOOD if pl.progression.mastery_level("tinker") >= need else UIStyle.DANGER_TEXT)
		for e in Gadgets.cost(_sel, nt):
			var have := pl.inventory_component.count(str(e[0]))
			_line("%d %s  (YOU HAVE %d)" % [int(e[1]), Gadgets._name(str(e[0])).to_upper(), have], UIStyle.GOOD if have >= int(e[1]) else UIStyle.DANGER_TEXT)
		_build_btn.text = "Build" if nt == 0 else "Upgrade"
		_build_btn.disabled = false
		if GadgetData.GADGETS[_sel]["kind"] == "ship" and not _aboard():
			_line("BUILT AND FITTED ONLY AT THE BENCH ABOARD YOUR SHIP", UIStyle.DANGER_TEXT)
			_build_btn.disabled = true
	_card.add_child(InventoryScreen._rule())
	var mc := belt.max_charges(_sel) if t >= 0 else 0
	if t >= 0 and mc > 0:
		_line("CHARGES %d / %d   REFILL: %s" % [belt.charges(_sel), mc, Gadgets.cost_text(Gadgets.refill_cost(_sel)).to_upper()], UIStyle.TEXT)
	elif t >= 0:
		_line("NO CHARGES: ONLY ITS COOLDOWN", UIStyle.TEXT_DIM)
	_refill_btn.disabled = t < 0 or mc <= 0 or belt.charges(_sel) >= mc
	for i in range(_slot_btns.size()):
		var sb: Button = _slot_btns[i]
		sb.visible = i < belt.slots.size()
		if not sb.visible:
			continue
		sb.disabled = t < 0 or g["kind"] == "ship"
		sb.modulate = Color(1.0, 0.85, 0.4) if belt.slots[i] == _sel else Color.WHITE


## At the bench aboard the ship (where ship gadgets are built and fitted).
func _aboard() -> bool:
	return bench != null and bench.get("style") == "ship"


func _line(text: String, col: Color) -> void:
	var l := InventoryScreen.small(text, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W_CARD, 0)
	_card.add_child(l)


func build_selected() -> void:
	var pl := _player()
	if GadgetData.GADGETS[_sel]["kind"] == "ship" and not _aboard():
		_flash("Build it at the bench aboard your ship", true)
		return
	var was := pl.progression.mastery_level("tinker")
	var why := Gadgets.build(pl, _sel)
	if why != "":
		_flash(why, true)
		return
	UIStyle.sfx("buy")
	if bench:
		Net.fx("sparkle", [bench.global_position + Vector3(0, 1.0, 0), 10, GadgetModels.BRASS])
		Net.fx("sfx", ["clack", bench.global_position + Vector3(0, 1.0, 0), -4.0, 0.1, 1.2])
	var t: int = pl.gadgets.tier_of(_sel)
	_flash("%s %s %s" % ["Built" if t == 0 else "Upgraded:", GadgetData.GADGETS[_sel]["name"], GadgetData.TIER_NAMES[t]], false)
	if pl.progression.mastery_level("tinker") > was:
		UIStyle.sfx("level_up")
	_refresh()


func refill_selected() -> void:
	var why := Gadgets.refill(_player(), _sel)
	if why != "":
		_flash(why, true)
		return
	UIStyle.sfx("buy")
	_flash("Refilled", false)
	_refresh()


func refill_all() -> void:
	var pl := _player()
	var n := 0
	var short := ""
	for gid in pl.gadgets.owned.keys():
		var why := Gadgets.refill(pl, gid)
		if why == "":
			n += 1
		elif why.begins_with("Short"):
			short = why
	if n == 0:
		_flash(short if short != "" else "All full", short != "")
		return
	UIStyle.sfx("buy")
	_flash("Refilled %d gadget%s" % [n, "" if n == 1 else "s"], false)
	_refresh()


func slot_selected(i: int) -> void:
	var belt: GadgetBelt = _player().gadgets
	belt.put(i, "" if belt.slots[i] == _sel else _sel)
	if belt.gadget() == "":
		belt.sel = i
	UIStyle.sfx("confirm")
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
