extends Node
class_name EquipmentComponent
## Worn gear by paper-doll slot (see Gear.SLOTS). The weapon stays on the
## Player (equipped_weapon); this holds clothing and armor.

signal equipment_changed

var slots: Dictionary = {}


func get_item(slot: String) -> ItemData:
	return slots.get(slot)


## Which slot an item goes into: its own kind, or the first free accessory slot.
func slot_for(item: ItemData) -> String:
	if item == null or not item.is_gear():
		return ""
	if item.gear_slot == "accessory":
		if slots.get("acc1") == null:
			return "acc1"
		if slots.get("acc2") == null:
			return "acc2"
		return "acc1"
	return item.gear_slot


## Wear an item; returns whatever it replaced (or null).
func equip(item: ItemData, slot: String = "") -> ItemData:
	if slot == "":
		slot = slot_for(item)
	if slot == "":
		return null
	var prev: ItemData = slots.get(slot)
	slots[slot] = item
	equipment_changed.emit()
	return prev


func unequip(slot: String) -> ItemData:
	var prev: ItemData = slots.get(slot)
	slots.erase(slot)
	if prev:
		equipment_changed.emit()
	return prev


func clear() -> void:
	slots.clear()
	equipment_changed.emit()


func defense() -> float:
	var d := 0.0
	for it in slots.values():
		if it:
			d += (it as ItemData).armor()
	return d
