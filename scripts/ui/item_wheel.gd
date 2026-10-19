extends RadialWheel
## The quick-item key (E): a tap takes the selected food or drink (Player.use_quick); hold it and the
## wheel opens on every food and drink you carry (InventoryComponent.quick_choices), each with how many
## you have; let go on one and it's the selected one (the bar's E slot shows it).


func _init() -> void:
	action = "quick_item"
	title = "Provisions"
	tap_ok = true


func _list() -> Array:
	return player.inventory_component.quick_choices().map(func(it: ItemData): return it.id)


func _title() -> String:
	return title if not entries.is_empty() else "Nothing to eat"


func _label(id) -> String:
	return ItemDB.get_item(id).display_name


func _sub(id) -> String:
	return "x%d" % player.inventory_component.count(id)


func _icon(id) -> Texture2D:
	return ItemDB.get_item(id).icon


func _dim(id) -> bool:
	return player.inventory_component.count(id) <= 0


func _current(id) -> bool:
	return id == player.inventory_component.quick


func _do(id) -> void:
	player.inventory_component.select_quick(id)
	UIStyle.sfx("equip")


func _tap() -> void:
	player.use_quick()
