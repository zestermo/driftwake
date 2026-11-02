extends PlayerState
## Fishing (Fishing; from F facing water with a rod, or the action wheel's Fish): the cast (the bobber
## flies at Fishing.RELEASE), the wait with a nibble or two, the bite (the float dips: reel inside the
## window with F or a click), the reel and the landing, or a miss: too soon pulls the hook clear (the
## line comes in), too late and it gets away (the line stays in for another). The rod and what's on the
## line are FishRod's (seen on every screen); the catch is this captain's. Moving, jumping, a dodge or a
## blow reels in and ends it. (1.28) A legendary is fought instead of reeled (FishFight: hold reel to wind it in,
## ease off while it runs; FishFightHud draws the line), and every catch goes in the fish journal (Fishing.record).

const COOL := 0.25

var phase := ""
var _t := 0.0
var _tier := ""
## The bait on the hook for this cast ("" a bare hook).
var _bait := ""
var _spot := Vector3.ZERO
var _bite_at := 0.0
var _nibbles: Array = []
var _nibble_count := 0
var _window := 0.0
var _catch := ""
var _hp := 0.0
var _reel_len := 1.0
var fight: FishFight
## (tests, debug) the next catch instead of a roll.
var rig := ""
var _hud: CanvasLayer


func enter(_data: Dictionary) -> void:
	_tier = Fishing.rod_of(player)
	_spot = Fishing.cast_spot(player, _tier)
	_bait = player.inventory_component.bait_on()
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
	var reel := player.inp.just_pressed("interact") or input_buffer.consume_action("light_attack")
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
			# (1.28) an auto-reel on the rod strikes for you and reels faster
			var auto: bool = player.gadgets.reel_left > 0
			if reel or auto:
				# (where the float is now: cast from a deck under way it has trolled along with her)
				_catch = Fishing.roll_catch(player, _tier, _rod()._bob_at, _bait) if rig == "" else rig
				rig = ""
				if FishTable.rarity_of(_catch) == 4 and FishTable.LEGEND_PULL.has(_catch):
					_start_fight()
					return
				_rod().reel()
				_reel_len = Fishing.REEL_LEN
				if auto:
					player.gadgets.reel_left -= 1
					_reel_len *= 1.0 - player.gadgets.reel_k
					FX.sfx("clack", player.global_position + Vector3(0, 1.0, 0), -8.0, 0.05, 1.6)
				player.body_model.play("rod_reel", _reel_len)
				_go("reel")
			elif _t >= _window:
				Fishing.lost(player)
				player.call("_toast", "It got away...")
				_rod().escape()
				_wait()
		"fight":
			var held := player.inp.pressed("interact") or player.inp.pressed("light_attack")
			fight.tick(delta, held)
			_rod().fight_pull(fight.progress(), fight.running)
			if fight.result == "landed":
				_end_fight()
				_rod().reel()
				_reel_len = 0.4
				player.body_model.play("rod_reel", _reel_len)
				_go("reel")
			elif fight.result != "":
				_end_fight()
				Fishing.lost(player)
				player.call("_toast", "The line snapped!" if fight.result == "snapped" else "It threw the hook...")
				_rod().reel()
				player.body_model.play("rod_strike", Fishing.STRIKE_LEN)
				_go("out")
		"reel":
			if _t >= _reel_len:
				_rod().land(_catch)
				player.body_model.play("rod_land", Fishing.LAND_LEN)
				_go("land")
		"land":
			if _catch != "" and _t >= Fishing.LAND_LEN * Fishing.BAGGED:
				Fishing.land(player, _catch, _bait, _rod()._bob_at)
				_catch = ""
			if _t >= Fishing.LAND_LEN:
				_end("")
				return
		"out":
			if _t >= Fishing.STRIKE_LEN:
				_end("")
				return
	if phase in ["wait", "bite", "fight"] and (get_movement_input().length() > 0.3 or player.inp.just_pressed("jump") or input_buffer.has_action("dodge")
			or input_buffer.has_action("heavy_attack")):
		_end("You reel in")



## The line's in: a bite to come (and a nibble or two first), the float held.
func _wait() -> void:
	_go("wait")
	_bite_at = Fishing.bite_secs(player, _tier, _bait)
	_nibble_count = randi() % (Fishing.NIBBLES_MAX + 1)
	_nibbles.clear()
	for i in range(_nibble_count):
		_nibbles.append(randf_range(_bite_at * 0.35, _bite_at * 0.9))
	_nibbles.sort()
	player.body_model.hold("rod_wait")


## A legendary's on: the fight starts (the float stays down, the rod bent), its bars on screen.
func _start_fight() -> void:
	fight = FishFight.new(float(FishTable.LEGEND_PULL[_catch]), randi())
	_go("fight")
	_hud = CanvasLayer.new()
	_hud.layer = 6
	var bars := FishFightHud.new()
	bars.fight = fight
	bars.fish_name = "Something huge is on the line!"
	_hud.add_child(bars)
	player.add_child(_hud)
	player.body_model.hold("rod_wait")
	FX.sfx("fish_bite", player.global_position, 2.0, 0.05, 0.7)


func _end_fight() -> void:
	if _hud and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null
	_rod().fight_pull(0.0, false)


func _end(why: String) -> void:
	if why != "":
		player.call("_toast", why)
	transitioned.emit(self, "Idle", {})


func exit() -> void:
	_end_fight()
	_rod().stop()
	if player.body_model.current_action().begins_with("rod_"):
		player.body_model.stop_action()
	phase = ""
