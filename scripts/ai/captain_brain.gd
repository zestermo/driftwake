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
## After a dodge, parry or block it can't answer again until this tick (1.23: it turtled behind back-to-back
## defences; now a pressed captain gets hits in between).
var _no_defend_until := 0
var _skill_at := 0
var _last_defence := ""
## How it answered the attacks it saw (dodge, parry, block, none): a count each.
var answers := {}
## Skills and ultimates it got off.
var casts := 0
## Orders from a crew fight (RivalEncounter): "fight" (its foe: `target`, or the nearest captain), "watch" (ring the
## duel `watch_r` m from `watch_center`, facing it, no blows), "rest" (a waiting crewmate: walk to `rest_at`, settle
## facing `look_node` and keep at `activity`, the head on the fight), "flee" (sprint for `flee_to`), "hold" (stand).
var order := "fight"
var target: Node3D
var watch_center: Node3D
var watch_r := 9.0
var flee_to := Vector3.ZERO
## "rest": what it does while it waits. "watch" stands and follows the fight with its head; the rest are side work
## (REST_KINDS: drills, a book, tinkering, an instrument, sat on the ground) with a glance up now and then.
const REST_KINDS := ["train", "read", "tinker", "music", "sit"]
var rest_at := Vector3.INF
var activity := "watch"
var look_node: Node3D
var _settled := false
var _rest_ticks := 0
var _glance_until := 0
var _next_glance := 0
## Walking to its spot gives up (settles where it stands) after this long: a rock or a wall in the way.
const REST_WALK_S := 8.0

const FOE_ATTACKS := ["LightAttack", "HeavyAttack", "Technique", "Skill", "Plunge", "Iai", "Shoot"]
## The ultimate waits for one of these (or a missed swing); combos only for a missed swing, never a stagger (no stunlocks).
const OPENINGS := ["Stagger"]
const SPRINT_FROM := 8.0
## Its plan is made every THINK_EVERY ticks (~10 Hz); the stick it last chose is held in between.
const THINK_EVERY := 6
var _last_move := Vector2.ZERO
var _last_sprint := false


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
	if Cutscene.active:
		bi.hold("parry", false)
		return   # (a scene playing: it holds still, like the captains)
	bi.hold("parry", _holding_block_until > _now())
	if order != "rest" and (_settled or _rest_ticks > 0):
		_unsettle()
	match order:
		"hold":
			return
		"flee":
			_flee(bi)
			return
		"rest":
			_rest(bi)
			return
	foe = target if target and is_instance_valid(target) and _standing(target) else _pick_foe()
	if foe == null:
		return
	var to := foe.global_position - p.global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 0.01:
		bi.yaw = atan2(-to.x, -to.z)
	if not p.armed and p.is_free() and dist < 25.0:
		p.toggle_weapon()
	if order == "watch":
		_watch(bi)
		return
	_watch_foe(dist)
	if _defend(bi, dist):
		return
	# (the plan, skills and footwork at ~10 Hz, staggered by instance, holding the last stick in between; seeing an
	# attack and defending stay every tick: 1.23 perf track)
	if (_now() + get_instance_id()) % THINK_EVERY != 0:
		bi.move = _last_move
		bi.hold("sprint", _last_sprint)
		return
	var t0 := Time.get_ticks_usec()
	if not _cast(dist):
		_move_and_swing(bi, dist)
	_last_move = bi.move
	_last_sprint = bi.held.get("sprint", false)
	Perf.add_us(Perf.AI, Time.get_ticks_usec() - t0)


func _standing(c: Node3D) -> bool:
	return c is Player and (c as Player).health_component.current_health > 0.0 and not (c as Player).bleeding \
		and (c as Player).current_state_name() != "Downed"


## Ring the duel at watch_r, drifting round it, facing the fight (the stick: toward/away to hold the ring, sideways
## to drift).
func _watch(bi: CaptainInput.BrainInput) -> void:
	var c := watch_center if watch_center and is_instance_valid(watch_center) else foe
	var off := p.global_position - c.global_position
	off.y = 0.0
	var d := off.length()
	var radial := clampf((d - watch_r) / 3.0, -1.0, 1.0)   # + = too far: in (stick forward faces the foe)
	bi.move = Vector2(_strafe * 0.35, -radial).limit_length(1.0)


## Waiting its turn: to its spot, then settled at its activity, facing the fight.
func _rest(bi: CaptainInput.BrainInput) -> void:
	_rest_ticks += 1
	if not _settled:
		var to := rest_at - p.global_position
		to.y = 0.0
		if rest_at != Vector3.INF and to.length() > 0.5 and _rest_ticks < _ticks(REST_WALK_S):
			if p.armed and p.is_free():
				p.sheathe_weapon(true)
			bi.yaw = atan2(-to.x, -to.z)
			bi.move = Vector2(0, -clampf(to.length() / 2.0, 0.3, 0.55))
			return
		if not p.is_free() or not p.is_on_floor():
			return
		_settle()
	_face_fight()
	_look_at_fight()
	# (back to the loop after a one-off: a reaction, a flinch)
	if activity in ["train", "read", "tinker"] and p.body_model.current_action() == "":
		p.body_model.hold(Downtime.pose_of(p, activity), 0.25)


func _settle() -> void:
	_settled = true
	p.velocity = Vector3.ZERO
	match activity:
		"train":
			if not p.armed:
				p.draw_weapon(true)
			p.body_model.hold(Downtime.pose_of(p, "train"), 0.4)
		"read", "tinker":
			p.body_model.seated = true
			p.body_model.seat_y = Downtime.seat_of(activity)
			p.body_model.hold(Downtime.pose_of(p, activity), 0.4)
		"sit":
			p.sit_ground()
		"music":
			p.jam.start()
	_next_glance = _now() + _ticks(rng.randf_range(2.0, 6.0))


## Called in (its turn, the retreat): up from whatever it was doing.
func _unsettle() -> void:
	if _settled:
		match activity:
			"music":
				p.jam.stop()
			"sit":
				if p.current_state_name() == "Sit":
					p.state_machine.force_state("Idle", {})
			"read", "tinker", "train":
				p.body_model.seated = false
				if p.body_model.current_action() == Downtime.pose_of(p, activity):
					p.body_model.stop_action()
	_settled = false
	_rest_ticks = 0
	p.body_model.look_weight = 0.0


## Eased round to face the fight (an activity faces it too: the crew on the side, all turned to the duel).
func _face_fight() -> void:
	if look_node == null or not is_instance_valid(look_node) or activity == "sit":
		return
	var d := look_node.global_position - p.global_position
	d.y = 0.0
	if d.length() < 0.5:
		return
	var want := atan2(-d.x, -d.z)
	p.player_model.rotation.y = lerp_angle(p.player_model.rotation.y, want, 0.06)


## The head on the fight: always for a watcher, now and then (a glance up) for the rest.
func _look_at_fight() -> void:
	var b := p.body_model
	if look_node == null or not is_instance_valid(look_node):
		b.look_weight = 0.0
		return
	b.look_target = look_node.global_position + Vector3.UP * 1.4
	var now := _now()
	if activity != "watch" and now >= _next_glance:
		_glance_until = now + _ticks(rng.randf_range(1.2, 2.4))
		_next_glance = _glance_until + _ticks(rng.randf_range(3.0, 8.0))
	var want := 1.0 if activity == "watch" or now < _glance_until else 0.0
	b.look_weight = move_toward(b.look_weight, want, 0.06)


## Something big in the duel: "down" (a mate beaten), "turn" (their captain steps up), "ult" (an ultimate). Resting,
## it looks up; a watcher answers it (a facepalm for a mate down, a cheer for the captain's turn).
func react(what: String) -> void:
	if order != "rest" or not _settled:
		return
	_glance_until = _now() + _ticks(rng.randf_range(2.0, 3.0))
	if activity != "watch" or not p.is_free():
		return
	match what:
		"down":
			if rng.randf() < 0.6:
				p.emote("facepalm")
		"turn":
			p.emote("cheer")


## Run for flee_to (the ship), sprinting; the yaw faces it.
func _flee(bi: CaptainInput.BrainInput) -> void:
	var to := flee_to - p.global_position
	to.y = 0.0
	if to.length() < 1.0:
		return
	bi.yaw = atan2(-to.x, -to.z)
	bi.move = Vector2(0, -1)
	bi.hold("sprint", true)


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
	if _now() < _no_defend_until:
		answers["none"] = int(answers.get("none", 0)) + 1
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
	if _last_defence != "none":
		_no_defend_until = _now() + _ticks(lerpf(1.8, 1.0, skill))
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
