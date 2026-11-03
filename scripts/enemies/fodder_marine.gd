class_name FodderMarine
extends PirateGrunt
## The stronghold's fodder (1.30, docs/v1_30_plan.md round 3: "20-30 fighting at once, most a cheap fodder tier"): an
## Admiralty marine that drops in 2-4 blows (HP of its own: no +30%, no co-op health scaling), a cutlass and a short
## moveset (the two-cut combo, the lunge from further out, now and then the red chop), no pistol, rush, shield, horn
## or elite trait. Its rig stays on the lod path in a fight and it thinks on a slower beat. A hunter (sent by the
## alarm: StrongholdAlarm) goes for the nearest captain as it musters and follows them across the fortress instead of
## minding a post. A sentry (StrongholdGarrison) is a fodder marine posted to watch a way in.

const HP := 40.0
const HUNT_RANGE := 90.0
const THINK := 8
const XP_K := 0.35
const PERIL_ODDS := 0.25
const LUNGE_ODDS := 0.5

var hunt := false
var sentry := false


func setup(cfg: Dictionary) -> PirateGrunt:
	super(cfg)
	hunt = bool(cfg.get("hunt", false))
	sentry = bool(cfg.get("sentry", false))
	horn = false
	return self


func _ready() -> void:
	super()
	add_to_group("fodder")
	if hunt and not net_puppet:
		alert.call_deferred(0.15)


func _roll_role() -> void:
	pass


func _roll_extras() -> void:
	pass


func elite() -> bool:
	return false


func _crew_k() -> float:
	return 1.0


func _max_hp() -> float:
	return HP * Levels.hp_k(level, _lv_ref())


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


func _feed_body(hv: Vector3, running: bool) -> void:
	super(hv, running)
	humanoid.lod = true


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
