extends RadialWheel
## The quick-item key (E): a tap takes the selected food or drink (Player.use_quick); hold it and the
## wheel opens on every food and drink you carry (InventoryComponent.quick_choices), each with how many
## you have, and (1.31, Zach) the gadgets you carry: the belt's filled slots (GadgetBelt: one alone, more with a
## gadget belt or bag), none at the helm. Let go on a food and it's the selected one (the bar's E slot shows it);
## on a gadget and it's taken up for U (GadgetBelt.pick). The bag's flap is open while gadgets are on the wheel.
## Gadget entries are "g:<gadget id>" (item ids and gadget ids never mix).
const G := "g:"


func _init() -> void:
	action = "quick_item"
	title = "Provisions"
	tap_ok = true


func _belt() -> GadgetBelt:
	return player.gadgets


func _gadgets() -> Array:
	if player.gadgets == null or player.current_state_name() == "Helm":
		return []
	return _belt().slots.filter(func(g): return g != "").map(func(g): return G + str(g))


func _list() -> Array:
	return player.inventory_component.quick_choices().map(func(it: ItemData): return it.id) + _gadgets()


static func _gid(id) -> String:
	return str(id).trim_prefix(G) if str(id).begins_with(G) else ""


func _title() -> String:
	if entries.is_empty():
		return "Nothing to eat"
	return "Provisions & gadgets" if entries.any(func(e): return _gid(e) != "") else title


func _label(id) -> String:
	var g := _gid(id)
	return str(GadgetData.GADGETS[g]["name"]) if g != "" else ItemDB.get_item(id).display_name


func _sub(id) -> String:
	var g := _gid(id)
	if g == "":
		return "%d in your bag" % player.inventory_component.count(id)
	var b := _belt()
	var s: String = GadgetData.TIER_NAMES[b.tier_of(g)]
	if b.max_charges(g) > 0:
		s += "  %d / %d" % [b.charges(g), b.max_charges(g)]
	if b.cooldown_left(g) > 0.0:
		s += "  ready in %d s" % ceili(b.cooldown_left(g))
	return s


func _badge(id) -> String:
	var g := _gid(id)
	if g == "":
		return str(player.inventory_component.count(id))
	return str(_belt().charges(g)) if _belt().max_charges(g) > 0 else ""


func _icon(id) -> Texture2D:
	var g := _gid(id)
	return GadgetModels.icon(g, _belt().tier_of(g)) if g != "" else ItemDB.get_item(id).icon


func _dim(id) -> bool:
	var g := _gid(id)
	if g == "":
		return player.inventory_component.count(id) <= 0
	return _belt().max_charges(g) > 0 and _belt().charges(g) <= 0


func _current(id) -> bool:
	var g := _gid(id)
	return g == _belt().gadget() if g != "" else id == player.inventory_component.quick


func _do(id) -> void:
	var g := _gid(id)
	if g == "":
		player.inventory_component.select_quick(id)
		UIStyle.sfx("equip")
	elif g in _belt().slots:
		_belt().pick(_belt().slots.find(g))


func _tap() -> void:
	player.use_quick()


func _open_now() -> void:
	super()
	if is_open() and not _gadgets().is_empty():
		_belt().wheel_open = true
		_belt()._bag_look()


func _close() -> void:
	super()
	if player and player.gadgets and _belt().wheel_open:
		_belt().wheel_open = false
		_belt()._bag_look()
