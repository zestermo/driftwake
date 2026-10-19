extends PlayerState
## Swimming at the surface. You float with your head above the waves and
## stroke around (Shift: faster but hungrier on stamina; a tap of it is a burst
## of strokes). Space pulls you up onto a ledge or a rock in front of you (the
## prompt says when one's in reach) or up a ladder; swim into a ladder and you
## take hold. At a sprint with nothing to climb, Space is a dolphin leap.
## Swimming slowly drains stamina and treading water lets it creep back; run
## the bar dry and you're exhausted: a slow float-paddle (no sprint, no dive)
## until you've got your breath back. No damage.
##
## Diving (Ctrl): a duck dive under, then you swim free below the waves: hold
## Ctrl to go deeper, Space to kick for the surface, neither and you drift
## slowly up. Under water you hold your breath (`breath`, the HUD's meter);
## at the surface it comes back fast. Run out on a dive and you take steady
## damage until your head is out (warned at a third left, and again at empty).
##
## The sea pushes back (SeaPush): rip currents off beaches carry you out (swim along the shore to break
## free), the surf shoves you in on each breaking crest, a storm's swell carries you and wears you out, and
## the water round a snow island is cold enough to sap your stamina.
##
## Devil Fruit users can't swim at all: the sea drags them under. They sink,
## struggling weakly, can trudge along the bottom, and drown (health drains
## fast once the head is under) unless they reach shallow water or a ladder.

const SWIM_SPEED := 3.2
const FAST_SPEED := 4.6
const TIRED_SPEED := 1.1
const ACCEL := 9.0
const DRAIN := 3.5
const FAST_DRAIN := 13.0
const DIVE_COST := 6.0
const DIVE_SPEED := 3.0
const DESCEND := 2.6
const ASCEND := 3.4
const DRIFT_UP := 0.9
const DIVE_VACCEL := 9.0
## The duck dive's push down, and how long before you can come back up through the surface.
const DIVE_KICK := 3.6
const DIVE_MIN := 0.4
## Seconds of breath on a dive (Swimming perks add breath_pct), refilled at BREATH_REFILL/s with the head out.
const BREATH := 20.0
const BREATH_REFILL := 9.0
## Sprinting under water spends breath this much faster.
const FAST_BREATH := 1.6
## Warned with this share of breath left.
const BREATH_WARN := 0.3
## Out of breath: this share of max health a second, in ticks of GASP_TICK s, until the head's out.
const GASP_DPS := 0.06
const GASP_TICK := 0.5
const TREAD_REGEN := 0.15
## Exhausted: a slow float-paddle, stamina creeping back at this share of its regen.
const FLOAT_REGEN := 0.25
## Exhausted until stamina is back to this.
const RECOVER := 30.0
## Ledges and rocks you can pull yourself onto: top this high above the water at most (a high one is a
## harder haul: ClimbState's "high" mantle).
const LEDGE_MAX := 2.2
const LEDGE_HIGH := 1.4
## Strokes: a tap of Shift is a burst (DASH_SPEED for DASH_TIME s, DASH_COST stamina, again after DASH_CD);
## held under water, the dolphin kick; Space at a sprint on top with nothing to climb, a dolphin leap.
const DASH_SPEED := 7.2
const DASH_TIME := 0.32
const DASH_COST := 12.0
const DASH_CD := 0.7
const DOLPHIN_SPEED := 5.0
const LEAP_VY := 8.2
const LEAP_FWD := 5.5
const LEAP_GRAVITY := 20.0
const LEAP_COST := 10.0
var _dash_t: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir := Vector3.ZERO
## Seconds into a dolphin leap (< 0: not leaping).
var _leap_t: float = -1.0
var _ledge := {}
var _ledge_t: float = 0.0
var _prompt := ""

var _vy: float = 0.0
var _diving: bool = false
var _dive_t: float = 0.0
var _tick: float = 0.0
var _warned: bool = false
var _ripple_t: float = 0.0
var _stroke_t: float = 0.0
var _move_blend: float = 0.0
var _exhausted: bool = false
var _prev_target: float = INF
## Seconds of breath left (the HUD's meter reads it with breath_max()).
var breath: float = BREATH
## Out of breath on a dive right now.
var gasping: bool = false
var _gasp_t: float = 0.0
var _breath_warned: bool = false
var _head_under: bool = false
var _cam_under: bool = false
# the sea pushing back (SeaPush): rips, surf, storm swell; cold water round a snow island
const SEA_PUSH := preload("res://scripts/swim/sea_push.gd")
## How fast the drift you're carried by follows the sea's push (1/s).
const DRIFT_EASE := 3.0
## Under water the surf and the swell carry you this much (currents run deep).
const DEEP_PUSH := 0.35
## How cold the water is here (0..1; the HUD shows it), and the storm's strength.
var cold: float = 0.0
var storm: float = 0.0
## Seconds left of a jellyfish sting's slower stroke (SeaThreats sets it).
var stung: float = 0.0
const STUNG_SLOW := 0.55
var _drift := Vector3.ZERO
var _crest: float = 0.0
var _sea_t: float = 0.0
var _told := {}
# the sea's curse
const SINK_SPEED := 1.6
const SEABED_SPEED := 1.5
const DROWN_GRACE := 1.0
const DROWN_DPS := 10.0
var _cursed: bool = false
var _under_t: float = 0.0
var _bubble_t: float = 0.0


func enter(data: Dictionary) -> void:
	player.sheathe_weapon(true)
	player.sprinting = false
	player.is_parrying = false
	player.reset_combo()
	player.sword_hitbox.deactivate()
	player.jumps_remaining = player.max_jumps
	player.body_model.stop_action()
	player.body_model.swimming = true
	player.body_model.diving = false
	var vy_in := float(data.get("entry_vy", 0.0))
	_vy = minf(vy_in, 0.0) * 0.45
	_diving = false
	gasping = false
	_breath_warned = false
	_tick = 0.0
	_warned = false
	_exhausted = player.stamina <= 0.0
	_move_blend = 0.0
	_prev_target = INF
	_drift = Vector3.ZERO
	_told.clear()
	_sea_t = 0.0
	_dash_t = 0.0
	_leap_t = -1.0
	_ledge = {}
	_ledge_t = 0.0
	_cursed = player.power.has_fruit()
	_under_t = 0.0
	if _cursed:
		player.call("_toast", "The sea drags you under! Get to shallow water")
	var surf := player.water_surface()
	var at := Vector3(player.global_position.x, surf, player.global_position.z)
	if data.get("quiet", false):
		Net.fx("splash", [at, 3, 0.5])
	elif vy_in < -5.0:
		Net.fx("splash", [at, 12, 1.0])
		Net.fx("dust_ring", [at, 10, 0.8])
		Net.fx("sfx", ["splash", at, -2.0, 0.08, 0.85])
	else:
		Net.fx("splash", [at, 5, 0.7])
		Net.fx("sfx", ["splash", at, -8.0, 0.1, 1.1])


func physics_update(delta: float) -> void:
	var input := get_movement_input()
	var dir := get_camera_relative_direction(input) if input.length() > 0.1 else Vector3.ZERO
	if _cursed:
		_sink_update(delta, dir)
		return
	# run the bar dry and you're exhausted until it's back to a quarter
	if player.stamina <= 0.5:
		_exhausted = true
	elif player.stamina >= RECOVER:
		_exhausted = false
	var tired := _exhausted
	var fast := Input.is_action_pressed("sprint") and not tired and dir != Vector3.ZERO
	var spd := TIRED_SPEED if tired else (FAST_SPEED if fast else SWIM_SPEED)
	if _diving:
		spd = DOLPHIN_SPEED if fast else DIVE_SPEED
	var swim_k := 1.0 + player.progression.stat("swim_pct")
	spd *= clampf(input.length(), 0.0, 1.0) * swim_k
	if stung > 0.0:
		stung -= delta
		spd *= STUNG_SLOW
	# your own stroke, apart from the drift the sea carries you on
	var hv := Vector3(player.velocity.x, 0.0, player.velocity.z) - _drift
	hv = hv.move_toward(dir * spd, ACCEL * delta)
	_dash_cd -= delta
	# a tap of Shift: a burst of strokes (on top, or a dolphin kick under), then on at a sprint while it's held
	if Input.is_action_just_pressed("sprint") and dir != Vector3.ZERO and not tired and _dash_cd <= 0.0 and _leap_t < 0.0 \
			and player.spend_stamina(DASH_COST):
		_dash_t = DASH_TIME
		_dash_cd = DASH_CD
		_dash_dir = dir
		var at := _surface_point() if not _diving else player.global_position + Vector3(0, 0.8, 0)
		if _diving:
			Net.fx("bubbles", [at, 10])
		else:
			Net.fx("spray", [at + dir * 0.5, (dir + Vector3.UP * 0.5).normalized(), 10, Color(0.9, 0.96, 1.0), 4.0])
		Net.fx("sfx", ["swim_stroke", player.global_position, -4.0, 0.1, 0.8])
	if _dash_t > 0.0:
		_dash_t -= delta
		hv = _dash_dir * DASH_SPEED * swim_k
	_sea(delta)

	# duck dive (Ctrl), then free under water until you come back up through the surface
	if not _diving and Input.is_action_just_pressed("dodge") and not tired and player.spend_stamina(DIVE_COST):
		_diving = true
		_dive_t = 0.0
		_vy = -DIVE_KICK
		var at := _surface_point()
		Net.fx("splash", [at, 6, 0.7])
		Net.fx("sfx", ["splash", at, -6.0, 0.1, 0.9])
	if _diving:
		_dive_t += delta
		var want := DRIFT_UP
		if tired:
			want = ASCEND * 0.6
		elif Input.is_action_pressed("jump"):
			want = ASCEND
		elif Input.is_action_pressed("dodge"):
			want = -DESCEND
		_vy = move_toward(_vy, want, DIVE_VACCEL * delta)
		if _dive_t > DIVE_MIN and want > 0.0 and player.global_position.y >= _float_y(false) - 0.08:
			_surface()
	player.body_model.diving = _diving
	_update_breath(delta, fast)

	# stamina: strokes cost a little, treading water lets it creep back; cold water and a storm's swell sap it
	# (worn out, the cold only slows it coming back: a swimmer always gets their breath in the end)
	var resist := 1.0 - player.progression.stat("sea_resist")
	var sap := (cold * SEA_PUSH.COLD_DRAIN + storm * SEA_PUSH.STORM_DRAIN) * resist
	if _exhausted:
		player.stamina_regen_mult = FLOAT_REGEN * (1.0 - cold * SEA_PUSH.COLD_REGEN * resist)
	elif dir != Vector3.ZERO or sap > 0.05:
		player.drain_stamina(((FAST_DRAIN if fast else DRAIN) if dir != Vector3.ZERO else 0.0) * delta + sap * delta)
		player.stamina_regen_mult = 0.0
	else:
		player.stamina_regen_mult = TREAD_REGEN

	if _exhausted:
		if not _warned:
			_warned = true
			player.call("_toast", "Exhausted! Float and catch your breath")
	else:
		_warned = false

	# float: hips near the surface, head above it (deeper while diving)
	_move_blend = move_toward(_move_blend, clampf(hv.length() / SWIM_SPEED, 0.0, 1.0), delta * 3.0)
	var target := _float_y(tired)
	var y := player.global_position.y
	# ride the swell: follow the surface's own rise and fall (feed-forward)
	# so the head doesn't lag under a rising wave
	var target_v := 0.0 if _prev_target == INF else clampf((target - _prev_target) / maxf(delta, 0.0001), -6.0, 6.0)
	_prev_target = target
	if _leap_t >= 0.0:
		# a dolphin leap: out of the water in an arc, head first back in
		_leap_t += delta
		_vy -= LEAP_GRAVITY * delta
		hv = hv.lerp(_dash_dir * LEAP_FWD * swim_k, clampf(4.0 * delta, 0.0, 1.0))
		if _leap_t > 0.25 and _vy < 0.0 and y <= target:
			_leap_t = -1.0
			player.body_model.diving = false
			_vy = maxf(_vy, -3.0)
			var at := _surface_point()
			Net.fx("splash", [at, 8, 0.75])
			Net.fx("sfx", ["splash", at, -6.0, 0.1, 1.05])
		else:
			player.body_model.diving = true
	elif not _diving:
		_vy += ((target - y) * 14.0 + (target_v - _vy) * 7.5) * delta
		_vy = clampf(_vy, -12.0, 6.0)
	elif y + _vy * delta > target:
		_vy = (target - y) / maxf(delta, 0.0001)
	player.velocity = Vector3(hv.x + _drift.x, _vy, hv.z + _drift.z)
	player.move_and_slide()
	if dir != Vector3.ZERO:
		face_direction(dir, delta * 0.6)

	# ripples and stroke splashes
	_ripple_t -= delta
	if _ripple_t <= 0.0 and not _diving:
		_ripple_t = 0.45 if hv.length() > 0.5 else 1.1
		Net.fx("splash", [_surface_point() + hv.normalized() * 0.4 if hv.length() > 0.5 else _surface_point(), 2 if hv.length() > 0.5 else 1, 0.4])
	_stroke_t -= delta
	if hv.length() > 0.8 and _stroke_t <= 0.0 and not _diving:
		_stroke_t = 0.6 if fast else 0.9
		Net.fx("sfx", ["swim_stroke", player.global_position, -8.0 if fast else -11.0, 0.08])

	# walked out of the water
	# (or leapt out onto something: a rock, a jetty)
	if not _diving and player.is_on_floor() and player.water_depth() < Player.SWIM_EXIT_DEPTH:
		_leap_t = -1.0
		transitioned.emit(self, "Move" if dir != Vector3.ZERO else "Idle", {})
		return
	if _diving or _leap_t >= 0.0:
		_show_climb("")
		return

	# a ladder you swim into takes you (you grab hold), as does Space by one
	var ladder := _ladder_in_reach()
	if ladder and (Input.is_action_just_pressed("jump") or _toward(ladder.global_position, dir)):
		_show_climb("")
		player.start_climb({"kind": "ladder", "ladder": ladder})
		return
	# a ledge or a rock in front: the prompt says so, Space pulls you up
	_ledge_t -= delta
	if _ledge_t <= 0.0:
		_ledge_t = 0.15
		_ledge = _find_ledge()
		_show_climb("Space: climb out" if not _ledge.is_empty() else "")
	if Input.is_action_just_pressed("jump"):
		var now := _find_ledge()
		if not now.is_empty() or not _ledge.is_empty():
			_show_climb("")
			player.start_climb(now if not now.is_empty() else _ledge)
			return
		# nothing to climb: at a sprint, a dolphin leap out of the water
		if fast and player.spend_stamina(LEAP_COST):
			_leap_t = 0.0
			_vy = LEAP_VY
			_dash_dir = dir
			Net.fx("spray", [_surface_point(), (dir + Vector3.UP).normalized(), 12, Color(0.9, 0.96, 1.0), 4.0])
			Net.fx("sfx", ["splash", player.global_position, -7.0, 0.1, 1.3])


## Swimming at `at` (flat): the stroke's heading points at it.
func _toward(at: Vector3, dir: Vector3) -> bool:
	var to := Vector3(at.x - player.global_position.x, 0.0, at.z - player.global_position.z)
	return dir != Vector3.ZERO and to.length() > 0.05 and dir.dot(to.normalized()) > 0.55


## The climb-out prompt (our own, so it's cleared only if we put it up).
func _show_climb(text: String) -> void:
	if text == _prompt:
		return
	_prompt = text
	get_tree().call_group("hud", "show_prompt", text, -1.0)


## Devil Fruit user in deep water: sinking, struggling, drowning.
func _sink_update(delta: float, dir: Vector3) -> void:
	var on_floor := player.is_on_floor()
	var spd := SEABED_SPEED if on_floor else 0.9
	var hv := Vector3(player.velocity.x, 0.0, player.velocity.z).move_toward(dir * spd, 4.0 * delta)
	var vy := player.velocity.y
	if on_floor:
		vy = -0.5
	else:
		vy = move_toward(vy, -SINK_SPEED, 6.0 * delta)
	player.velocity = Vector3(hv.x, vy, hv.z)
	player.move_and_slide()
	if dir != Vector3.ZERO:
		face_direction(dir, delta * 0.5)
	player.body_model.swimming = not on_floor
	player.body_model.diving = false
	player.stamina_regen_mult = 0.0
	# drowning once the head is under
	var head := player.body_model.head.global_position
	if player.water_surface(head) - head.y > 0.05:
		_under_t += delta
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble_t = 0.35
			Net.fx("sparkle", [head + Vector3(0, 0.15, 0), 2, Color(0.8, 0.92, 1.0)])
		if _under_t > DROWN_GRACE:
			_tick += delta
			if _tick >= 0.5:
				_tick = 0.0
				player.health_component.take_damage(DROWN_DPS * 0.5)
				if player.health_component.current_health <= 0.0:
					return
	else:
		_under_t = 0.0
	# made it to the shallows
	if on_floor and player.water_depth() < Player.SWIM_EXIT_DEPTH:
		transitioned.emit(self, "Move" if dir != Vector3.ZERO else "Idle", {})
		return
	# a ladder can still save you
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact"):
		var ladder := _ladder_in_reach()
		if ladder:
			player.start_climb({"kind": "ladder", "ladder": ladder})


func _surface_point() -> Vector3:
	var p := player.global_position
	return Vector3(p.x, player.water_surface(), p.z)


## Root (feet) height that puts the hips at the right depth below the waves.
func _float_y(tired: bool) -> float:
	var surf := player.water_surface()
	var hip := player.body_model.hip_y * player.body_model.scale.y
	var depth := lerpf(0.42, 0.34, _move_blend) * player.body_model.scale.y
	if tired:
		depth += 0.12
	return surf - depth - hip


## Back up through the surface: a gasp of air and a splash.
func _surface() -> void:
	_diving = false
	_vy = minf(_vy, 1.5)
	var at := _surface_point()
	Net.fx("splash", [at, 8 if breath < breath_max() * BREATH_WARN else 6, 0.75])
	Net.fx("sfx", ["splash", at, -7.0, 0.1, 1.15])


func breath_max() -> float:
	return BREATH * (1.0 + player.progression.stat("breath_pct"))


## Breath: held while the head's under (faster at a sprint), back fast once it's out. Empty on a dive:
## steady damage until you surface. Bubbles trail from the mouth now and then.
func _update_breath(delta: float, fast: bool) -> void:
	var head := player.body_model.head.global_position
	var depth := player.water_surface(head) - head.y
	# (only a dive holds your breath: a wave over a swimmer's head at the surface doesn't)
	_head_under = _diving and depth > 0.05
	_cam_under = _diving and (depth > 0.9 or (_cam_under and depth > 0.3))
	if not _head_under:
		breath = minf(breath + BREATH_REFILL * (1.0 + player.progression.stat("breath_refill_pct")) * delta, breath_max())
		if gasping:
			gasping = false
			player.call("_toast", "Air!")
		if breath > breath_max() * BREATH_WARN:
			_breath_warned = false
		return
	breath = maxf(breath - delta * (FAST_BREATH if fast else 1.0), 0.0)
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble_t = 0.25 if gasping else randf_range(0.9, 1.6)
		Net.fx("bubbles", [head + Vector3(0, 0.1, 0) - player.player_model.global_basis.z * 0.12, 6 if gasping else 3])
	if not _breath_warned and breath <= breath_max() * BREATH_WARN:
		_breath_warned = true
		player.call("_toast", "Running out of air! Space to surface")
		FX.sfx("blip_low", head, -4.0, 0.0, 0.8)
	if breath > 0.0:
		return
	if not gasping:
		gasping = true
		_gasp_t = 0.0
		player.call("_toast", "Out of breath! Get to the surface!")
		FX.sfx("peril", head, -2.0)
	_gasp_t -= delta
	if _gasp_t <= 0.0:
		_gasp_t = GASP_TICK
		player.health_component.take_damage(player.health_component.max_health * GASP_DPS * GASP_TICK)
		CombatManager.apply_camera_shake(0.05)


## The sea pushing back: a rip's pull, the surf shoving you in on each breaking crest (with its current
## along the beach), a storm's swell carrying you, all easing into the drift you're carried on (the sea_resist
## perk takes the edge off). How cold it is and how stormy are read a few times a second.
func _sea(delta: float) -> void:
	var p := player.global_position
	_sea_t -= delta
	if _sea_t <= 0.0:
		_sea_t = 0.25
		cold = SEA_PUSH.cold(get_tree(), p)
		storm = SEA_PUSH.storm_k(p)
		if cold > 0.3:
			_tell_once("cold", "The water's freezing! It saps your stamina - get out of it")
		if storm > 0.5:
			_tell_once("storm", "The swell's too heavy to fight - let it carry you")
	var deep := DEEP_PUSH if _diving else 1.0
	var rip := SEA_PUSH.rip(get_tree(), p)
	var surf: Array = SEA_PUSH.surf(p)
	var push := rip + ((surf[0] as Vector3) + SEA_PUSH.storm(p, storm)) * deep
	_drift = _drift.lerp(push * (1.0 - player.progression.stat("sea_resist")), clampf(DRIFT_EASE * delta, 0.0, 1.0))
	if rip.length() > 1.0:
		_tell_once("rip", "Caught in a rip current! Swim along the shore to break out")
	# a breaker coming over you
	var crest: float = surf[1]
	if crest > 0.75 and _crest <= 0.75 and not _diving:
		var at := _surface_point()
		Net.fx("splash", [at + Vector3(0, 0.4, 0), 9, 0.8])
		Net.fx("sfx", ["wave_break", at, -6.0, 0.1, 1.1])
		CombatManager.apply_camera_shake(0.06)
	_crest = crest


func _tell_once(key: String, line: String) -> void:
	if not _told.has(key):
		_told[key] = true
		player.call("_toast", line)


## The camera should be under the waves too (a deep enough dive).
func camera_under() -> bool:
	return _cam_under and player.current_state_name() == "Swim"


func _ladder_in_reach() -> Ladder:
	for l in get_tree().get_nodes_in_group("ladders"):
		var lad := l as Ladder
		if lad and lad.in_reach(player.global_position):
			return lad
	return null


## A walkable edge just above the water in front of you, with room to stand.
func _find_ledge() -> Dictionary:
	var fwd := -player.player_model.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		return {}
	fwd = fwd.normalized()
	var surf := player.water_surface()
	var space := player.get_world_3d().direct_space_state
	for reach in [0.5, 0.75, 1.0, 1.25]:
		var probe: Vector3 = player.global_position + fwd * float(reach)
		var q := PhysicsRayQueryParameters3D.create(Vector3(probe.x, surf + LEDGE_MAX + 0.4, probe.z), Vector3(probe.x, surf + 0.1, probe.z), 1)
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var n: Vector3 = hit["normal"]
		var top: Vector3 = hit["position"]
		var h := top.y - surf
		if n.y < 0.7 or h < 0.15 or h > LEDGE_MAX:
			continue
		# room to stand up there
		var cap := CapsuleShape3D.new()
		cap.radius = 0.3
		cap.height = 1.7
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = cap
		sq.collision_mask = 1
		sq.transform = Transform3D(Basis.IDENTITY, top + fwd * 0.35 + Vector3.UP * 0.95)
		sq.exclude = [player.get_rid()]
		if not space.intersect_shape(sq, 1).is_empty():
			continue
		var anchor := hit["collider"] as Node3D
		return {"kind": "ledge", "anchor": anchor, "edge": top, "top": top + fwd * 0.35, "fwd": fwd, "high": h > LEDGE_HIGH}
	return {}


func exit() -> void:
	player.body_model.swimming = false
	player.body_model.diving = false
	player.stamina_regen_mult = 1.0
	_diving = false
	_cam_under = false
	gasping = false
	breath = breath_max()
	cold = 0.0
	storm = 0.0
	_leap_t = -1.0
	_show_climb("")
