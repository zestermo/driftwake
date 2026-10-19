extends Control
## A trader's stall (GameMenu screen "shop", open_shop): their stock on the left with prices, your
## bag in the middle (what they'd buy lit, the rest dimmed, with what they'd pay), the picked item's
## card with Buy / Sell on the right. Hover anything for its tooltip, compared with what you hold or
## wear. Right-click buys or sells one at once. Gold is the gold in your bag.

const SHOPS := preload("res://scripts/game/shops.gd")
const SLOT := InventoryScreen.SLOT
const GAP := InventoryScreen.GAP
const COLS := 5
const ROWS := 5
const INFO_W := 142
const TIP_W := 150
const KIND_NAMES := {"loot": "treasure", "weapon": "weapons", "consumable": "food and drink", "gear": "clothes and armour", "ingredient": "ingredients"}

var shop_id: String = ""
var _menu: Node
var _panel: PanelContainer
var _title: Label
var _line: Label
var _gold: Label
var _stock_grid: GridContainer
var _bag_grid: GridContainer
var _buy_note: Label
var _stock: Array = []  # [stock entry, item] per stock slot; the buy-back row after: [[], item, each, count]
## The first buy-back slot (Shops.sold_back) in _stock.
var _back_at := 0
var _stock_slots: Array = []
var _bag_slots: Array = []
var _view: Array[int] = []
var _card: VBoxContainer
var _price: Label
var _buy_btn: Button
var _sell_btn: Button
var _all_btn: Button
var _hints: HBoxContainer
var _tip: PanelContainer
var _tip_box: VBoxContainer
var _hover = null
var _tip_t := 0.0
var _flash_t := 0.0
## What the card shows: {"src": "shop" | "bag", "i": slot}, or {}.
var _sel := {}


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
	_title = UIStyle.title("")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(_title)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	var coin := TextureRect.new()
	coin.texture = load("res://assets/textures/icons/gold.png")
	coin.custom_minimum_size = Vector2(16, 16)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(coin)
	_gold = InventoryScreen._text("", UIStyle.ACCENT, InventoryScreen.BOLD)
	_gold.add_theme_font_size_override("font_size", 16)
	_gold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_gold)
	_line = InventoryScreen._text("", UIStyle.TEXT_DIM)
	vb.add_child(_line)
	vb.add_child(InventoryScreen._rule())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	vb.add_child(body)
	var c1 := VBoxContainer.new()
	c1.add_theme_constant_override("separation", 3)
	body.add_child(c1)
	c1.add_child(InventoryScreen.small("FOR SALE", UIStyle.BORDER))
	_stock_grid = _grid(c1)
	var c2 := VBoxContainer.new()
	c2.add_theme_constant_override("separation", 3)
	body.add_child(c2)
	c2.add_child(InventoryScreen.small("YOUR BAG", UIStyle.BORDER))
	_bag_grid = _grid(c2)
	_buy_note = InventoryScreen.small("", UIStyle.TEXT_DIM)
	_buy_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buy_note.custom_minimum_size = Vector2(COLS * (SLOT + GAP) + 6, 0)
	c2.add_child(_buy_note)
	var c3 := VBoxContainer.new()
	c3.custom_minimum_size = Vector2(INFO_W, 0)
	c3.add_theme_constant_override("separation", 3)
	body.add_child(c3)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 2)
	_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c3.add_child(_card)
	_price = InventoryScreen.small("", UIStyle.ACCENT)
	_price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_price.custom_minimum_size = Vector2(INFO_W, 0)
	c3.add_child(_price)
	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 4)
	c3.add_child(act)
	_buy_btn = UIStyle.button("Buy", 60)
	_buy_btn.pressed.connect(func(): _act(false))
	_sell_btn = UIStyle.button("Sell", 52)
	_sell_btn.pressed.connect(func(): _act(false))
	_all_btn = UIStyle.button("Sell all", 66)
	_all_btn.pressed.connect(func(): _act(true))
	for b in [_buy_btn, _sell_btn, _all_btn]:
		act.add_child(b)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	vb.add_child(foot)
	_hints = HBoxContainer.new()
	_hints.add_theme_constant_override("separation", 10)
	_hints.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hints.alignment = BoxContainer.ALIGNMENT_BEGIN
	foot.add_child(_hints)
	var leave := UIStyle.button("Leave", 80)
	leave.pressed.connect(func(): _menu.close())
	foot.add_child(leave)

	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip_box = VBoxContainer.new()
	_tip_box.add_theme_constant_override("separation", 2)
	_tip.add_child(_tip_box)
	add_child(_tip)


## A scrolling grid of COLS x ROWS slots.
func _grid(parent: Control) -> GridContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(COLS * (SLOT + GAP) + 6, ROWS * (SLOT + GAP) - GAP)
	parent.add_child(sc)
	var g := GridContainer.new()
	g.columns = COLS
	g.add_theme_constant_override("h_separation", GAP)
	g.add_theme_constant_override("v_separation", GAP)
	sc.add_child(g)
	return g


func _slot(src: String, i: int):
	var s := InventoryScreen.Slot.new("", {"src": src, "i": i})
	s.mouse_entered.connect(func():
		_hover = s
		_tip_t = 0.0
		_tip.visible = false)
	s.mouse_exited.connect(func():
		if _hover == s:
			_hover = null
			_tip.visible = false)
	s.focus_entered.connect(func(): _pick(src, i))
	s.pressed.connect(func(): quick_act(src, i, Input.is_key_pressed(KEY_SHIFT)))
	s.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			_pick(src, i)
			_act(false))
	return s


func open_shop(id: String) -> void:
	shop_id = id
	_sel = {}
	_refresh()


func on_open() -> void:
	_flash_t = 0.0
	_hover = null
	_tip.visible = false
	_refresh()
	_set_hints()
	if not _stock_slots.is_empty():
		(_stock_slots[0] as Control).call_deferred("grab_focus")


func _player() -> Player:
	return _menu.call("_player")


func gold() -> int:
	return _player().inventory_component.count("gold")


func _refresh() -> void:
	var shop: Dictionary = SHOPS.shop(shop_id)
	var inv := _player().inventory_component
	var off := Journal.discount(shop_id)
	_title.text = str(shop["name"]) + ("  -%d%% crew" % roundi(off * 100.0) if off > 0.0 else "")
	_line.text = str(shop["line"])
	_gold.text = str(gold())
	var kinds: Array = []
	for k in (shop["buys"] as Dictionary).keys():
		kinds.append(KIND_NAMES[k])
	_buy_note.text = ("BUYS " + ", ".join(kinds)).to_upper() if not kinds.is_empty() else "BUYS NOTHING"
	_buy_note.add_theme_color_override("font_color", UIStyle.TEXT_DIM if not kinds.is_empty() else UIStyle.DANGER_TEXT)
	_stock.clear()
	for e in SHOPS.stock(shop_id):
		_stock.append([e, SHOPS.item_of(e)])
	_back_at = _stock.size()
	for b in SHOPS.sold_back(shop_id):
		_stock.append([[], b[0], int(b[2]), int(b[1])])
	while _stock_slots.size() < _stock.size():
		var s = _slot("shop", _stock_slots.size())
		_stock_grid.add_child(s)
		_stock_slots.append(s)
	for i in range(_stock_slots.size()):
		var s = _stock_slots[i]
		s.visible = i < _stock.size()
		s.modulate = Color.WHITE
		if i < _stock.size():
			var price := price_at(i)
			s.show_item(_stock[i][1], 1)
			s.count.text = str(price)
			s.count.add_theme_color_override("font_color", UIStyle.ACCENT if gold() >= price else UIStyle.DANGER_TEXT)
			if i >= _back_at:
				# (the buy-back row: what you just sold them, tinted)
				s.modulate = Color(0.75, 0.9, 1.0)
	_view = inv.bag_view()
	var cells := maxi(ceili(_view.size() / float(COLS)) * COLS, ROWS * COLS)
	while _bag_slots.size() < cells:
		var s = _slot("bag", _bag_slots.size())
		_bag_grid.add_child(s)
		_bag_slots.append(s)
	for i in range(_bag_slots.size()):
		var s = _bag_slots[i]
		s.visible = i < cells
		if i < _view.size():
			var st := inv.items[_view[i]]
			s.show_item(st.item, st.quantity)
			s.count.remove_theme_color_override("font_color")
			if SHOPS.offer(shop_id, st.item) <= 0:
				s.tex.modulate.a = 0.3
		else:
			s.show_item(null, 0)
	_show_card()


func _item_of(src: String, i: int) -> ItemData:
	if src == "shop":
		return _stock[i][1] if i < _stock.size() else null
	var inv := _player().inventory_component
	return inv.items[_view[i]].item if i < _view.size() else null


func _pick(src: String, i: int) -> void:
	if _item_of(src, i) == null:
		return
	_sel = {"src": src, "i": i}
	_show_card()


## A click; with shift on a bag stack, sell it whole.
func quick_act(src: String, i: int, shift: bool) -> void:
	_pick(src, i)
	if shift and src == "bag" and not _sel.is_empty():
		_act(true)


## The card: the item, then what it costs or what they'd pay, and the buttons for it.
func _show_card() -> void:
	var it := _item_of(str(_sel["src"]), int(_sel["i"])) if not _sel.is_empty() else null
	for b in [_buy_btn, _sell_btn, _all_btn]:
		b.visible = false
	if it == null:
		_sel = {}
		InventoryScreen._clear(_card)
		_card.add_child(InventoryScreen.small("PICK SOMETHING TO SEE IT HERE", UIStyle.TEXT_DIM))
		_price.text = ""
		return
	var pl := _player()
	var src := str(_sel["src"])
	if src == "shop":
		var price := price_at(int(_sel["i"]))
		InventoryScreen.fill_info(_card, it, 1, "shop", INFO_W, pl)
		_price.text = ("BUY BACK %d G" if int(_sel["i"]) >= _back_at else "PRICE %d G") % price
		_price.add_theme_color_override("font_color", UIStyle.ACCENT if gold() >= price else UIStyle.DANGER_TEXT)
		_buy_btn.visible = true
		_buy_btn.disabled = gold() < price or pl.inventory_component.room_for(it) <= 0
		return
	var n := _count(it)
	InventoryScreen.fill_info(_card, it, n, "bag", INFO_W, pl)
	var each := SHOPS.offer(shop_id, it)
	if each <= 0:
		_price.text = "THEY WON'T BUY THIS"
		_price.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
		return
	_price.text = "THEY PAY %d G" % each + ("  (ALL %d G)" % (each * n) if n > 1 else "")
	_price.add_theme_color_override("font_color", UIStyle.ACCENT)
	_sell_btn.visible = true
	_all_btn.visible = n > 1


func _count(it: ItemData) -> int:
	return _player().inventory_component.count(it.id) if it.stackable else 1


## Buy or sell (all of it) what the card shows.
func _act(all: bool) -> void:
	if _sel.is_empty():
		return
	var it := _item_of(str(_sel["src"]), int(_sel["i"]))
	if it == null:
		return
	if str(_sel["src"]) == "shop" and int(_sel["i"]) >= _back_at:
		buy_back(int(_sel["i"]) - _back_at)
	elif str(_sel["src"]) == "shop":
		buy(_stock[int(_sel["i"])][0])
	else:
		sell(it, _count(it) if all else 1)


## What stock slot `i` costs: on the curve, or (the buy-back row) what they paid you.
func price_at(i: int) -> int:
	return int(_stock[i][2]) if i >= _back_at else crew_price(_stock[i][0])


## On the curve, less the crew's discount here (a quest's reward: Journal.perks).
func crew_price(entry: Array) -> int:
	return roundi(SHOPS.price_of(entry) * (1.0 - Journal.discount(shop_id)))


## The stock slot of buy-back entry `k`.
func back_slot(k: int) -> int:
	return _back_at + k


## Buy back one of what you sold them (buy-back entry `k`) at what they paid.
func buy_back(k: int) -> void:
	var i := _back_at + k
	var price := price_at(i)
	var it: ItemData = _stock[i][1]
	var inv = _player().inventory_component
	if gold() < price:
		_flash("Not enough gold", true)
		return
	if not inv.add_item(it, 1):
		_flash("Your bag's full", true)
		return
	inv.remove_item(ItemDB.get_item("gold"), price)
	SHOPS.took_back(shop_id, k)
	UIStyle.sfx("buy")
	_flash("Bought back %s for %d gold" % [it.display_name, price], false)
	_refresh()
	_bounce(it)


func buy(entry: Array) -> void:
	var price := crew_price(entry)
	var inv = _player().inventory_component
	if gold() < price:
		_flash("Not enough gold", true)
		return
	var it := SHOPS.item_of(entry)
	if not inv.add_item(it, 1):
		_flash("Your bag's full", true)
		return
	inv.remove_item(ItemDB.get_item("gold"), price)
	UIStyle.sfx("buy")
	_flash("Bought %s for %d gold" % [it.display_name, price], false)
	_refresh()
	_bounce(it)


func sell(it: ItemData, n: int) -> void:
	var inv = _player().inventory_component
	var each := SHOPS.offer(shop_id, it)
	if each <= 0:
		_flash("They won't buy that", true)
		return
	if not inv.remove_item(it, n):
		return
	inv.add_item(ItemDB.get_item("gold"), each * n)
	SHOPS.note_sold(shop_id, it, n, each)
	UIStyle.sfx("sell")
	_flash("Sold %s%s for %d gold" % [it.display_name, " x%d" % n if n > 1 else "", each * n], false)
	_refresh()
	_gold.pivot_offset = _gold.size * 0.5
	_gold.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(_gold, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The bag slot that got it pops.
func _bounce(it: ItemData) -> void:
	for s in _bag_slots:
		if s.visible and s.item and s.item.id == it.id:
			s.bounce()
			return


func _set_hints() -> void:
	InventoryScreen._clear(_hints)
	for p in [["LMB", "PICK"], ["RMB", "BUY / SELL ONE"], ["SHIFT", "SELL ALL"], ["ESC", "LEAVE"]]:
		_hints.add_child(UIStyle.key_hint(p[0], p[1]))


## A note in place of the hints for a moment (what happened, or why not).
func _flash(text: String, bad: bool) -> void:
	InventoryScreen._clear(_hints)
	var l := InventoryScreen.small(text.to_upper(), UIStyle.DANGER_TEXT if bad else UIStyle.GOOD)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hints.add_child(l)
	_flash_t = 2.5
	if bad:
		UIStyle.sfx("deny")


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_set_hints()
	var it: ItemData = _item_of(str(_hover.data["src"]), int(_hover.data["i"])) if _hover else null
	if it == null:
		_tip.visible = false
		return
	_tip_t += delta
	if _tip_t < 0.15:
		return
	if not _tip.visible:
		var src := str(_hover.data["src"])
		InventoryScreen.fill_info(_tip_box, it, 1 if src == "shop" else _count(it), src, TIP_W, _player())
		var border := it.rarity_color() if it.rarity != ItemData.Rarity.SUPREME else Color(0.85, 0.85, 0.8)
		_tip.add_theme_stylebox_override("panel", UIStyle.frame(UIStyle.BG_DARK, border, 5, "plank"))
		_tip.visible = true
	_tip.size = Vector2.ZERO
	var sz := _tip.get_combined_minimum_size()
	var m := get_local_mouse_position()
	var p := m + Vector2(12, 10)
	if p.x + sz.x > size.x - 4:
		p.x = m.x - sz.x - 10
	p.y = clampf(p.y - 20, 4, size.y - sz.y - 4)
	_tip.position = p.round()
