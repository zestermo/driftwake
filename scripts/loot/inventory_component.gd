extends Node
class_name InventoryComponent
## Carried items, and the selected quick item: the food or drink the quick-item key (E) takes.
## A tap of E takes it (Player.use_quick); holding E opens the item wheel of every food and drink
## you carry (quick_choices) to pick another (select_quick). The selection is an item id: it fills
## itself with the first consumable you pick up, moves on to the next food you carry when its stack
## runs out, and is remembered when you've none left at all (it lights up again when you find more).
## Weapons are equipped from the inventory, not from here.

signal inventory_changed
signal item_added(item: ItemData, quantity: int)
signal quick_changed

@export var max_slots: int = 20
## Bag slots the crew's ship's hold adds (Ship.apply_kit: the ship this machine sees).
static var bonus_slots: int = 0
var items: Array[ItemStack] = []
## The selected quick item's id ("" = none).
var quick: String = ""
## The weapons in your hands (Player keeps it). Those stacks and the selected quick item's
## stay in `items` but live in their slots: off the bag grid and taking no bag space.
var in_hands: Array[ItemData] = []


## Is the stack at each bag position held (a hand or the quick item)?
func held_mask() -> Array[bool]:
	var hands: Array[String] = []
	for w in in_hands:
		hands.append(w.id)
	var out: Array[bool] = []
	for st in items:
		var h := quick != "" and st.item.id == quick
		if not h and hands.has(st.item.id):
			hands.erase(st.item.id)
			h = true
		out.append(h)
	return out


## The bag positions shown in the bag grid, in order.
func bag_view() -> Array[int]:
	var out: Array[int] = []
	var mask := held_mask()
	for i in range(items.size()):
		if not mask[i]:
			out.append(i)
	return out


func used_slots() -> int:
	return held_mask().count(false)


## How many stacks the bag holds.
func slots() -> int:
	return max_slots + bonus_slots


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
	while quantity > 0 and used_slots() < slots():
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
	_quick_ran_out()
	inventory_changed.emit()
	return true


## Room for one more (non-stacking) item?
func has_room() -> bool:
	return used_slots() < slots()


## Put a single item into a specific bag position (gear swapping in place).
func insert_item(item_data: ItemData, at: int) -> void:
	var stack := ItemStack.new()
	stack.item = item_data
	stack.quantity = 1
	items.insert(clampi(at, 0, items.size()), stack)
	inventory_changed.emit()


## Drag and drop: move the stack at `from` onto bag position `to`. The same
## item merges (as far as the stack allows), anything else swaps places;
## past the last stack = to the end.
func move_stack(from: int, to: int) -> void:
	if from < 0 or from >= items.size() or from == to:
		return
	if to >= items.size():
		var st := items[from]
		items.remove_at(from)
		items.append(st)
		inventory_changed.emit()
		return
	var a := items[from]
	var b := items[to]
	if a.item == b.item and a.item.stackable and b.quantity < a.item.max_stack:
		var moved := mini(a.quantity, a.item.max_stack - b.quantity)
		b.quantity += moved
		a.quantity -= moved
		if a.quantity <= 0:
			items.remove_at(from)
	else:
		items[from] = b
		items[to] = a
	inventory_changed.emit()


## Take `qty` from the stack at a bag position (all of it with qty < 0).
func take_amount(idx: int, qty: int = -1) -> ItemStack:
	if idx < 0 or idx >= items.size():
		return null
	var st := items[idx]
	if qty < 0 or qty >= st.quantity:
		return take_at(idx)
	st.quantity -= qty
	var out := ItemStack.new()
	out.item = st.item
	out.quantity = qty
	inventory_changed.emit()
	return out


## How many of an item would fit right now.
func room_for(item_data: ItemData) -> int:
	var n := 0
	if item_data.stackable:
		for stack in items:
			if stack.item == item_data:
				n += maxi(item_data.max_stack - stack.quantity, 0)
	n += maxi(slots() - used_slots(), 0) * (item_data.max_stack if item_data.stackable else 1)
	return n


## Take the stack at a bag position out entirely.
func take_at(idx: int) -> ItemStack:
	if idx < 0 or idx >= items.size():
		return null
	var st := items[idx]
	items.remove_at(idx)
	_quick_ran_out()
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


## The bag position of the first stack of `item_id` (-1: none).
func find_index(item_id: String) -> int:
	for i in range(items.size()):
		if items[i].item and items[i].item.id == item_id:
			return i
	return -1


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


## Remove and return everything in the bag except one of each item in `keep`
## (the weapons in your hands): what goes on your grave.
func take_all_except(keep: Array) -> Array[ItemStack]:
	var held: Array = []
	for k in keep:
		if k != null:
			held.append(SaveGame.item_ref(k))
	var out: Array[ItemStack] = []
	for i in range(items.size() - 1, -1, -1):
		var st := items[i]
		if st.item == null:
			continue
		var ref := SaveGame.item_ref(st.item)
		var at := held.find(ref)
		if at >= 0:
			held.remove_at(at)
			if st.quantity <= 1:
				continue
			var rest := ItemStack.new()
			rest.item = st.item
			rest.quantity = st.quantity - 1
			st.quantity = 1
			out.append(rest)
			continue
		out.append(st)
		items.remove_at(i)
	if not out.is_empty():
		_quick_ran_out()
		inventory_changed.emit()
	return out


func clear() -> void:
	items.clear()
	inventory_changed.emit()


# ---- The quick item ----
## Can this item be the quick item? (Food and drink: consumables, not Devil Fruits.)
static func quick_ok(item_data: ItemData) -> bool:
	return item_data != null and item_data.is_consumable() and item_data.devil_fruit == ""


## Make `item_id` the quick item ("" = none). Refused for anything but food and drink.
func select_quick(item_id: String) -> bool:
	if item_id != "" and not quick_ok(ItemDB.get_item(item_id)):
		return false
	if item_id != quick:
		quick = item_id
		quick_changed.emit()
		inventory_changed.emit()
	return true


## The selected quick item (null: none). It may be one you've run out of (count() says).
func quick_item() -> ItemData:
	return find_item(quick) if quick != "" else null


## Every food and drink you carry, one per kind, in bag order; the selected one is
## always among them (first, when you've run out of it).
func quick_choices() -> Array[ItemData]:
	var out: Array[ItemData] = []
	var it := quick_item()
	if it and count(quick) <= 0:
		out.append(it)
	for st in items:
		if quick_ok(st.item) and not out.has(st.item):
			out.append(st.item)
	return out


func _auto_assign(item_data: ItemData) -> void:
	if quick_ok(item_data) and (quick == "" or count(quick) <= 0):
		select_quick(item_data.id)


## The quick item's last one went: on to the next food or drink you carry, if any.
func _quick_ran_out() -> void:
	if quick == "" or count(quick) > 0:
		return
	for st in items:
		if quick_ok(st.item):
			select_quick(st.item.id)
			return
