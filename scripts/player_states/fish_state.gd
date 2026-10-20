extends PlayerState
## Fishing (Fishing; from F facing water with a rod, or the action wheel's Fish): the cast (the bobber
## flies at Fishing.RELEASE), the wait with a nibble or two, the bite (the float dips: reel inside the
## window with F or a click), the reel and the landing, or a miss: too soon pulls the hook clear (the
## line comes in), too late and it gets away (the line stays in for another). The rod and what's on the
## line are FishRod's (seen on every screen); the catch is this captain's. Moving, jumping, a dodge or a
## blow reels in and ends it.

const COOL := 0.25

var phase := ""
var _t := 0.0
var _tier := ""
var _spot := Vector3.ZERO
var _bite_at := 0.0
var _nibbles: Array = []
var _nibble_count := 0
var _window := 0.0
var _catch := ""
var _hp := 0.0


func enter(_data: Dictionary) -> void:
	_tier = Fishing.rod_of(player)
	_spot = Fishing.cast_spot(player, _tier)
	player.velocity = Vector3.ZERO
	player.sprinting = false
	player.sheathe_weapon(true)
	if player.jam.playing:
		player.jam.stop()
	_hp = player.health_component.current_health
	_go("cast")
	player.body_model.play("rod_cast", Fishing.CAST_LEN)


func _go(p: String) -> void:
	phase = p
	_t = 0.0


func _rod() -> FishRod:
	return player.fish_rod


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.move_and_slide()
	_t += delta
	if player.health_component.current_health < _hp:
		_end("")
		return
	_hp = player.health_component.current_health
	var reel := Input.is_action_just_pressed("interact") or input_buffer.consume_action("light_attack")
	match phase:
		"cast":
			if _t >= Fishing.CAST_LEN * Fishing.RELEASE and _rod().phase == "":
				_rod().throw(_spot)
			if _t >= Fishing.CAST_LEN:
				_wait()
		"wait":
			if not _nibbles.is_empty() and _t >= float(_nibbles[0]):
				_nibbles.pop_front()
				_rod().nibble()
			if _t >= _bite_at:
				_rod().bite()
				_window = Fishing.window(player, _tier)
				_go("bite")
			elif reel and _t > COOL:
				Fishing.lost(player)
				player.call("_toast", "Too soon - it was only nibbling" if _nibbles.size() < _nibble_count else "Nothing on the line yet")
				_rod().reel()
				player.body_model.play("rod_strike", Fishing.STRIKE_LEN)
				_go("out")
		"bite":
			if reel:
				_catch = Fishing.roll_catch(player, _tier)
				_rod().reel()
				player.body_model.play("rod_reel", Fishing.REEL_LEN)
				_go("reel")
			elif _t >= _window:
				Fishing.lost(player)
				player.call("_toast", "It got away...")
				_rod().escape()
				_wait()
		"reel":
			if _t >= Fishing.REEL_LEN:
				_rod().land(_catch)
				player.body_model.play("rod_land", Fishing.LAND_LEN)
				_go("land")
		"land":
			if _catch != "" and _t >= Fishing.LAND_LEN * Fishing.BAGGED:
				Fishing.land(player, _catch)
				_catch = ""
			if _t >= Fishing.LAND_LEN:
				_end("")
				return
		"out":
			if _t >= Fishing.STRIKE_LEN:
				_end("")
				return
	if phase in ["wait", "bite"] and (get_movement_input().length() > 0.3 or Input.is_action_just_pressed("jump") or input_buffer.has_action("dodge")
			or input_buffer.has_action("heavy_attack")):
		_end("You reel in")



## The line's in: a bite to come (and a nibble or two first), the float held.
func _wait() -> void:
	_go("wait")
	_bite_at = Fishing.bite_secs(player, _tier)
	_nibble_count = randi() % (Fishing.NIBBLES_MAX + 1)
	_nibbles.clear()
	for i in range(_nibble_count):
		_nibbles.append(randf_range(_bite_at * 0.35, _bite_at * 0.9))
	_nibbles.sort()
	player.body_model.hold("rod_wait")


func _end(why: String) -> void:
	if why != "":
		player.call("_toast", why)
	transitioned.emit(self, "Idle", {})


func exit() -> void:
	_rod().stop()
	if player.body_model.current_action().begins_with("rod_"):
		player.body_model.stop_action()
	phase = ""
