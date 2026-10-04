extends Node
class_name InventoryComponent
## Carried items plus a 5-slot hotbar. Hotbar slots store item ids, so a slot
## remembers its item even when the stack runs out (e.g. you drank all the rum).

signal inventory_changed
signal item_added(item: ItemData, quantity: int)
signal hotbar_changed

const HOTBAR_SIZE := 5

@export var max_slots: int = 20
var items: Array[ItemStack] = []
var hotbar: Array[String] = ["", "", "", "", ""]


func add_item(item_data: ItemData, quantity: int = 1) -> bool:
	if item_data == null or quantity <= 0:
		return false
	var added := 0
	if item_data.stackable:
		for stack in items:
			if stack.item == item_data and stack.quantity < item_data.max_stack:
				var can_add := mini(quantity, item_data.max_stack - stack.quantity)
				stack.quantity += can_add
				quantity -= can_add
				added += can_add
				if quantity <= 0:
					break
	while quantity > 0 and items.size() < max_slots:
		var stack := ItemStack.new()
		stack.item = item_data
		stack.quantity = mini(quantity, item_data.max_stack if item_data.stackable else 1)
		quantity -= stack.quantity
		added += stack.quantity
		items.append(stack)
	if added > 0:
		_auto_assign(item_data)
		item_added.emit(item_data, added)
		inventory_changed.emit()
	return quantity <= 0


## Remove `quantity` of an item. Returns false if there wasn't enough.
func remove_item(item_data: ItemData, quantity: int = 1) -> bool:
	if count(item_data.id) < quantity:
		return false
	for i in range(items.size() - 1, -1, -1):
		if quantity <= 0:
			break
		var stack := items[i]
		if stack.item != item_data:
			continue
		var take := mini(quantity, stack.quantity)
		stack.quantity -= take
		quantity -= take
		if stack.quantity <= 0:
			items.remove_at(i)
	inventory_changed.emit()
	return true


## Room for one more (non-stacking) item?
func has_room() -> bool:
	return items.size() < max_slots


## Put a single item into a specific bag position (gear swapping in place).
func insert_item(item_data: ItemData, at: int) -> void:
	var stack := ItemStack.new()
	stack.item = item_data
	stack.quantity = 1
	items.insert(clampi(at, 0, items.size()), stack)
	inventory_changed.emit()


## Take the stack at a bag position out entirely.
func take_at(idx: int) -> ItemStack:
	if idx < 0 or idx >= items.size():
		return null
	var st := items[idx]
	items.remove_at(idx)
	inventory_changed.emit()
	return st


func count(item_id: String) -> int:
	var total := 0
	for stack in items:
		if stack.item and stack.item.id == item_id:
			total += stack.quantity
	return total


func has_item(item_id: String) -> bool:
	return count(item_id) > 0


func find_item(item_id: String) -> ItemData:
	for stack in items:
		if stack.item and stack.item.id == item_id:
			return stack.item
	return ItemDB.get_item(item_id)


func get_total_items() -> int:
	var total := 0
	for stack in items:
		total += stack.quantity
	return total


## Total quantity of loot (gold/treasure) carried — what you risk on death.
func get_loot_count() -> int:
	var total := 0
	for stack in items:
		if stack.item and stack.item.is_loot():
			total += stack.quantity
	return total


func get_all_items() -> Array[ItemStack]:
	return items.duplicate()


## Remove and return all loot stacks (for banking or dropping on death).
func take_loot() -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for i in range(items.size() - 1, -1, -1):
		if items[i].item and items[i].item.is_loot():
			out.append(items[i])
			items.remove_at(i)
	if not out.is_empty():
		inventory_changed.emit()
	return out


func clear() -> void:
	items.clear()
	inventory_changed.emit()


# ---- Hotbar ----
func assign_hotbar(slot: int, item_id: String) -> void:
	if slot < 0 or slot >= HOTBAR_SIZE:
		return
	# an item lives in one slot only
	for i in range(HOTBAR_SIZE):
		if hotbar[i] == item_id:
			hotbar[i] = ""
	hotbar[slot] = item_id
	hotbar_changed.emit()


func clear_hotbar_slot(slot: int) -> void:
	if slot >= 0 and slot < HOTBAR_SIZE:
		hotbar[slot] = ""
		hotbar_changed.emit()


func get_hotbar_item(slot: int) -> ItemData:
	if slot < 0 or slot >= HOTBAR_SIZE or hotbar[slot] == "":
		return null
	return find_item(hotbar[slot])


func _auto_assign(item_data: ItemData) -> void:
	if item_data.is_loot() or item_data.is_gear() or hotbar.has(item_data.id):
		return
	for i in range(HOTBAR_SIZE):
		if hotbar[i] == "":
			hotbar[i] = item_data.id
			hotbar_changed.emit()
			return
