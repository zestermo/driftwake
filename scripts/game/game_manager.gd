extends Node

var banked_items: Array[ItemStack] = []
var active_loot_bag: LootBag = null
var loot_bag_scene: PackedScene

var ship: Ship
var player: Player
## Saved world state: chests opened (LootBag.save_id) and thornbrush burned
## (node names).
var opened: Dictionary = {}
var burned: Dictionary = {}
## Treasure maps found in bottles (treasure index -> true) and places put on
## the sea chart ("island:<name>", "reef:<i>", ... -> true).
var maps: Dictionary = {}
var charted: Dictionary = {}
## Devil Fruits already found in this world (item id -> who found it).
var fruit_claims: Dictionary = {}
## The shipwright's work on our ship (ShipKit; the host's world in co-op).
var ship_kit: Dictionary = ShipKit.fresh()
const AUTOSAVE_EVERY := 120.0
var _autosave_t: float = 0.0
## Seconds played in this save (counted while the game isn't paused).
var play_time: float = 0.0


## A fresh start for a new game or a load (the world scene is about to be
## rebuilt): forget everything from the previous session.
func reset_session() -> void:
	banked_items.clear()
	opened.clear()
	burned.clear()
	maps.clear()
	charted.clear()
	fruit_claims.clear()
	ship_kit = ShipKit.fresh()
	play_time = 0.0
	_autosave_t = 0.0
	active_loot_bag = null
	ship = null
	player = null


func _ready() -> void:
	loot_bag_scene = load("res://scenes/loot/loot_bag.tscn")


## Called by the player when it enters the scene (works however the scene was loaded).
func register_player(p: Player) -> void:
	player = p
	Net.register_local(p)
	if not player.health_component.died.is_connected(_on_player_died):
		player.health_component.died.connect(_on_player_died)
	_load_save.call_deferred()


func _load_save() -> void:
	# let the world finish building (chests, thornbrush, the ship) first
	await get_tree().process_frame
	await get_tree().process_frame
	if player and is_instance_valid(player) and SaveGame.load_into(player):
		get_tree().call_group("hud", "show_toast", "Welcome back, captain")
	if player and is_instance_valid(player):
		Net.world_loaded()


## A message for the title screen (e.g. "The host closed the session").
var title_message: String = ""


func show_title_message(text: String) -> void:
	title_message = text


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or get_tree().paused:
		return
	play_time += delta
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_EVERY:
		_autosave_t = 0.0
		if player.health_component.current_health > 0.0 and not CharacterCreator.active:
			SaveGame.save(player)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and player and is_instance_valid(player):
		SaveGame.save(player)


func mark_opened(save_id: String) -> void:
	if save_id != "":
		opened[save_id] = true


func mark_burned(node_name: String) -> void:
	burned[node_name] = true


## After loading: remove opened chests and burned thornbrush from the world.
func apply_world_state() -> void:
	for bag in get_tree().current_scene.find_children("*", "LootBag", true, false):
		var lb := bag as LootBag
		if lb.save_id != "" and opened.has(lb.save_id):
			lb.queue_free()
	for b in get_tree().get_nodes_in_group("burnable"):
		if burned.has(str((b as Node).name)):
			(b as Burnable).burn_away_instantly()


## Combat experience for the player (an enemy went down at `at`).
func award_xp(amount: int, at: Vector3 = Vector3.INF) -> void:
	if player and is_instance_valid(player) and player.progression:
		player.progression.add_xp(amount, at)


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
	SaveGame.save(player)
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
	# co-op: knocked out first - a crewmate can still get you up (the
	# player calls bleed_out() if nobody does)
	if Net.coop() and Net.others_standing() and player.context != Player.Context.HELM:
		return
	_die_for_real()


## Nobody got you up in time.
func bleed_out() -> void:
	_die_for_real()


func _die_for_real() -> void:
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
