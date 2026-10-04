class_name ItemDB
extends RefCounted
## Looks up item definitions (res://resources/items/*.tres) by id.

const DIR := "res://resources/items/"

static var _items: Dictionary = {}


static func get_item(id: String) -> ItemData:
	if _items.is_empty():
		_load_all()
	return _items.get(id)


## Add an item made at runtime (generated gear) so lookups by id find it.
static func register(item: ItemData) -> ItemData:
	if _items.is_empty():
		_load_all()
	if _items.has(item.id):
		return _items[item.id]
	_items[item.id] = item
	return item


static func _load_all() -> void:
	for file in ResourceLoader.list_directory(DIR):
		var f := file.trim_suffix(".remap")
		if not (f.ends_with(".tres") or f.ends_with(".res")):
			continue
		var item := load(DIR + f) as ItemData
		if item and item.id != "":
			_items[item.id] = item
