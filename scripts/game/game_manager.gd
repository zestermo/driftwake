extends Node

var banked_items: Array[ItemStack] = []
var active_loot_bag: LootBag = null
var loot_bag_scene: PackedScene

var ship: Ship
var player: Player


func _ready() -> void:
	loot_bag_scene = load("res://scenes/loot/loot_bag.tscn")
	await get_tree().process_frame
	ship = get_tree().get_first_node_in_group("ship") as Ship
	player = get_tree().get_first_node_in_group("player") as Player
	if player:
		player.health_component.died.connect(_on_player_died)


func bank_items() -> int:
	if not player:
		return 0
	var inventory := player.get_node("InventoryComponent") as InventoryComponent
	if not inventory:
		return 0

	var items := inventory.get_all_items()
	var count := 0
	for stack in items:
		banked_items.append(stack.duplicate())
		count += stack.quantity
	inventory.clear()
	return count


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

	# Drop loot at death location
	var items := inventory.get_all_items()
	if items.size() > 0 and loot_bag_scene:
		var bag := loot_bag_scene.instantiate() as LootBag
		bag.setup(items, true)
		get_tree().current_scene.add_child(bag)
		bag.global_position = player.global_position
		active_loot_bag = bag
		inventory.clear()

	# Respawn after delay
	_respawn_player()


func _respawn_player() -> void:
	await get_tree().create_timer(2.0).timeout

	if not player or not ship:
		return

	player.global_position = ship.respawn_point.global_position
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
