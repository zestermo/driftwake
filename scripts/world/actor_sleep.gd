class_name ActorSleep
extends Node
## Puts enemies, villagers and enemy ships far from every captain to sleep: the actor's node goes
## PROCESS_MODE_DISABLED (no AI, no move_and_slide, its bodies and hurtbox out of the physics space,
## no rig), so it wakes exactly where and how it was, its timers where they stopped. Farther out a
## sleeper is hidden too. Each actor joins with ActorSleep.add(self) and says when it may sleep
## (sleep_ok(): not fighting, not on the ground, not boarding). Judged against every captain,
## a slice of the actors each frame. The host decides for synced enemies (asleep: net_idle, no
## snapshots); a guest's puppet sleeps while the host sends nothing for it and wakes with the next one.

## [sleep past, wake within, hide past, show within] (m)
const PEOPLE := [160.0, 120.0, 230.0, 210.0]
## Ships sleep only well past where they'd notice the crew's ship (EnemyShip.NOTICE, LOSE) and stay in sight.
const SHIP := [420.0, 340.0, INF, INF]
## Every actor is looked at once every this many frames.
const SLICES := 8
## A guest's puppet: asleep once the host has sent nothing for this long, awake on a snapshot this fresh.
const STALE := 0.6
const FRESH := 0.3

## Off (the bench's nosleep run): everyone wakes and stays awake.
static var enabled := true
static var _mgr: ActorSleep
static var _all: Array = []

var _i := 0
var _caps: Array = []


static func add(actor: Node3D, radii: Array = PEOPLE) -> void:
	_all.append({"n": actor, "r": radii, "asleep": false, "hid": false})
	if _mgr == null or not is_instance_valid(_mgr):
		_mgr = ActorSleep.new()
		_mgr.name = "ActorSleep"
		actor.get_tree().root.add_child.call_deferred(_mgr)


static func asleep(actor: Node) -> bool:
	for e in _all:
		if e["n"] == actor:
			return bool(e["asleep"])
	return false


func _process(_delta: float) -> void:
	if not enabled:
		for e in _all:
			if is_instance_valid(e["n"]) and bool(e["asleep"]):
				_wake(e)
		return
	_caps.clear()
	for p in Net.all_players():
		_caps.append((p as Node3D).global_position)
	# (no captain in the world: a tool or the title screen, nobody to judge by)
	if _caps.is_empty() or _all.is_empty():
		return
	var n := ceili(_all.size() / float(SLICES))
	while n > 0 and not _all.is_empty():
		if _i >= _all.size():
			_i = 0
		var e: Dictionary = _all[_i]
		if not is_instance_valid(e["n"]):
			_all.remove_at(_i)
			continue
		_i += 1
		n -= 1
		_check(e)


func _check(e: Dictionary) -> void:
	var a := e["n"] as Node3D
	if not a.is_inside_tree():
		return
	if a.has_method("is_dead") and a.is_dead():
		# (a body sinks away and frees itself)
		if bool(e["asleep"]):
			_wake(e)
		return
	var d := INF
	for q in _caps:
		d = minf(d, a.global_position.distance_to(q))
	var r: Array = e["r"]
	if Net.is_client() and a.is_in_group("net_sync"):
		var age := Net.snapshot_age(a)
		if bool(e["asleep"]) and age < FRESH:
			_wake(e)
		elif not bool(e["asleep"]) and age > STALE and d > float(r[1]):
			_sleep(e)
	elif bool(e["asleep"]) and d < float(r[1]):
		_wake(e)
	elif not bool(e["asleep"]) and d > float(r[0]) and a.sleep_ok():
		_sleep(e)
	if bool(e["asleep"]) and a.process_mode != Node.PROCESS_MODE_DISABLED:
		a.process_mode = Node.PROCESS_MODE_DISABLED
	var hide := bool(e["asleep"]) and d > float(r[3] if bool(e["hid"]) else r[2])
	if hide and not bool(e["hid"]) and a.visible:
		a.visible = false
		e["hid"] = true
	elif not hide and bool(e["hid"]):
		a.visible = true
		e["hid"] = false


func _sleep(e: Dictionary) -> void:
	var a := e["n"] as Node3D
	e["asleep"] = true
	a.process_mode = Node.PROCESS_MODE_DISABLED
	a.set("net_idle", true)


func _wake(e: Dictionary) -> void:
	var a := e["n"] as Node3D
	e["asleep"] = false
	a.process_mode = Node.PROCESS_MODE_INHERIT
	a.set("net_idle", false)
	if bool(e["hid"]):
		a.visible = true
		e["hid"] = false
