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
	custom_minimum_size = Vector2(540, 0)
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 10, 2))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)
	var top := HBoxContainer.new()
	top.add_child(UIStyle.title("Tackett's Yard"))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	_gold = UIStyle.label("", 12, UIStyle.ACCENT)
	top.add_child(_gold)
	vb.add_child(top)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	vb.add_child(cols)
	# refits
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	left.custom_minimum_size = Vector2(250, 0)
	cols.add_child(left)
	left.add_child(UIStyle.label("Refits", 14, UIStyle.ACCENT))
	left.add_child(HSeparator.new())
	for r in ShipKit.REFITS:
		var row := HBoxContainer.new()
		var txt := VBoxContainer.new()
		txt.add_theme_constant_override("separation", 0)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_child(UIStyle.label(r[1], 12))
		txt.add_child(UIStyle.label(r[2], 8, UIStyle.TEXT_DIM))
		row.add_child(txt)
		var b := UIStyle.button("", 64)
		var id: String = r[0]
		b.pressed.connect(func(): buy(id))
		row.add_child(b)
		_buy[id] = b
		left.add_child(row)
	# looks
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	cols.add_child(right)
	right.add_child(UIStyle.label("Paint & colours", 14, UIStyle.ACCENT))
	right.add_child(HSeparator.new())
	for l in LOOKS:
		var row := HBoxContainer.new()
		var name_l := UIStyle.label(l[1], 12)
		name_l.custom_minimum_size = Vector2(92, 0)
		row.add_child(name_l)
		var b := UIStyle.button("", 150)
		var key: String = l[0]
		b.pressed.connect(func(): cycle(key))
		row.add_child(b)
		_cycles.append([key, b, l[2]])
		right.add_child(row)
	_flag = TextureRect.new()
	_flag.custom_minimum_size = Vector2(ShipKit.FLAG_W * 2, ShipKit.FLAG_H * 2)
	_flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flag.stretch_mode = TextureRect.STRETCH_SCALE
	_flag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(_flag)
	# the foot
	_note = UIStyle.label("", 8, UIStyle.TEXT_DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.custom_minimum_size = Vector2(500, 0)
	vb.add_child(_note)
	var done := UIStyle.button("Done", 120)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func(): _menu.close())
	vb.add_child(done)


func on_open() -> void:
	_note.text = "This is the host's ship: only they can order work on her." if Net.is_client() \
		else "Refits are for good. Paint and colours are free: change them whenever you like."
	_refresh()
	for c in find_children("*", "Button", true, false):
		if not (c as Button).disabled:
			(c as Button).call_deferred("grab_focus")
			return


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
		FX.sfx("blip_low", Vector3.ZERO, -6.0)
		return
	var p = _menu.call("_player")
	p.inventory_component.remove_item(ItemDB.get_item("gold"), cost)
	kit[id] = true
	Net.set_ship_kit(kit)
	SaveGame.save(p)
	_note.text = "%s: done. She'll thank you for it." % r[1]
	_menu.call("_play")
	_refresh()


func cycle(key: String) -> void:
	if Net.is_client():
		return
	var kit := _kit()
	for c in _cycles:
		if c[0] == key:
			kit[key] = (int(kit[key]) + 1) % (c[2] as Array).size()
	Net.set_ship_kit(kit)
	_menu.call("_play")
	_refresh()
