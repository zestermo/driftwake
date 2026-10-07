extends PlayerState
## Climbing. Ladders and the rigging are climbed by hand: F grabs on (from the
## water or the deck at a ladder, at the foot of the ratlines or in the crow's
## nest), W/S climb, Space jumps off, F lets go. Off the top you go over the
## rail / into the nest; off the bottom of the ratlines onto the deck, off the
## bottom of a ladder into the sea. With a one-handed blade you can climb
## armed (Z): the left hand holds on, your right side turns out toward where
## you look and left click chops down. Low ledges out of the water are a
## scripted pull-up. Paths are kept in the frame of what you climb, so it
## works on a rocking ship.

const LADDER_UP := 1.9
const LADDER_DOWN := 2.4
const RIG_UP := 2.8
const RIG_DOWN := 3.2
## Holding on one-handed is slower.
const ARMED_MULT := 0.6
const CHOP_TIME := 0.5
const CHOP_ON := 0.26
const CHOP_OFF := 0.38
const CHOP_DAMAGE := 10.0
const JUMP_UP := 4.5
const JUMP_OUT := 3.5

var anchor: Node3D
var kind: String = ""
var keys: Array = []      # [[time, local_pos], ...]
var total: float = 0.0
var t: float = 0.0
## After the keys: "line" (hanging on, climbing by hand) or "idle" (done).
var _then: String = ""
var _yaw_local: float = 0.0
## How far along the climb (m from the bottom), and its length.
var s: float = 0.0
var _len: float = 0.0
var _lad: Ladder
var _rig: ShipRigging
var _chop_t: float = -1.0
var _hit_on: bool = false
var _anchor_prev := Vector3.ZERO
var _anchor_v := Vector3.ZERO


func enter(data: Dictionary) -> void:
	t = 0.0
	keys.clear()
	_then = ""
	_chop_t = -1.0
	_hit_on = false
	_lad = null
	_rig = null
	kind = str(data.get("kind", "ledge"))
	player.velocity = Vector3.ZERO
	player.sprinting = false
	player.body_model.swimming = false
	player.stamina_regen_mult = 1.0
	if kind == "ladder":
		_lad = data["ladder"]
		anchor = _lad
		_len = _lad.rail + 0.05 - _bottom_y()
		_yaw_local = 0.0  # face -Z of the ladder (toward the deck)
		var start := _lad.to_local(player.global_position)
		if start.z < 0.2 and start.y > _lad.rail - 0.6:
			# from the deck: over the rail and down onto the top rungs
			s = _len
			_play([[0.0, start], [0.3, Vector3(0, _lad.rail + 0.15, -0.15)], [0.65, _line(s)]], "line")
		else:
			s = clampf(start.y - _bottom_y(), 0.0, _len * 0.5)
			_play([[0.0, start], [0.25, _line(s)]], "line")
			Net.fx("sfx", ["splash", player.global_position, -8.0, 0.1, 1.2])
	elif kind == "rig":
		_rig = data["rig"]
		anchor = _rig
		_len = _rig.hold(0.0).distance_to(_rig.hold(1.0))
		_yaw_local = _rig.side * PI * 0.5  # facing in, toward the mast
		var start := _rig.to_local(player.global_position)
		if bool(data.get("up", true)):
			s = 0.0
			_play([[0.0, start], [0.35, _line(0.0)]], "line")
		else:
			s = _len
			_play([[0.0, start], [0.3, _rig.nest_gap()], [0.55, _line(_len)]], "line")
		Net.fx("sfx", ["rope", player.global_position, -10.0, 0.1, 1.1])
	else:
		anchor = data.get("anchor") as Node3D
		var edge: Vector3 = data["edge"]
		var top: Vector3 = data["top"]
		var fwd: Vector3 = data["fwd"]
		var start := player.global_position
		var hang := Vector3(edge.x, edge.y - 0.95, edge.z) - fwd * 0.42
		if anchor:
			start = anchor.to_local(start)
			hang = anchor.to_local(hang)
			var e := anchor.to_local(edge - fwd * 0.1 + Vector3.UP * 0.05)
			var tp := anchor.to_local(top)
			_play([[0.0, start], [0.18, hang], [0.5, e], [0.78, tp]], "idle")
			_yaw_local = _local_yaw(anchor, fwd)
		total = 0.78
		player.body_model.play("mantle", total)
		Net.fx("splash", [Vector3(player.global_position.x, player.water_surface(), player.global_position.z), 5, 0.6])
		Net.fx("sfx", ["splash", player.global_position, -8.0, 0.1, 1.2])
		player.sheathe_weapon(true)
		return
	player.body_model.climbing = true
	player.body_model.climb_phase = s
	_anchor_prev = anchor.global_position
	_anchor_v = Vector3.ZERO
	# both hands on unless it's a one-handed blade
	if player.armed and not _one_handed():
		player.sheathe_weapon(true)


func _local_yaw(a: Node3D, world_dir: Vector3) -> float:
	var d := a.global_basis.orthonormalized().inverse() * world_dir
	return atan2(-d.x, -d.z)


func _play(k: Array, then: String) -> void:
	keys = k
	total = float(k[k.size() - 1][0])
	t = 0.0
	_then = then


## A cutlass or a single axe: you can hold on with the other hand.
func _one_handed() -> bool:
	return player.equipped_weapon != null and player.style() in ["sword", "axe"]


func _bottom_y() -> float:
	return -_lad.length + 0.1


## Where your feet are at `at` metres up the climb (anchor-local).
func _line(at: float) -> Vector3:
	if _rig:
		return _rig.hold(clampf(at / maxf(_len, 0.01), 0.0, 1.0))
	return Vector3(0, _bottom_y() + clampf(at, 0.0, _len), 0.4)


func physics_update(delta: float) -> void:
	if anchor == null or not is_instance_valid(anchor) or (kind == "ledge" and keys.is_empty()):
		transitioned.emit(self, "Idle" if kind == "ledge" else "Fall", {})
		return
	_anchor_v = (anchor.global_position - _anchor_prev) / maxf(delta, 0.0001)
	_anchor_prev = anchor.global_position
	if not keys.is_empty():
		t += delta
		_place(_sample(minf(t, total)))
		_face(delta)
		if _then == "idle" and kind != "ledge" and t > total * 0.4:
			player.body_model.climbing = false
		if t < total:
			return
		keys.clear()
		if _then == "idle":
			transitioned.emit(self, "Idle", {})
			return
	_hang(delta)


## On the ladder / ratlines: climb, let go, jump off, fight one-handed.
func _hang(delta: float) -> void:
	var h := player.body_model
	h.climbing = true
	h.climb_hold = "l" if player.armed else ""
	if Input.is_action_just_pressed("jump"):
		_jump_off()
		return
	if Input.is_action_just_pressed("interact"):
		_let_go(0.8)
		return
	if Input.is_action_just_pressed("ready_weapon"):
		if player.armed:
			player.sheathe_weapon()
		elif _one_handed():
			player.draw_weapon()
		elif player.equipped_weapon != null:
			player.call("_toast", "You need a hand free to hold on")
	if input_buffer.consume_action("light_attack"):
		if player.armed and player.can_attack() and _chop_t < 0.0 and player.spend_stamina(player.LIGHT_COST):
			_chop_t = 0.0
			_hit_on = false
			player.set_reach("sword")
			h.play("climb_chop", CHOP_TIME)
		elif not player.armed and _one_handed():
			player.draw_weapon()
	input_buffer.consume_action("heavy_attack")
	_chop(delta)
	var mv := -get_movement_input().y
	if _chop_t >= 0.0:
		mv = 0.0
	var k := ARMED_MULT if player.armed else 1.0
	if mv > 0.1:
		s += mv * (LADDER_UP if _lad else RIG_UP) * k * delta
	elif mv < -0.1:
		s += mv * (LADDER_DOWN if _lad else RIG_DOWN) * k * delta
	if s >= _len and mv > 0.1:
		_over_top()
		return
	if s <= 0.0 and mv < -0.1:
		_off_bottom()
		return
	s = clampf(s, 0.0, _len)
	_place(_line(s))
	h.climb_phase = s
	_face(delta)


func _place(lp: Vector3) -> void:
	player.global_position = anchor.global_transform * lp
	player.velocity = Vector3.ZERO


## Facing the climb; armed, your right side turned out toward where you look.
func _face(delta: float) -> void:
	var f := anchor.global_basis.orthonormalized() * Vector3(-sin(_yaw_local), 0.0, -cos(_yaw_local))
	f.y = 0.0
	if f.length() < 0.1:
		return
	var yaw := atan2(-f.x, -f.z)
	if player.armed and keys.is_empty() and kind != "ledge":
		var cam := get_camera_forward()
		yaw += clampf(wrapf(atan2(-cam.x, -cam.z) - yaw, -PI, PI), -2.6, -1.05)
	player.player_model.rotation.y = lerp_angle(player.player_model.rotation.y, yaw, minf(14.0 * delta, 1.0)) if keys.is_empty() else yaw


func _chop(delta: float) -> void:
	if _chop_t < 0.0:
		return
	_chop_t += delta
	if _chop_t >= CHOP_ON and not _hit_on:
		_hit_on = true
		var hit := player.melee_hit(CHOP_DAMAGE)
		hit.hitstop_duration = 0.05
		hit.camera_shake_intensity = 0.1
		hit.knockback_force = 5.0
		hit.sever = true
		player.sword_hitbox.activate(hit)
		Net.fx("slash", [player.player_model, "overhead", 0.26, Player.HAKI_TRAIL if player.power.buff("coat") else Color(0.45, 0.75, 1.0)])
		Net.fx("sfx", ["whoosh", player.global_position, -6.0, 0.12, 1.0])
	if _chop_t >= CHOP_OFF:
		player.sword_hitbox.deactivate()
	if _chop_t >= CHOP_TIME:
		_chop_t = -1.0


## Away from what you're climbing (world, flat).
func _outward() -> Vector3:
	var f := anchor.global_basis.orthonormalized() * Vector3(-sin(_yaw_local), 0.0, -cos(_yaw_local))
	f.y = 0.0
	return -f.normalized() if f.length() > 0.01 else Vector3.ZERO


## Off the way you look: from the ratlines that can be in over the deck; from
## a ladder, not into the hull it hangs on.
func _jump_off() -> void:
	var dir := get_camera_forward()
	var out := _outward()
	if _lad and dir.dot(out) < 0.0:
		dir -= out * dir.dot(out)
	player.velocity = _anchor_v + dir * JUMP_OUT + Vector3.UP * JUMP_UP
	player.jumps_remaining = maxi(player.max_jumps - 1, 0)
	player.squash(3.5)
	Net.fx("sfx", ["jump", player.global_position, -8.0, 0.06])
	transitioned.emit(self, "Fall", {})


func _let_go(push: float) -> void:
	player.velocity = _anchor_v + _outward() * push
	player.jumps_remaining = maxi(player.max_jumps - 1, 0)
	transitioned.emit(self, "Fall", {})


func _over_top() -> void:
	var cur := _line(_len)
	if _rig:
		_play([[0.0, cur], [0.35, _rig.nest_gap()], [0.6, _rig.nest_spot()]], "idle")
	elif _lad.rail > 0.0:
		_play([[0.0, cur], [0.5, Vector3(0, _lad.rail + 0.12, -0.2)], [0.8, Vector3(0, 0.0, -_lad.deck_depth)]], "idle")
	else:
		_play([[0.0, cur], [0.35, Vector3(0, 0.1, -0.2)], [0.55, Vector3(0, 0.0, -_lad.deck_depth)]], "idle")
	player.sword_hitbox.deactivate()


func _off_bottom() -> void:
	if _rig:
		_play([[0.0, _line(0.0)], [0.35, _rig.deck_spot()]], "idle")
		return
	# the foot of a ladder is in the sea
	_let_go(0.3)


func _sample(time: float) -> Vector3:
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if time <= float(b[0]):
			var x := clampf((time - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)
			x = x * x * (3.0 - 2.0 * x)
			return (a[1] as Vector3).lerp(b[1], x)
	return keys[keys.size() - 1][1]


func exit() -> void:
	player.body_model.climbing = false
	player.body_model.climb_hold = ""
	player.sword_hitbox.deactivate()
	if _chop_t >= 0.0:
		player.body_model.stop_action()
	_chop_t = -1.0
	anchor = null
	_lad = null
	_rig = null
