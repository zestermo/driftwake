class_name ItemDB
extends RefCounted
## Looks up item definitions (res://resources/items/*.tres) by id.

const DIR := "res://resources/items/"

static var _items: Dictionary = {}


static func get_item(id: String) -> ItemData:
	if _items.is_empty():
		_load_all()
	if not _items.has(id) and id.contains("@"):
		return tiered(id.get_slice("@", 0), int(id.get_slice("@", 1)))
	return _items.get(id)


## A copy of item `base_id` at another tier ("<id>@<tier>": saved and sent
## by that id like any other item). The base's own tier gives the base.
static func tiered(base_id: String, tier: int) -> ItemData:
	var base := get_item(base_id)
	if int(base.rarity) == tier:
		return base
	var id := "%s@%d" % [base_id, tier]
	if _items.has(id):
		return _items[id]
	var it := base.duplicate() as ItemData
	it.id = id
	it.rarity = tier as ItemData.Rarity
	return register(it)


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
