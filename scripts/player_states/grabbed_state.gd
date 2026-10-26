extends PlayerState
## Grabbed (1.23: block a brute three times and he grabs you; PirateGrunt "grab", HitData.grab): held up in front of
## him struggling, mash attack, jump or dodge to break free (MASH presses: you shove off him and he reels); held HOLD s,
## he throws you down. Run on the grabbed captain's own machine; the brute hears how it ended (grab_ended).

const MASH := 7
const HOLD := 2.2
const THROW_DAMAGE := 16.0
const KEYS := ["light_attack", "heavy_attack", "dodge", "parry"]

var _by: Node3D
var _t := 0.0
var _presses := 0


func enter(data: Dictionary) -> void:
	_by = data.get("by") as Node3D
	_t = 0.0
	_presses = 0
	player.velocity = Vector3.ZERO
	player.sprinting = false
	player.is_parrying = false
	player.body_model.hold("jug_held", 0.12)
	player.call("_toast", "Grabbed! Mash to break free")


func physics_update(delta: float) -> void:
	_t += delta
	var held := _by != null and is_instance_valid(_by)
	if held:
		# up against his chest, facing him
		var f: Vector3 = -_by.get_node("Facing").global_basis.z
		f.y = 0.0
		f = f.normalized()
		var spot := _by.global_position + f * 0.85
		player.velocity = (spot - player.global_position) * 12.0
		player.velocity.y = 0.0
		player.player_model.rotation.y = atan2(f.x, f.z)
	else:
		player.velocity = Vector3.ZERO
	player.move_and_slide()
	var pressed := player.inp.just_pressed("jump")
	for k in KEYS:
		if input_buffer.consume_action(k):
			pressed = true
	if pressed:
		_presses += 1
		player.squash(-1.0)
		Net.fx("sfx", ["hup", player.global_position, -10.0, 0.08, 1.1 + 0.05 * _presses])
		if _presses % 2 == 0:
			Net.fx("dust", [player.global_position, 3, 0.4])
	if _presses >= MASH or not held:
		_free(held)
	elif _t >= HOLD:
		_thrown()


## Broke free: a shove off his chest, he reels.
func _free(held: bool) -> void:
	if held:
		var away := player.global_position - _by.global_position
		away.y = 0.0
		player.velocity = away.normalized() * 5.0
		Net.fx("impact", [player.global_position + Vector3(0, 1.2, 0) - away.normalized() * 0.4, Color(1.0, 0.9, 0.7)])
		Net.fx("sfx", ["punch", player.global_position, -4.0, 0.05, 1.0])
		_by.call("grab_ended", true)
		player.call("_toast", "Broke free!")
	transitioned.emit(self, "Idle", {})


## Held too long: thrown down at his feet.
func _thrown() -> void:
	var f: Vector3 = -_by.get_node("Facing").global_basis.z
	f.y = 0.0
	_by.call("grab_ended", false)
	if not Duel.beaten(player, THROW_DAMAGE * (1.0 - player.damage_reduction())):
		player.health_component.take_damage(THROW_DAMAGE * (1.0 - player.damage_reduction()))
	Net.fx("dust_ring", [player.global_position, 12, 0.9])
	Net.fx("sfx", ["thud", player.global_position, -2.0, 0.05, 0.8])
	if player.health_component.current_health > 0.0:
		player.knock_down(f.normalized() * 5.0 + Vector3.UP * 4.0)


func exit() -> void:
	if player.body_model.current_action() == "jug_held":
		player.body_model.stop_action()
