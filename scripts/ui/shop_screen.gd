extends PanelContainer
## A trader's stall (GameMenu screen "shop", ShopScreen.open_shop): what they
## sell on the left, what of yours they'll buy on the right. Gold is the gold
## in your bag. Hover a row for the item's description.

const SHOPS := preload("res://scripts/game/shops.gd")

var shop_id: String = ""
var _menu: Node
var _title: Label
var _line: Label
var _gold: Label
var _sell_list: VBoxContainer
var _buy_list: VBoxContainer
var _note: Label
var _coin: AudioStreamPlayer


func _init(menu: Node) -> void:
	_menu = menu
	# (the game's paused in here: a plain player, not a positional FX sound)
	_coin = AudioStreamPlayer.new()
	_coin.stream = load("res://assets/audio/coin.wav")
	_coin.bus = "UI"
	_coin.volume_db = -6.0
	add_child(_coin)
	custom_minimum_size = Vector2(560, 290)
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 10, 2))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)
	var top := HBoxContainer.new()
	_title = UIStyle.title("")
	top.add_child(_title)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	_gold = UIStyle.label("", 12, UIStyle.ACCENT)
	top.add_child(_gold)
	vb.add_child(top)
	_line = UIStyle.label("", 8, UIStyle.TEXT_DIM)
	vb.add_child(_line)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)
	_sell_list = _column(cols, "For sale")
	_buy_list = _column(cols, "They'll buy")
	_note = UIStyle.label("", 8, UIStyle.TEXT_DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.custom_minimum_size = Vector2(530, 20)
	vb.add_child(_note)
	var done := UIStyle.button("Leave", 120)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func(): _menu.close())
	vb.add_child(done)


func _column(parent: Control, heading: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIStyle.label(heading, 14, UIStyle.ACCENT))
	col.add_child(HSeparator.new())
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(260, 170)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	sc.add_child(list)
	parent.add_child(col)
	return list


func open_shop(id: String) -> void:
	shop_id = id
	_note.text = ""
	_refresh()


func on_open() -> void:
	_refresh()
	for c in find_children("*", "Button", true, false):
		if not (c as Button).disabled:
			(c as Button).call_deferred("grab_focus")
			return


func _player() -> Node:
	return _menu.call("_player")


func gold() -> int:
	return _player().inventory_component.count("gold")


func _refresh() -> void:
	var shop: Dictionary = SHOPS.shop(shop_id)
	_title.text = str(shop["name"])
	_line.text = str(shop["line"])
	_gold.text = "%d gold" % gold()
	for c in _sell_list.get_children() + _buy_list.get_children():
		c.queue_free()
	for e in shop["stock"]:
		var entry: Array = e
		var it := SHOPS.item_of(entry)
		var price := SHOPS.price_of(entry)
		var row := _row(_sell_list, it, it.display_name, "%d g" % price)
		var b := UIStyle.button("Buy", 44)
		b.disabled = gold() < price
		b.pressed.connect(func(): buy(entry))
		row.add_child(b)
	# what of ours they'd take (one row per kind of item)
	var seen := {}
	for st in _player().inventory_component.items:
		var it: ItemData = st.item
		var each := SHOPS.offer(shop_id, it)
		if each <= 0 or seen.has(it):
			continue
		seen[it] = true
		var n: int = _player().inventory_component.count(it.id) if it.stackable else 1
		var row := _row(_buy_list, it, "%s x%d" % [it.display_name, n] if n > 1 else it.display_name, "%d g" % each)
		var b := UIStyle.button("Sell", 40)
		b.pressed.connect(func(): sell(it, 1))
		row.add_child(b)
		if n > 1:
			var all := UIStyle.button("All", 34)
			all.pressed.connect(func(): sell(it, n))
			row.add_child(all)
	if seen.is_empty():
		_buy_list.add_child(UIStyle.label("Nothing they want." if not (shop["buys"] as Dictionary).is_empty() else "They don't buy.", 8, UIStyle.TEXT_DIM))


func _row(list: VBoxContainer, it: ItemData, text: String, price: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var icon := TextureRect.new()
	icon.texture = it.icon
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var name_l := UIStyle.label(text, 12, it.rarity_color())
	name_l.add_theme_color_override("font_outline_color", it.rarity_outline())
	name_l.add_theme_constant_override("outline_size", 3)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	name_l.mouse_filter = Control.MOUSE_FILTER_STOP
	name_l.mouse_entered.connect(func(): _note.text = "%s. %s" % [it.rarity_name(), it.description])
	row.add_child(name_l)
	row.add_child(UIStyle.label(price, 12, UIStyle.ACCENT))
	list.add_child(row)
	return row


func buy(entry: Array) -> void:
	var price := SHOPS.price_of(entry)
	var inv = _player().inventory_component
	if gold() < price:
		_note.text = "Not enough gold."
		return
	var it := SHOPS.item_of(entry)
	if not inv.add_item(it, 1):
		_note.text = "Your bag's full."
		return
	inv.remove_item(ItemDB.get_item("gold"), price)
	_coin.play()
	_note.text = "Bought %s for %d gold." % [it.display_name, price]
	_refresh()


func sell(it: ItemData, n: int) -> void:
	var inv = _player().inventory_component
	var each := SHOPS.offer(shop_id, it)
	if each <= 0 or not inv.remove_item(it, n):
		return
	inv.add_item(ItemDB.get_item("gold"), each * n)
	_coin.play()
	_note.text = "Sold %s%s for %d gold." % [it.display_name, " x%d" % n if n > 1 else "", each * n]
	_refresh()
