extends RadialWheel
## The gadget key (O, 1.28.1): a tap takes up the next gadget (GadgetBelt.cycle: at the helm the next ship gadget;
## without a bag it says a bag carries more); held with a gadget bag, the wheel shows every gadget in it with its tier
## and charges, and letting go on one takes it up. The bag's flap is open while the wheel is up.


func _init() -> void:
	action = "gadget_cycle"
	title = "Gadgets"
	tap_ok = true


func _belt() -> GadgetBelt:
	return player.gadgets


func _list() -> Array:
	return _belt().slots.filter(func(g): return g != "")


func _label(gid) -> String:
	return str(GadgetData.GADGETS[gid]["name"])


func _sub(gid) -> String:
	var b := _belt()
	var s: String = GadgetData.TIER_NAMES[b.tier_of(gid)]
	if b.max_charges(gid) > 0:
		s += "  %d / %d" % [b.charges(gid), b.max_charges(gid)]
	if b.cooldown_left(gid) > 0.0:
		s += "  ready in %d s" % ceili(b.cooldown_left(gid))
	return s


func _icon(gid) -> Texture2D:
	return GadgetModels.icon(gid, _belt().tier_of(gid))


func _badge(gid) -> String:
	return str(_belt().charges(gid)) if _belt().max_charges(gid) > 0 else ""


func _dim(gid) -> bool:
	return _belt().max_charges(gid) > 0 and _belt().charges(gid) <= 0


func _current(gid) -> bool:
	return gid == _belt().gadget()


func _do(gid) -> void:
	if gid in _belt().slots:
		_belt().pick(_belt().slots.find(gid))


func _tap() -> void:
	_belt().cycle()


## Held without a bag (or at the helm, or with one gadget in it): just the tap.
func _open_now() -> void:
	var b := _belt()
	if b.capacity() <= 1 or player.current_state_name() == "Helm" or _list().size() < 2:
		_down = false
		_tap()
		return
	super()
	b.wheel_open = true
	b._bag_look()


func _close() -> void:
	super()
	if player and player.gadgets:
		_belt().wheel_open = false
		_belt()._bag_look()
