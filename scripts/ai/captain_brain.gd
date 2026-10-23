class_name CaptainBrain
extends Node
## The captain-style AI's brain (docs/v1_19_plan.md: "fair but sharp"): a child of an AI Player, it thinks before the
## states every physics tick and sets the captain's BrainInput, pressing what a player would. It sees only what a
## player could: where its foe is and what they're doing (their state starting: a wind-up), never their input.
##   spacing - sprint in from far, circle at the weapon's reach, back off a step after a combo
##   offence - light chains on combo timing, a heavy now and then, skills off cooldown, the ultimate on an opening
##             (the foe staggered, down, or recovering from a swing that missed)
##   defence - a foe's attack starting, after a reaction time: dodge, parry or block, some of the time
## `skill` (0..1) sets the reaction time, how often it defends, and how hard it presses (a rookie vs the captain).

## 0 = a rookie, 1 = a captain at their best.
@export var skill := 0.5

var p: Player
var foe: Node3D
var rng := RandomNumberGenerator.new()
var mode := "approach"
## What it's doing and until when (physics ticks).
var _until := 0
var _strafe := 1.0
var _combo_left := 0
var _next_swing := 0
var _seen_attack := -1      # the tick it saw the foe's attack start
var _react_at := -1         # the tick it answers it
var _foe_state := ""
var _holding_block_until := 0
var _skill_at := 0
var _last_defence := ""
## How it answered the attacks it saw (dodge, parry, block, none): a count each.
var answers := {}
## Skills and ultimates it got off.
var casts := 0

const FOE_ATTACKS := ["LightAttack", "HeavyAttack", "Technique", "Skill", "Plunge", "Iai", "Shoot"]
## The ultimate waits for one of these (or a missed swing); combos only for a missed swing, never a stagger (no stunlocks).
const OPENINGS := ["Stagger"]
const SPRINT_FROM := 8.0


func _ready() -> void:
	p = get_parent() as Player
	process_physics_priority = -10
	rng.seed = hash([name, p.name if p else "", randi()])
	_strafe = 1.0 if rng.randf() < 0.5 else -1.0


func _now() -> int:
	return Engine.get_physics_frames()


func _ticks(secs: float) -> int:
	return int(round(secs * Engine.physics_ticks_per_second))


## Reach of its weapon (where it wants to stand to swing).
func reach() -> float:
	match p.weapon_class():
		"greatsword", "polearm":
			return 2.6
		"pistol", "rifle":
			return 7.0
		"dagger", "fist":
			return 1.6
	return 2.1


func _brain_input() -> CaptainInput.BrainInput:
	return p.inp as CaptainInput.BrainInput


func _physics_process(_d: float) -> void:
	if p == null or not p.is_inside_tree() or p.health_component.current_health <= 0.0:
		return
	var bi := _brain_input()
	if bi == null:
		return
	bi.move = Vector2.ZERO
	bi.hold("sprint", false)
	foe = _pick_foe()
	if foe == null:
		return
	var to := foe.global_position - p.global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 0.01:
		bi.yaw = atan2(-to.x, -to.z)
	if not p.armed and p.is_free() and dist < 25.0:
		p.toggle_weapon()
	_watch_foe(dist)
	if _defend(bi, dist):
		return
	if _cast(dist):
		return
	_move_and_swing(bi, dist)


## The nearest captain still standing.
func _pick_foe() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for c in get_tree().get_nodes_in_group("players"):
		if not (c is Player) or (c as Player).health_component.current_health <= 0.0 or (c as Player).bleeding:
			continue
		var d := (c as Node3D).global_position.distance_to(p.global_position)
		if d < bd:
			bd = d
			best = c
	return best


func _foe_state_name() -> String:
	return (foe as Player).current_state_name() if foe is Player else ""


## Sees the foe's attack start (a wind-up) and decides when it can answer: a reaction time by skill.
func _watch_foe(dist: float) -> void:
	var st := _foe_state_name()
	if st != _foe_state:
		if st in FOE_ATTACKS and dist < 6.0:
			_seen_attack = _now()
			_react_at = _now() + _ticks(lerpf(0.42, 0.16, skill) + rng.randf_range(0.0, 0.08))
		_foe_state = st


## Answer a seen attack: dodge, parry or block (or take it), by skill. True while defending.
func _defend(bi: CaptainInput.BrainInput, dist: float) -> bool:
	if _holding_block_until > _now():
		bi.hold("parry", true)
		return true
	bi.hold("parry", false)
	if _react_at < 0 or _now() < _react_at:
		return false
	_react_at = -1
	if not (_foe_state_name() in FOE_ATTACKS) or dist > 4.5 or not p.is_free() and p.current_state_name() not in ["LightAttack"]:
		return false
	var r := rng.randf()
	var dodge := lerpf(0.12, 0.45, skill)
	var parry := lerpf(0.04, 0.25, skill)
	var block := lerpf(0.15, 0.2, skill)
	if r < dodge:
		# sideways and a little back, out of the swing's line
		bi.move = Vector2(_strafe, 0.5).normalized()
		p.input_buffer.buffer_action("dodge")
		_last_defence = "dodge"
		answers[_last_defence] = int(answers.get(_last_defence, 0)) + 1
		_strafe = -_strafe if rng.randf() < 0.4 else _strafe
	elif r < dodge + parry:
		p.input_buffer.buffer_action("parry")
		_last_defence = "parry"
		answers[_last_defence] = int(answers.get(_last_defence, 0)) + 1
	elif r < dodge + parry + block:
		p.input_buffer.buffer_action("parry")
		_holding_block_until = _now() + _ticks(rng.randf_range(0.5, 0.9))
		_last_defence = "block"
		answers[_last_defence] = int(answers.get(_last_defence, 0)) + 1
	else:
		_last_defence = "none"
		answers[_last_defence] = int(answers.get(_last_defence, 0)) + 1
	return true


## Skills off cooldown when the foe is near; the ultimate on an opening. True if it cast.
func _cast(dist: float) -> bool:
	if _now() < _skill_at or not p.is_free() or dist > 9.0:
		return false
	_skill_at = _now() + _ticks(rng.randf_range(lerpf(5.0, 2.0, skill), lerpf(9.0, 4.0, skill)))
	var opening := _foe_state_name() in OPENINGS or _foe_recovering()
	if opening and p.power.can_cast(PowerComponent.ULT) == "" and p.power.try_cast(PowerComponent.ULT):
		casts += 1
		return true
	var slots := []
	for i in range(PowerComponent.SLOTS):
		if i != PowerComponent.ULT and p.power.loadout[i] != "" and p.power.can_cast(i) == "":
			slots.append(i)
	if slots.is_empty() or rng.randf() > lerpf(0.35, 0.7, skill):
		return false
	if p.power.try_cast(slots[rng.randi() % slots.size()]):
		casts += 1
		return true
	return false


## Close in, circle at reach, swing chains; a step back after.
func _move_and_swing(bi: CaptainInput.BrainInput, dist: float) -> void:
	var r := reach()
	if _combo_left > 0:
		if dist > r + 0.8:
			_combo_left = 0
		elif _now() >= _next_swing:
			_combo_left -= 1
			p.input_buffer.buffer_action("light_attack" if _combo_left > 0 or rng.randf() > lerpf(0.15, 0.35, skill) else "heavy_attack")
			_next_swing = _now() + _ticks(rng.randf_range(0.26, 0.4))
			if _combo_left == 0:
				mode = "back"
				_until = _now() + _ticks(rng.randf_range(0.5, 1.0))
		bi.move = Vector2(0, -0.4 if dist > r * 0.7 else 0.0)
		return
	if mode == "back" and _now() < _until:
		bi.move = Vector2(_strafe * 0.5, 1.0).normalized()
		return
	if dist > r + 0.6:
		mode = "approach"
		bi.move = Vector2(0, -1)
		bi.hold("sprint", dist > SPRINT_FROM)
		return
	# at reach: circle a moment, then go in (sooner the sharper it is, and at once on an opening)
	if mode != "circle":
		mode = "circle"
		_until = _now() + _ticks(rng.randf_range(lerpf(1.4, 0.6, skill), lerpf(2.6, 1.3, skill)))
	var opening := _foe_recovering()
	if _now() >= _until or opening:
		_combo_left = rng.randi_range(2, 3 + int(skill * 2.0))
		_next_swing = _now()
		return
	bi.move = Vector2(_strafe, -0.15 if dist > r * 0.8 else 0.25).normalized() * 0.7


## The foe just finished a swing (its state left an attack within the last moment): a window to punish.
func _foe_recovering() -> bool:
	return _seen_attack >= 0 and _now() - _seen_attack < _ticks(1.0) and not (_foe_state_name() in FOE_ATTACKS)
