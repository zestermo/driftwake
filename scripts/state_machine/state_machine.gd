extends Node
class_name StateMachine

@export var initial_state_name: String = "idle"

var current_state: State
var states: Dictionary = {}


func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.transitioned.connect(_on_child_transitioned)

	var initial := states.get(initial_state_name.to_lower()) as State
	if initial:
		initial.enter({})
		current_state = initial


## Co-op: a menu is open but the world keeps running (no control).
func _locked() -> bool:
	return owner != null and owner.get("input_locked") == true


func _process(delta: float) -> void:
	if current_state and not _locked() and owner.get("hitstop_left") <= 0.0:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if owner.get("hitstop_left") > 0.0:
		owner.hitstop_left -= delta
		return
	if current_state:
		if _locked() and owner.has_method("locked_physics") and owner.locked_physics(delta):
			return
		current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state and not _locked():
		current_state.handle_input(event)


func _on_child_transitioned(state: State, new_state_name: String, data: Dictionary) -> void:
	if state != current_state:
		return

	var new_state := states.get(new_state_name.to_lower()) as State
	if new_state == null:
		push_warning("StateMachine: State '%s' not found" % new_state_name)
		return

	current_state.exit()
	new_state.enter(data)
	current_state = new_state


## Switch state from outside (getting hit, dying), whatever state is active.
func force_state(new_state_name: String, data: Dictionary = {}) -> void:
	var new_state := states.get(new_state_name.to_lower()) as State
	if new_state == null:
		push_warning("StateMachine: State '%s' not found" % new_state_name)
		return
	if current_state:
		current_state.exit()
	new_state.enter(data)
	current_state = new_state
