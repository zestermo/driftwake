extends Node
class_name InventoryComponent

signal inventory_changed
signal item_added(item: ItemData, quantity: int)

@export var max_slots: int = 20
var items: Array[ItemStack] = []


func add_item(item_data: ItemData, quantity: int = 1) -> bool:
	if item_data.stackable:
		for stack in items:
			if stack.item == item_data and stack.quantity < item_data.max_stack:
				var can_add := mini(quantity, item_data.max_stack - stack.quantity)
				stack.quantity += can_add
				quantity -= can_add
				if quantity <= 0:
					item_added.emit(item_data, can_add)
					inventory_changed.emit()
					return true

	if items.size() < max_slots and quantity > 0:
		var stack := ItemStack.new()
		stack.item = item_data
		stack.quantity = quantity
		items.append(stack)
		item_added.emit(item_data, quantity)
		inventory_changed.emit()
		return true
	return false


func get_total_items() -> int:
	var total := 0
	for stack in items:
		total += stack.quantity
	return total


func get_all_items() -> Array[ItemStack]:
	return items.duplicate()


func clear() -> void:
	items.clear()
	inventory_changed.emit()
