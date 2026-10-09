extends Node

## The ship's storage (the chest in the crew cabin): what you've banked. It's
## the only thing that survives a death; your bag goes on your grave. In
## co-op the host's storage is the crew's (Net shares it as bag "storage").
var storage: Array[ItemStack] = []
## Your grave (where you last died, holding your bag) - one at a time.
var grave: LootBag = null
var loot_bag_scene: PackedScene
## The galley tops each quick-slot consumable up to this many (and rum if
## you've nothing on the quick slots).
const RESTOCK_CAP := 3

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
## The island chain past Brinehollow (Chain): its seed, rolled for each new
## game (the host's in co-op), and the island the crew is at (-1 = Brinehollow's sea).
var chain_seed: int = randi()
var chain_at: int = -1
## On a chain island the log pose sets once its beast falls (chain_set) or
## LOG_SET_TIME of world time after the crew arrived (chain_since).
var chain_set: bool = false
var chain_since: float = 0.0
const LOG_SET_TIME := 900.0
## A captain needs this level before the log pose sets on the first island.
const LOG_POSE_LEVEL := 5
var _was_set: bool = false
const AUTOSAVE_EVERY := 120.0
var _autosave_t: float = 0.0
## Seconds played in this save (counted while the game isn't paused).
var play_time: float = 0.0


## A fresh start for a new game or a load (the world scene is about to be
## rebuilt): forget everything from the previous session.
func reset_session() -> void:
	storage.clear()
	opened.clear()
	burned.clear()
	maps.clear()
	charted.clear()
	fruit_claims.clear()
	ship_kit = ShipKit.fresh()
	chain_seed = randi()
	chain_at = -1
	chain_set = false
	chain_since = 0.0
	_was_set = false
	play_time = 0.0
	_autosave_t = 0.0
	grave = null
	ship = null
	player = null


## Web: closing the tab sends no close request, so the game saves when the page is hidden.
var _on_page_hidden: JavaScriptObject


func _ready() -> void:
	loot_bag_scene = load("res://scenes/loot/loot_bag.tscn")
	if OS.has_feature("web"):
		_on_page_hidden = JavaScriptBridge.create_callback(func(_args: Array):
			if str(JavaScriptBridge.eval("document.visibilityState")) == "hidden":
				_save_on_exit())
		JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _on_page_hidden)


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
	# the moment the log pose sets on the next island(s)
	var now_set := log_pose_set()
	if now_set and not _was_set and chain_at >= 0 and player.has_log_pose():
		get_tree().call_group("hud", "show_banner", "The log pose has set", "Its needle points on, past this island. Hold L.", true)
	_was_set = now_set
	if _autosave_t >= AUTOSAVE_EVERY:
		_autosave_t = 0.0
		if player.health_component.current_health > 0.0 and not CharacterCreator.active:
			SaveGame.save(player)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_on_exit()


func _save_on_exit() -> void:
	if player and is_instance_valid(player):
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


## The world's chain (built from chain_seed; null outside the world scene).
func chain() -> Chain:
	var w := get_tree().get_first_node_in_group("world_gen")
	return w.chain() if w else null


## The islands the log pose points at (chain nodes), [] while it hasn't set.
## (Every wrist on this screen shows what our captain's would.)
func log_pose_targets() -> Array:
	var c := chain()
	if c == null or player == null or not is_instance_valid(player):
		return []
	if chain_at < 0 and player.progression.level < LOG_POSE_LEVEL:
		return []
	if not log_pose_set():
		return []
	return c.next_of(chain_at).map(func(id): return c.node(id))


## Has the log pose set on where we go next? (In Brinehollow's sea it always
## has; the level gate is the captain's own, see log_pose_targets.)
func log_pose_set() -> bool:
	return chain_at < 0 or chain_set or Weather.world_time() - chain_since >= LOG_SET_TIME


## Seconds until the log pose sets by itself here (0 once it has).
func log_pose_wait() -> float:
	return 0.0 if log_pose_set() else LOG_SET_TIME - (Weather.world_time() - chain_since)


## Host: the crew has come to chain island `id` (the one left behind, and a
## fork's other side, are let go).
func chain_arrive(id: int) -> void:
	Net.everyone("_all_chain", [id, false, Weather.world_time()])


## Host: this island's beast is down - the log pose sets now.
func chain_settle() -> void:
	Net.everyone("_all_chain", [chain_at, true, chain_since])


## (every machine) the chain's state from the host.
func apply_chain(at: int, is_set: bool, since: float) -> void:
	var moved := at != chain_at
	chain_at = at
	chain_set = is_set
	chain_since = since
	if moved:
		_was_set = log_pose_set()
		var c := chain()
		if c and at >= 0:
			get_tree().call_group("hud", "show_toast", "Arrived at %s. The log pose will set in time." % c.node(at)["name"])


func _get_ship() -> Ship:
	if ship == null or not is_instance_valid(ship):
		ship = get_tree().get_first_node_in_group("ship") as Ship
	return ship


## Total stored quantity of an item id (or of everything when id is "").
func stored_count(item_id: String = "") -> int:
	var n := 0
	for b in _storage_contents():
		if item_id == "" or (b.item and b.item.id == item_id):
			n += b.quantity
	return n


## What's in the storage this machine sees (the host's in co-op).
func _storage_contents() -> Array:
	var s := _get_ship()
	if s and s.storage and is_instance_valid(s.storage):
		return s.storage.contents
	return storage


# --------------------------------------------------------------------------
# The crew cabin: rest in the bunk, restock at the galley
# --------------------------------------------------------------------------
## A rest in the bunk: health, stamina and energy back to full. Not with
## enemies about.
func rest(p: Player) -> String:
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node3D
		if e.has_method("in_combat") and e.in_combat() and en.global_position.distance_to(p.global_position) < 40.0:
			return "You can't rest with enemies about"
	var hc := p.health_component
	hc.heal(hc.max_health)
	p.stamina = p.max_stamina
	p.power.energy = p.power.max_energy()
	SaveGame.save(p)
	return "You rest a while. Fully recovered."


## The galley tops up your quick-slot provisions (each to RESTOCK_CAP).
func restock(p: Player) -> String:
	var inv := p.inventory_component
	var ids: Array = []
	for id in inv.hotbar:
		if str(id) != "" and not ids.has(str(id)):
			ids.append(str(id))
	if ids.is_empty():
		ids = ["rum"]
	var got: Array = []
	for id in ids:
		var it := ItemDB.get_item(id)
		var have := inv.count(id)
		if it == null or have >= RESTOCK_CAP:
			continue
		var n := mini(RESTOCK_CAP - have, inv.room_for(it))
		if n > 0 and inv.add_item(it, n):
			got.append("%d %s" % [n, it.display_name])
	if got.is_empty():
		return "Your provisions are full"
	return "Restocked: " + ", ".join(got)


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
	# an old grave you never got back to: lost for good
	if grave and is_instance_valid(grave):
		_sink_grave(grave)
	grave = null
	# your bag goes on a grave where you fell (what you wear and hold stays on you)
	var items := player.inventory_component.take_all_except([player.equipped_weapon, player.offhand_weapon])
	if not items.is_empty():
		grave = make_grave(items, player.global_position)
	_respawn_player()


## Your grave with `items` where you fell (`at`): a headstone on the ground
## (or on a ship's deck, sailing with her); lost at sea, your sack floats.
func make_grave(items: Array[ItemStack], at: Vector3) -> LootBag:
	var s := _get_ship()
	var deep := float(Ocean.depth_at(at, [player.get_rid()], true)) > 1.6
	var aboard := s != null and s.aboard(at)
	var bag := _grave_node(items, deep and not aboard, s.ship_model if aboard else get_tree().current_scene)
	bag.global_position = at if bag.floating else _grave_spot(at)
	return bag


## A grave from a save: `pos` is ship-local when it's on her deck.
func restore_grave(items: Array[ItemStack], pos: Vector3, on_ship: bool, floating: bool) -> LootBag:
	var s := _get_ship()
	var bag := _grave_node(items, floating, s.ship_model if on_ship and s else get_tree().current_scene)
	if on_ship and s:
		bag.position = pos
	else:
		bag.global_position = pos
	return bag


func _grave_node(items: Array[ItemStack], floating: bool, parent: Node) -> LootBag:
	var bag := loot_bag_scene.instantiate() as LootBag
	bag.setup(items, true)
	bag.name = "Grave"
	bag.floating = floating
	parent.add_child(bag)
	var mi := bag.get_node("MeshInstance3D") as MeshInstance3D
	mi.position = Vector3.ZERO
	if bag.floating:
		mi.mesh = Props.sack_mesh()
		return bag
	mi.mesh = Props.grave_mesh()
	var cs := bag.get_node("CollisionShape3D") as CollisionShape3D
	cs.position = Vector3(0, 0.45, -0.35)
	cs.shape = cs.shape.duplicate()
	(cs.shape as BoxShape3D).size = Vector3(0.62, 0.9, 0.16)
	return bag


## Somewhere a grave can stand: the ground under where you fell (the sea
## bed if you drowned; on a ship's deck, the deck).
func _grave_spot(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, at + Vector3.DOWN * 60.0, 1)
	q.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else at


## You died again before you got back: the old grave shakes, then sinks into
## the ground and is gone (with what it held).
func _sink_grave(g: LootBag) -> void:
	g.interactable.enabled = false
	var mi := g.get_node("MeshInstance3D") as Node3D
	var tw := g.create_tween()
	for k in range(10):
		tw.tween_property(mi, "position", Vector3(randf_range(-0.06, 0.06), 0.0, randf_range(-0.06, 0.06)), 0.07)
	tw.tween_callback(func(): FX.dust(g.global_position, 14, 0.9))
	tw.tween_property(mi, "position", Vector3(0, -1.4, 0), 2.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(g.queue_free)
	FX.sfx("thud", g.global_position, -6.0, 0.1, 0.6)


## Your grave was emptied (everything taken back).
func grave_recovered(g: LootBag) -> void:
	if g == grave:
		grave = null
		get_tree().call_group("hud", "show_toast", "You've recovered your belongings")


func _respawn_player() -> void:
	await get_tree().create_timer(3.0).timeout

	if not player or not _get_ship():
		return

	# you wake in the crew cabin, by the bunk (before she's yours: on the sand
	# where you first came to)
	var isl := Story.island()
	player.global_position = ship.respawn_point.global_position if ship.owned() or isl == null else isl.wake_spot()[0] + Vector3.UP * 0.1
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
