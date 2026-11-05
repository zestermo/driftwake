extends Node
class_name EquipmentComponent
## Worn gear by paper-doll slot (see Gear.SLOTS). The weapon stays on the
## Player (equipped_weapon); this holds clothing and armor.

signal equipment_changed

var slots: Dictionary = {}
## Equipment pieces (item ids) the captain keeps off the body: still carried and usable, just not drawn
## (the inventory's SHOW box by the equipment slot; it rides in the look, so crewmates see it the same).
var hidden: Dictionary = {}


## (1.29) Coats (item ids) worn draped over the shoulders, the sleeves empty (the wardrobe's DRAPE box under the coat
## slot; in the look as "coat_drape", so crewmates see it the same).
var draped: Dictionary = {}

## (1.30) Transmog: the clothing slots that can show a cosmetic piece instead of the worn one (the wardrobe's MOG boxes).
## The worn piece gives every stat; `cosmetic` (slot -> piece, out of the bag while it sits there) is what the body
## draws while that slot's `mog` is ticked. An empty cosmetic slot shows the worn piece.
const MOG_SLOTS := ["head", "face", "torso", "vest", "coat", "shoulders", "belt", "back", "strap", "hands", "legs", "feet"]
var cosmetic: Dictionary = {}
var mog: Dictionary = {}


func is_mogged(slot: String) -> bool:
	return mog.has(slot)


func set_mog(slot: String, on: bool) -> void:
	assert(slot in MOG_SLOTS, "no transmog for slot " + slot)
	if on == is_mogged(slot):
		return
	if on:
		mog[slot] = true
	else:
		mog.erase(slot)
	equipment_changed.emit()


func get_cosmetic(slot: String) -> ItemData:
	return cosmetic.get(slot)


func fits_cosmetic(item: ItemData, slot: String) -> bool:
	return item != null and slot in MOG_SLOTS and item.is_gear() and item.gear_slot == slot


## Put a piece in a slot's cosmetic place; returns whatever it replaced (or null).
func wear_cosmetic(item: ItemData, slot: String) -> ItemData:
	assert(fits_cosmetic(item, slot), "%s can't be worn for looks in %s" % [item.id if item else "null", slot])
	var prev: ItemData = cosmetic.get(slot)
	cosmetic[slot] = item
	equipment_changed.emit()
	return prev


func take_cosmetic(slot: String) -> ItemData:
	var prev: ItemData = cosmetic.get(slot)
	cosmetic.erase(slot)
	if prev:
		equipment_changed.emit()
	return prev


## The piece the body draws for a slot: the cosmetic one while mogged (and filled), the worn one otherwise.
func look_item(slot: String) -> ItemData:
	if is_mogged(slot) and cosmetic.get(slot) != null:
		return cosmetic[slot]
	return slots.get(slot)


## The worn slots with the mogged ones' cosmetic pieces in their place: what Gear.compose builds the look from.
func look_slots() -> Dictionary:
	var out := slots.duplicate()
	for slot in mog.keys():
		if cosmetic.get(slot) != null:
			out[slot] = cosmetic[slot]
	return out


## Move a bag piece into its slot's cosmetic place (whatever was there goes back to that bag position).
func mog_from_bag(inv: InventoryComponent, idx: int, slot: String = "") -> bool:
	if idx < 0 or idx >= inv.items.size():
		return false
	var it: ItemData = inv.items[idx].item
	if slot == "":
		slot = it.gear_slot if it.is_gear() else ""
	if not fits_cosmetic(it, slot):
		return false
	var shown := look_slots()
	shown[slot] = it
	if Gear.clash(shown, draped) != "":
		return false
	inv.take_at(idx)
	var prev := wear_cosmetic(it, slot)
	if prev:
		inv.insert_item(prev, idx)
	return true


## Take a slot's cosmetic piece back into the bag (if there's room).
func unmog_to_bag(inv: InventoryComponent, slot: String) -> bool:
	if cosmetic.get(slot) == null or not inv.has_room():
		return false
	inv.add_item(take_cosmetic(slot), 1)
	return true


func is_draped(item: ItemData) -> bool:
	return item != null and draped.has(item.id)


func set_draped(item: ItemData, on: bool) -> void:
	if on == is_draped(item):
		return
	if on:
		draped[item.id] = true
	else:
		draped.erase(item.id)
	equipment_changed.emit()


func is_hidden(item: ItemData) -> bool:
	return item != null and hidden.has(item.id)


func set_hidden(item: ItemData, on: bool) -> void:
	if on == is_hidden(item):
		return
	if on:
		hidden[item.id] = true
	else:
		hidden.erase(item.id)
	equipment_changed.emit()


func get_item(slot: String) -> ItemData:
	return slots.get(slot)


## Which slot an item goes into: its own kind, or the first free trinket slot.
func slot_for(item: ItemData) -> String:
	if item == null or not item.is_gear():
		return ""
	if item.gear_slot == "trinket":
		if slots.get("trinket1") == null:
			return "trinket1"
		if slots.get("trinket2") == null:
			return "trinket2"
		return "trinket1"
	return item.gear_slot


## (1.30.3) Why `item` can't go in `slot` (its own if "") beside what's worn, or "" when it can (Gear.BLOCKS). Judged on
## the worn pieces and on what's drawn (a mogged slot's cosmetic piece).
func clash(item: ItemData, slot: String = "", drape: Variant = null) -> String:
	if slot == "":
		slot = slot_for(item)
	var dr := draped.duplicate()
	if drape != null:
		var ct: ItemData = item if slot == "coat" and item != null else look_item("coat")
		if ct:
			if drape:
				dr[ct.id] = true
			else:
				dr.erase(ct.id)
	for base in [slots, look_slots()]:
		var trial: Dictionary = base.duplicate()
		if item:
			trial[slot] = item
		var why := Gear.clash(trial, dr)
		if why != "":
			return why
	return ""


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
	cosmetic.clear()
	mog.clear()
	equipment_changed.emit()


func defense() -> float:
	var d := 0.0
	for it in slots.values():
		if it:
			d += (it as ItemData).armor()
	return d
