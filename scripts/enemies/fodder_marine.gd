class_name FodderMarine
extends PirateGrunt
## The stronghold's fodder (1.30, docs/v1_30_plan.md round 3: "20-30 fighting at once, most a cheap fodder tier"): an
## Admiralty marine LEVEL_GAP levels under its camp (no +30%, no co-op health scaling), a cutlass and a short
## moveset (the two-cut combo, the lunge from further out, now and then the red chop), no pistol, rush, shield, horn
## or elite trait. Its rig stays on the lod path in a fight and it thinks on a slower beat. A hunter (sent by the
## alarm: StrongholdAlarm) goes for the nearest captain as it musters and follows them across the fortress instead of
## minding a post. A sentry (StrongholdGarrison) is a fodder marine posted to watch a way in.

## (1.30 round 5, the level gap) A marine's own numbers (no +30%) at the fortress's level less this: the gap does the
## rest (a captain at the fortress's level hits it x1.24, takes x0.52 from it, its poise x0.52).
const LEVEL_GAP := 4
const HUNT_RANGE := 90.0
const THINK := 10
const XP_K := 0.35
const PERIL_ODDS := 0.25
const LUNGE_ODDS := 0.5

## (piece 2) A captain sneaking (Crouch) up behind an unaware one within TAKEDOWN_R takes him down with one blow, silently.
const TAKEDOWN_R := 2.4
## A bell's runner rings it this long at the rope before the alarm is up (StrongholdBell, StrongholdAlarm).
const RING_SECS := 2.0
const RUN_STATES := [S.IDLE, S.ALERT, S.CHASE, S.CIRCLE, S.CLOSE, S.KEEP, S.RETURN, S.REPOSITION, S.RECOVER]

var hunt := false
var sentry := false
## (host) The bell he's running for, how long he's rung it, and whether he got the alarm out.
var bell: Node3D
var rang := false
var _ring_t := 0.0
var _silent := false
## Where he looked while still unaware (a takedown in the moment he turns still counts as from behind).
var _calm_fwd := Vector3.FORWARD
const SHOUT_AFTER := 0.7
const TURNING := 0.6


func setup(cfg: Dictionary) -> PirateGrunt:
	super(cfg)
	hunt = bool(cfg.get("hunt", false))
	sentry = bool(cfg.get("sentry", false))
	horn = false
	return self


func _ready() -> void:
	if level > 0:
		level = maxi(level - LEVEL_GAP, 1)
	super()
	add_to_group("fodder")
	# (a crowd pressing on one captain: bodies pushing bodies were most of its physics; they keep apart by steering)
	collision_layer = 4
	collision_mask = 1 | 2
	if hunt and not net_puppet:
		alert.call_deferred(0.15)


## Between thinks (moving about, no blow or guard on the line), only the move: gravity and on along its last decision.
## The skipped time goes into the next full tick's clocks.
var _skip_dt := 0.0


## (host) Off to ring `b` (a StrongholdBell): out of the fight and running for it, shouting.
func run_to_bell(b: Node3D) -> void:
	bell = b
	_ring_t = 0.0
	hunt = true
	humanoid.seated = false
	_release_token()
	bark(["The bell! Ring the bell!", "Sound the alarm!", "To the bell, quick!"], 1.0)
	if state in [S.IDLE, S.RETURN]:
		_set_state(S.CHASE)


func _physics_process(delta: float) -> void:
	if state == S.IDLE:
		_calm_fwd = _fwd()
	if bell != null and not net_puppet and state in RUN_STATES:
		_run_bell(delta)
		return
	if not net_puppet and state in THINK_STATES and _yank <= 0.0 and _slow_t <= 0.0 \
			and (Engine.get_physics_frames() + get_instance_id()) % THINK != 0:
		_skip_dt += delta
		if is_on_floor() and velocity.y < 0.0:
			velocity.y = -0.5
		else:
			velocity.y -= GRAVITY * delta
		_move_tail(_last_want, _last_accel, _last_turn, _last_running, _flat(velocity), delta)
		return
	super(delta + _skip_dt)
	_skip_dt = 0.0


## Noticing a captain, he shouts to the others only SHOUT_AFTER s later: cut down before then, nobody else heard.
func alert(delay: float = 0.0) -> void:
	if delay > 0.0 or state not in [S.IDLE, S.RETURN] or _holding():
		super(delay)
		return
	var c := camp
	camp = null
	super(0.0)
	camp = c
	get_tree().create_timer(SHOUT_AFTER, false, true).timeout.connect(func():
		if is_instance_valid(self) and not is_dead() and camp and is_instance_valid(camp):
			camp.call("alert_all", global_position))


func _run_bell(delta: float) -> void:
	st_t += delta
	_bark_t -= delta
	if _bark_t <= 0.0:
		_bark.visible = false
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	if not is_instance_valid(bell) or bell.call("cut"):
		bell = null
		return
	if state != S.CHASE:
		_set_state(S.CHASE)
	var spot: Vector3 = bell.call("ring_spot")
	var to := _flat(spot - global_position)
	if to.length() > 1.3:
		var nd := _nav_dir(spot, delta)
		_face(nd)
		_move_tail(nd * RUN_SPEED * 1.1, 24.0, 12.0, true, _flat(velocity), delta)
		return
	_face(_flat(bell.global_position - global_position))
	_move_tail(Vector3.ZERO, 24.0, 12.0, false, _flat(velocity), delta)
	var before := _ring_t
	_ring_t += delta
	if int(before / 0.7) != int(_ring_t / 0.7) or before == 0.0:
		humanoid.play("draw", 0.4)
		Net.fx("sfx", ["bell", bell.global_position + Vector3.UP * 3.0, 3.0, 0.02, 0.9])
	if _ring_t >= RING_SECS:
		rang = true
		bell = null


## Hit while unaware by a captain sneaking up from behind: a silent takedown (no shout, nobody near alerted).
func _on_hit(hit: HitData, attacker: Node) -> void:
	var unaware := state == S.IDLE or (state == S.ALERT and st_t < TURNING)
	var from_sneak := unaware and (hit.sneak or Stealth.sneaking(attacker)) and attacker is Node3D \
		and Stealth.behind(attacker as Node3D, global_position, _calm_fwd)
	# (1.30 gadgets) dazed by flash powder or blinded in smoke: from any side, sneaking or not
	if (from_sneak or is_stunned()) and not hit.ranged and not hit.dot and attacker is Node3D and (attacker as Node3D).is_in_group("players") \
			and global_position.distance_to((attacker as Node3D).global_position) < TAKEDOWN_R:
		_takedown(attacker as Node3D)
		return
	super(hit, attacker)


func _takedown(by: Node3D) -> void:
	_silent = true
	_hit_by = by
	var dir := _flat(global_position - by.global_position).normalized()
	set_meta("last_dir", dir * 0.2)
	humanoid.start_ragdoll(dir * 1.2 + Vector3.DOWN * 0.5, Vector3.ZERO, false)
	Net.fx("sfx", ["punch", global_position + Vector3.UP, -10.0, 0.05, 0.8])
	Net.fx("float_text", [global_position + Vector3(0, 2.2, 0), "Takedown", Color(0.75, 0.8, 0.9)])
	health.take_damage(health.current_health + 1.0)


func bark(lines: Array, chance: float = 1.0) -> void:
	if _silent:
		return
	super(lines, chance)


func _roll_role() -> void:
	pass


func _roll_extras() -> void:
	pass


func elite() -> bool:
	return false


func _crew_k() -> float:
	return 1.0


func net_rescale(_k: float) -> void:
	super(1.0)


func _can_rush() -> bool:
	return false


func _want_pistol(_p: Node3D, _dist: float, _delta: float) -> bool:
	return false


func _choose_attack(dist: float) -> String:
	var a := "combo"
	if _peril_cd <= 0.0 and _rng.randf() < PERIL_ODDS:
		_peril_cd = _rng.randf_range(10.0, 16.0)
		a = "peril"
	elif dist > 2.9 and _rng.randf() < LUNGE_ODDS:
		a = "lunge"
	_last_attack = a
	return a


func _think_skip(delta: float) -> bool:
	if state not in THINK_STATES or _yank > 0.0:
		_think_acc = 0.0
		return false
	if (Engine.get_physics_frames() + get_instance_id()) % THINK != 0:
		_think_acc += delta
		return true
	return false


## The sea and fire check once a think, not every tick (the same want comes back on the ticks between).
var _aw_in := Vector3.INF
var _aw_out := Vector3.ZERO
var _aw_tick := -100


func _avoid_water(want: Vector3) -> Vector3:
	var f := Engine.get_physics_frames()
	if want == _aw_in and f - _aw_tick < THINK:
		return _aw_out
	_aw_in = want
	_aw_tick = f
	_aw_out = super(want)
	return _aw_out


func _feed_body(hv: Vector3, running: bool) -> void:
	super(hv, running)
	humanoid.lod = true
	humanoid.crowd = state not in [S.WIND, S.SWING, S.GRAB]


func _lost(p: Node3D, dist: float) -> bool:
	if not hunt:
		return super(p, dist)
	if p == null or dist > HUNT_RANGE:
		return true
	return not _player_ok(p) and str(p.call("current_state_name")) != "Downed" and st_t > 4.0


func _go_home() -> void:
	if hunt:
		post = global_position
	super()


func _xp(base: float) -> int:
	return super(base * XP_K)


func _coins(n: int) -> int:
	return maxi(1, super(n) / 2)
