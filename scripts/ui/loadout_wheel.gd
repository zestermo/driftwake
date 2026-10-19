extends RadialWheel
## The loadout key (X): a tap swaps to the next weapon setup (Player.swap_loadout); held, the wheel
## shows every slot (two, a third from the Captain tree's Quartermaster) with its style and weapons;
## let go on one to take it up. The slot in use is whatever you put in your hands (the bag, I).

const STYLES := preload("res://scripts/ui/inspect_panel.gd").STYLES


func _init() -> void:
	action = "loadout"
	title = "Loadouts"
	tap_ok = true


func _list() -> Array:
	return range(Player.LOADOUTS)


func _locked(i: int) -> bool:
	return i >= player.loadout_slots()


func _label(id) -> String:
	if _locked(id):
		return "Locked"
	var l: Array = player.loadouts[id]
	if l.is_empty():
		return "Empty"
	if l[0] == "":
		return "Fists"
	return STYLES[Player.style_of(ItemDB.get_item(l[0]), ItemDB.get_item(l[1]) if l[1] != "" else null)]


func _sub(id) -> String:
	if _locked(id):
		return "Captain tree: Quartermaster"
	var l: Array = player.loadouts[id]
	if l.is_empty():
		return "%d  set it up" % (id + 1)
	if l[0] == "":
		return str(id + 1)
	var main := ItemDB.get_item(l[0]).display_name
	if l[1] == "":
		return "%d  %s" % [id + 1, main]
	if l[1] == l[0]:
		return "%d  2x %s" % [id + 1, main]
	return "%d  %s + %s" % [id + 1, main, ItemDB.get_item(l[1]).display_name]


func _icon(id) -> Texture2D:
	if _locked(id):
		return null
	var l: Array = player.loadouts[id]
	return ItemDB.get_item(l[0]).icon if not l.is_empty() and l[0] != "" else null


func _dim(id) -> bool:
	return _locked(id) or not player.loadout_carried(id)


func _current(id) -> bool:
	return id == player.loadout_at


func _do(id) -> void:
	player.swap_loadout(id)


func _tap() -> void:
	player.swap_loadout((player.loadout_at + 1) % player.loadout_slots())
