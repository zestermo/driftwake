extends StaticBody3D
class_name LootBag
## A container on the ground: a chest, a defeated enemy's dropped weapon, your
## recovery bag, or items someone dropped. Opening it shows its contents
## next to your bag (take items one by one, take everything with F, drag your
## own items in to store them). Empty, it goes away (a placed chest is then
## remembered as opened).
##
## Co-op: world chests are each captain's own copy (everyone loots every
## chest once). Dropped items are shared (`shared_id`): the host keeps the
## contents, everyone sees the same bag, and whoever takes an item gets it -
## that's how captains trade (Devil Fruits included).

signal contents_changed

var contents: Array[ItemStack] = []
var is_recovery_bag: bool = false
## Placed chests have an id so the save remembers they've been opened.
var save_id: String = ""
## Co-op: set for dropped bags everyone shares (see Net.drop_items).
var shared_id: String = ""
## Bobs on the waves (plunder from a sunken ship); grab it while swimming.
var floating: bool = false
var _bob_t: float = 0.0

@onready var interactable: Interactable = $Interactable
@onready var mesh: MeshInstance3D = $MeshInstance3D

var _glow_tween: Tween


func _ready() -> void:
	interactable.interacted.connect(_on_interact)
	interactable.prompt_text = _prompt()
	if is_recovery_bag:
		_start_glow()
	if floating:
		interactable.usable_in_water = true
		set_physics_process(true)
	else:
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not floating:
		return
	_bob_t += delta
	var oc := get_node_or_null("/root/Ocean")
	if oc and oc.has_method("get_wave_height"):
		var h := float(oc.call("get_wave_height", global_position))
		global_position.y = h - 0.15
		rotation = Vector3(sin(_bob_t * 1.3) * 0.12, rotation.y + delta * 0.05, cos(_bob_t * 1.1) * 0.1)


func _prompt() -> String:
	if is_recovery_bag:
		return "Recover lost loot"
	if save_id != "" or floating:
		return "Open chest"
	if contents.size() == 1 and contents[0].item:
		return "Pick up %s" % contents[0].item.display_name
	return "Pick up loot"


## What the loot window calls it.
func title() -> String:
	if is_recovery_bag:
		return "Your lost loot"
	if save_id != "":
		return "Chest"
	if floating:
		return "Plunder"
	return "Dropped items" if shared_id != "" else "Loot"


func setup(loot: Array[ItemStack], recovery: bool = false) -> void:
	contents = loot
	is_recovery_bag = recovery


func _on_interact(player: Player) -> void:
	# a single item (a dropped sword) is picked up straight away; anything
	# more opens the loot window (headless test runs just take everything)
	var gm := get_node_or_null("/root/GameMenu")
	if contents.size() > 1 and gm and gm.has_method("open_container") and DisplayServer.get_name() != "headless":
		gm.open_container(self)
	else:
		take_all(player)


## Take everything (what F does, in the world or in the loot window).
func _on_picked_up(player: Player) -> void:
	take_all(player)


func take_all(player: Player) -> void:
	for i in range(contents.size() - 1, -1, -1):
		if i < contents.size():
			take(i, player)


## Move a stack (or `qty` of it) into the player's bag, as far as it fits.
func take(idx: int, player: Player, qty: int = -1) -> void:
	if idx < 0 or idx >= contents.size() or player == null:
		return
	var st := contents[idx]
	var want := st.quantity if qty < 0 else mini(qty, st.quantity)
	var inv := player.inventory_component
	want = mini(want, inv.room_for(st.item))
	if want <= 0:
		player.call("_toast", "Your bag is full")
		return
	if shared_id != "":
		Net.bag_take(self, st.item, want)
		return
	# one of each Devil Fruit per world: in co-op every captain opens their
	# own copy of a chest, but only the first finds the fruit
	if st.item.devil_fruit != "" and save_id != "":
		var net := get_node_or_null("/root/Net")
		if net and not net.claim_fruit(st.item.id):
			player.call("_toast", "The %s is gone - a crewmate got here first" % st.item.display_name)
			_remove(idx, st.quantity)
			_changed()
			return
	inv.add_item(st.item, want)
	_remove(idx, want)
	_changed()


## Put (part of) a bag stack into this container.
func store(player: Player, bag_idx: int, qty: int = -1) -> void:
	if player == null:
		return
	var st := player.inventory_component.take_amount(bag_idx, qty)
	if st == null:
		return
	player.check_equipped()
	if shared_id != "":
		Net.bag_store(self, st.item, st.quantity)
		return
	add_stack(st.item, st.quantity)
	_changed()


func add_stack(item: ItemData, qty: int) -> void:
	if item.stackable:
		for c in contents:
			if c.item == item and c.quantity < item.max_stack:
				var n := mini(qty, item.max_stack - c.quantity)
				c.quantity += n
				qty -= n
				if qty <= 0:
					return
	while qty > 0:
		var ns := ItemStack.new()
		ns.item = item
		ns.quantity = mini(qty, item.max_stack if item.stackable else 1)
		qty -= ns.quantity
		contents.append(ns)


func _remove(idx: int, qty: int) -> void:
	var st := contents[idx]
	st.quantity -= qty
	if st.quantity <= 0:
		contents.remove_at(idx)


## Index of the first stack holding `item` (shared bags match by item).
func find_stack(item: ItemData) -> int:
	var ref := SaveGame.item_ref(item)
	for i in range(contents.size()):
		if contents[i].item == item or (contents[i].item and SaveGame.item_ref(contents[i].item) == ref):
			return i
	return -1


## Co-op: the host says what's in a shared bag now.
func set_contents(refs: Array) -> void:
	contents.clear()
	for e in refs:
		var it := SaveGame.item_from(e[0])
		if it:
			var st := ItemStack.new()
			st.item = it
			st.quantity = int(e[1])
			contents.append(st)
	interactable.prompt_text = _prompt()
	contents_changed.emit()
	if contents.is_empty():
		queue_free()


func refs() -> Array:
	var out: Array = []
	for c in contents:
		out.append([SaveGame.item_ref(c.item), c.quantity])
	return out


func _changed() -> void:
	interactable.prompt_text = _prompt()
	contents_changed.emit()
	if contents.is_empty():
		var gm := get_node_or_null("/root/GameManager")
		if gm and save_id != "":
			gm.mark_opened(save_id)
		interactable.enabled = false
		queue_free()


func _start_glow() -> void:
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(mesh, "scale", Vector3(1.2, 1.2, 1.2), 0.5)
	_glow_tween.tween_property(mesh, "scale", Vector3(1.0, 1.0, 1.0), 0.5)
