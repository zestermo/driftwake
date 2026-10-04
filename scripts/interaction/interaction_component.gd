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
		current_interactable.interact(player)


func _physics_process(_delta: float) -> void:
	if not player:
		return
	if player.context != Player.Context.ON_FOOT or Dialogue.active:
		if current_interactable:
			current_interactable = null
			prompt_hidden.emit()
		return

	var best: Interactable = null
	var best_dist := 999.0
	for inter in nearby_interactables:
		if not is_instance_valid(inter) or not inter.enabled:
			continue
		if (player.is_swimming() or player.current_state_name() == "Climb") and not inter.usable_in_water:
			continue
		var dist := player.global_position.distance_to(inter.global_position)
		if dist < best_dist:
			best_dist = dist
			best = inter

	if best != current_interactable:
		current_interactable = best
		if current_interactable:
			prompt_changed.emit(current_interactable.prompt_text)
		else:
			prompt_hidden.emit()


func _on_area_entered(area: Area3D) -> void:
	if area is Interactable:
		nearby_interactables.append(area as Interactable)


func _on_area_exited(area: Area3D) -> void:
	if area is Interactable:
		nearby_interactables.erase(area as Interactable)
