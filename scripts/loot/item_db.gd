class_name ItemDB
extends RefCounted
## Looks up item definitions (res://resources/items/*.tres) by id.

const DIR := "res://resources/items/"

static var _items: Dictionary = {}


static func get_item(id: String) -> ItemData:
	if _items.is_empty():
		_load_all()
	if not _items.has(id) and id.contains("+"):
		return with_trait(id.get_slice("+", 0), id.get_slice("+", 1))
	if not _items.has(id) and id.contains("@"):
		return tiered(id.get_slice("@", 0), int(id.get_slice("@", 1)))
	return _items.get(id)


## A copy of weapon `base_id` (any tier: "<id>@<tier>") carrying a named trait (WeaponTraits):
## "<base_id>+<trait>", saved and sent by that id like any other item.
static func with_trait(base_id: String, trait_id: String) -> ItemData:
	var id := "%s+%s" % [base_id, trait_id]
	if _items.has(id):
		return _items[id]
	var base := get_item(base_id)
	var it := base.duplicate() as ItemData
	it.id = id
	it.weapon_trait = trait_id
	it.display_name = "%s %s" % [WeaponTraits.title(trait_id), base.display_name]
	if trait_id == "venomous":
		it.poison = maxf(it.poison, 3.0 * WeaponTraits.power(int(it.rarity)))
	return register(it)


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
	if it.is_weapon():
		it.icon = WeaponDesigns.icon(it.model())
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
	preload("res://scripts/game/dep_record.gd").note_dep(DIR)
	for file in ResourceLoader.list_directory(DIR):
		var f := file.trim_suffix(".remap")
		if not (f.ends_with(".tres") or f.ends_with(".res")):
			continue
		var item := load(DIR + f) as ItemData
		if item and item.id != "":
			_items[item.id] = item
	WeaponDesigns.make_items(_items)
	Instruments.make_items(_items)
	Food.make_items(_items)
	Rods.make_items(_items)
	FishTable.make_items(_items)
	Bait.make_items(_items)
