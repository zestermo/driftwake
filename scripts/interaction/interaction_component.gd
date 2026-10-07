extends Area3D
class_name InteractionComponent

signal prompt_changed(text: String)
signal prompt_hidden

var current_interactable: Interactable = null
var player: Player
var nearby_interactables: Array[Interactable] = []


func _ready() -> void:
	await owner.ready
	player = owner as Player
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _unhandled_input(event: InputEvent) -> void:
	if Dialogue.is_blocking():
		return
	if event.is_action_pressed("interact") and current_interactable:
		get_viewport().set_input_as_handled()
		var it := current_interactable
		it.interact(player)
		# (it may have just gone away: re-check now rather than next tick)
		if not is_instance_valid(it) or it.is_queued_for_deletion() or not it.enabled:
			current_interactable = null
			_shown = false
			prompt_hidden.emit()


func _physics_process(_delta: float) -> void:
	if not player:
		return
	# the thing we were looking at is gone (a picked-up bag, an opened chest):
	# drop its prompt right away
	if not is_instance_valid(current_interactable) or (current_interactable and (current_interactable.is_queued_for_deletion() or not current_interactable.enabled)):
		if current_interactable != null or _shown:
			current_interactable = null
			_shown = false
			prompt_hidden.emit()
	if player.context != Player.Context.ON_FOOT or Dialogue.active:
		if current_interactable:
			current_interactable = null
			prompt_hidden.emit()
		return

	var best: Interactable = null
	var best_dist := 999.0
	# a ship's deck job in reach (patch, douse, pump, capstan) takes F: those
	# are held, read straight off the key, and a cannon or ladder close by
	# would otherwise grab every press
	var ship := get_tree().get_first_node_in_group("ship")
	var busy: bool = ship != null and str(ship.get("local_job")) != ""
	for inter in ([] if busy else nearby_interactables):
		if not is_instance_valid(inter) or not inter.enabled or inter.is_queued_for_deletion():
			continue
		if (player.is_swimming() or player.current_state_name() == "Climb") and not inter.usable_in_water:
			continue
		var dist := player.global_position.distance_to(inter.global_position)
		if dist < best_dist:
			best_dist = dist
			best = inter

	if best != current_interactable or (best == null and _shown):
		current_interactable = best
		if current_interactable:
			_shown = true
			prompt_changed.emit(current_interactable.prompt_text)
		else:
			_shown = false
			prompt_hidden.emit()


var _shown: bool = false


func _on_area_entered(area: Area3D) -> void:
	if area is Interactable:
		nearby_interactables.append(area as Interactable)


func _on_area_exited(area: Area3D) -> void:
	if area is Interactable:
		nearby_interactables.erase(area as Interactable)
	nearby_interactables.assign(nearby_interactables.filter(func(i): return is_instance_valid(i)))
