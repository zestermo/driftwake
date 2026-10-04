extends Node

var banked_items: Array[ItemStack] = []
var active_loot_bag: LootBag = null
var loot_bag_scene: PackedScene

var ship: Ship
var player: Player


func _ready() -> void:
	loot_bag_scene = load("res://scenes/loot/loot_bag.tscn")


## Called by the player when it enters the scene (works however the scene was loaded).
func register_player(p: Player) -> void:
	player = p
	if not player.health_component.died.is_connected(_on_player_died):
		player.health_component.died.connect(_on_player_died)


func _get_ship() -> Ship:
	if ship == null or not is_instance_valid(ship):
		ship = get_tree().get_first_node_in_group("ship") as Ship
	return ship


func bank_items() -> int:
	if not player:
		return 0
	var inventory := player.get_node("InventoryComponent") as InventoryComponent
	if not inventory:
		return 0

	# Only loot is banked; weapons and consumables stay with the player.
	var items := inventory.take_loot()
	var count := 0
	for stack in items:
		_add_banked(stack)
		count += stack.quantity
	return count


func _add_banked(stack: ItemStack) -> void:
	for b in banked_items:
		if b.item == stack.item:
			b.quantity += stack.quantity
			return
	banked_items.append(stack.duplicate())


## Total banked quantity of an item id (or of everything when id is "").
func banked_count(item_id: String = "") -> int:
	var n := 0
	for b in banked_items:
		if item_id == "" or (b.item and b.item.id == item_id):
			n += b.quantity
	return n


func _on_player_died() -> void:
	if not player:
		return

	var inventory := player.get_node("InventoryComponent") as InventoryComponent
	if not inventory:
		return

	# Destroy old recovery bag if exists (permanent loss)
	if active_loot_bag and is_instance_valid(active_loot_bag):
		active_loot_bag.queue_free()
		active_loot_bag = null

	# Drop carried loot at the death location (gear is kept)
	var items := inventory.take_loot()
	if items.size() > 0 and loot_bag_scene:
		var bag := loot_bag_scene.instantiate() as LootBag
		bag.setup(items, true)
		get_tree().current_scene.add_child(bag)
		bag.global_position = player.global_position
		active_loot_bag = bag

	# Respawn after delay
	_respawn_player()


func _respawn_player() -> void:
	await get_tree().create_timer(3.0).timeout

	if not player or not _get_ship():
		return

	player.global_position = ship.respawn_point.global_position
	player.reset_physics_interpolation()
	player.sheathe_weapon(true)
	player.velocity = Vector3.ZERO
	player.health_component.current_health = player.health_component.max_health
	player.health_component.health_changed.emit(
		player.health_component.current_health,
		player.health_component.max_health
	)

	# Force to idle state
	if player.state_machine.current_state:
		player.state_machine.current_state.exit()
	var idle := player.state_machine.states.get("idle") as State
	if idle:
		idle.enter({})
		player.state_machine.current_state = idle
