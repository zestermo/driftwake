extends AnimatableBody3D
class_name EnemyShip
## A pirate sloop flying the skull and crossbones. It patrols its stretch of
## sea; when the crew's ship comes by (with someone aboard, away from
## Brinehollow's harbour), it sounds its horn and gives chase:
##
## * it swings round to bring a broadside to bear at 25-45 m and fires its
##   three guns on that side one after another (a second's warning first:
##   sparks at the muzzles, the bosun's "Fire!");
## * after a couple of volleys, if you're slow or close, it pulls alongside,
##   throws grapples and its crew (on deck all along: they draw their
##   cutlasses for the chase and line the rail before boarding) go leaping
##   onto your deck;
## * cannon fire wears its hull down; sunk, it heels over, burns and goes
##   under, leaving a floating chest of plunder;
## * board it yourself (jump across while it's lashed alongside, or climb a
##   ladder from the water): whoever is left aboard, helmsman too, fights you
##   on its deck; clear it and the ship strikes its colours - a prize, with
##   the captain's chest by the cabin. Left empty, it's scuttled.
##
## Co-op: the host sails it (group net_sync); every other screen runs the
## same sailing from the host's latest state (smooth under whoever stands on
## its deck). Its guns send their shots to every screen; boarders and deck
## crews are ordinary grunts.

signal sunk(ship: EnemyShip)

enum S { PATROL, HUNT, BROADSIDE, BOARD, HOLD, SINK, DECK, PRIZE, RAM, FLEE }

## What sails: speed, hull, guns a side (deck z), crew, broadside range
## [near, far], aim scatter, and how it fights (boards / rams / a second
## broadside right after the first / surrenders when beaten).
const KINDS := {
	"sloop": {"speed": 10.0, "hull": 260.0, "guns": [-3.8, -1.6, 1.4], "crew": 6, "range": [24.0, 46.0], "scatter": 1.0,
		"boards": true, "rams": false, "double": false, "yields": true,
		"look": {"hull": Color(0.55, 0.45, 0.42), "deck": Color(0.75, 0.68, 0.6), "trim": Color(0.55, 0.12, 0.1), "sail": Color(0.22, 0.2, 0.2), "flag": Color(0.25, 0.22, 0.22), "emblem": "jolly"}},
	"gunboat": {"speed": 13.0, "hull": 150.0, "guns": [-2.6, 0.6], "crew": 4, "range": [18.0, 34.0], "scatter": 1.25,
		"boards": true, "rams": true, "double": false, "yields": true,
		"look": {"hull": Color(0.6, 0.4, 0.3), "deck": Color(0.8, 0.7, 0.55), "trim": Color(0.75, 0.55, 0.2), "sail": Color(0.62, 0.16, 0.12), "flag": Color(0.2, 0.18, 0.18), "emblem": "jolly"}},
	"brig": {"speed": 8.0, "hull": 420.0, "guns": [-4.4, -2.2, 0.0, 2.2], "crew": 8, "range": [26.0, 50.0], "scatter": 1.0,
		"boards": true, "rams": true, "double": true, "yields": true,
		"look": {"hull": Color(0.32, 0.27, 0.26), "deck": Color(0.6, 0.52, 0.45), "trim": Color(0.3, 0.06, 0.06), "sail": Color(0.12, 0.11, 0.12), "flag": Color(0.15, 0.13, 0.13), "emblem": "jolly"}},
	"marine": {"speed": 11.0, "hull": 320.0, "guns": [-3.8, -1.6, 1.4], "crew": 6, "range": [36.0, 58.0], "scatter": 0.5,
		"boards": false, "rams": false, "double": false, "yields": false,
		"look": {"hull": Color(1.7, 1.7, 1.65), "deck": Color(0.8, 0.74, 0.64), "trim": Color(0.2, 0.32, 0.62), "sail": Color(0.95, 0.95, 0.92), "flag": Color(0.92, 0.92, 0.9), "emblem": "marine"}},
}

const ACCEL := 2.2
const MAX_TURN := 0.5
const FREEBOARD := 0.85
const HEAVE_SCALE := 0.45
const NOTICE := 150.0
const LOSE := 240.0
const FIRE_MAX := 64.0
const VOLLEY_EVERY := 7.5
const WARN := 1.0
## Ramming: closing speed, hull damage dealt (x the rammer's speed share),
## and how long before it tries again.
const RAM_DAMAGE := 45.0
const RAM_EVERY := 25.0
## Fleeing at this share of hull; striking its colours at this share (if it
## would), once you've caught it.
const FLEE_AT := 0.25
const YIELD_AT := 0.15
## Brinehollow's harbour: they won't follow you in (world position, radius).
static var safe_center := Vector3(150, 0, 150)
const SAFE_RADIUS := 250.0
## Land the pirates keep clear of: [centre (x, z), radius] (WorldGenerator
## fills it: the islands, Brinehollow and its dock, the Redtide rock). They
## steer round it, and leave alone a ship within STANDOFF of it (pulling in
## to land, moored at a dock).
static var no_go: Array = []
const STANDOFF := 60.0
const LOOK_AHEAD := 45.0
## The crew on deck: [spot (ship-local, on the deck), yaw]. The helmsman (0)
## stays aboard; the rest go over the side in this order when it boards.
const CREW_SPOTS := [
	[Vector3(0.0, 0.0, 4.0), 0.0],
	[Vector3(0.7, 0.0, -0.3), 0.3],
	[Vector3(1.9, 0.0, -2.7), -PI * 0.5],
	[Vector3(-1.9, 0.0, -0.5), PI * 0.5],
	[Vector3(-0.9, 0.0, 2.1), PI * 0.8],
	[Vector3(0.4, 0.0, -5.2), 0.0],
	[Vector3(-1.4, 0.0, -3.9), PI * 0.5],
	[Vector3(1.7, 0.0, 3.1), -PI * 0.5],
]
## The crew are only drawn this close to the camera (bodies, hair and cloth).
const CREW_SHOW := 220.0
const CREW_WALK := 2.5

var fleet: Node
var patrol_center := Vector3.ZERO
var patrol_radius: float = 90.0
var state: S = S.PATROL
var st_t: float = 0.0
var kind: String = "sloop"
var spec: Dictionary = KINDS["sloop"]
var hull: float = 260.0
var max_hull: float = 260.0
var _ram_cd: float = 0.0
var _second: bool = false
var _fled: bool = false
var speed: float = 0.0
var cannons: Array = []
var hurtbox: Hurtbox
var boarders: Array = []
var net_puppet: bool = false
var look_seed: int = 1

var _pos := Vector3.ZERO
var _heading: float = 0.0
var _yaw_rate: float = 0.0
var _y: float = 0.0
var _vy: float = 0.0
var _pitch: float = 0.0
var _vpitch: float = 0.0
var _roll: float = 0.0
var _vroll: float = 0.0
var _swell_ready: bool = false
var _wp_a: float = 0.0
var _target: Node3D = null
var _volley_cd: float = 3.0
var _volleys: int = 0
var _warn_t: float = -1.0
var _volley_side: float = 1.0
var _boarded: bool = false
var _orbit: float = 1.0
var _sink_t: float = 0.0
var _chest_done: bool = false
var _wake_t: float = 0.0
var _smoke_t: float = 0.0
var _bark: Label3D
var _bark_t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _ocean: Node
var _tokens: Array = []
var _stuck_t: float = 0.0
## {node: Humanoid, look, spot, yaw, gone} per CREW_SPOTS entry.
var _crew: Array = []
var _crew_gone: int = 0
## The crew fighting boarders on this deck (grunts).
var deck_crew: Array = []
## A prize left empty this long is scuttled.
const SCUTTLE_AFTER := 60.0
var _empty_t: float = 0.0
var _deck_delta := Transform3D.IDENTITY
var _copy_ready: bool = false
var _jolly: Node3D


func setup(center: Vector3, radius: float, start_angle: float, seed_value: int, kind_name: String = "sloop") -> EnemyShip:
	patrol_center = center
	patrol_radius = radius
	_wp_a = start_angle
	look_seed = seed_value
	kind = kind_name
	spec = KINDS[kind]
	max_hull = float(spec["hull"])
	hull = max_hull
	return self


func _max_speed() -> float:
	return float(spec["speed"])


func _ready() -> void:
	add_to_group("enemy_ships")
	add_to_group("net_sync")
	add_to_group("decks")
	net_puppet = Net.is_client()
	_rng.seed = look_seed
	collision_layer = 1
	collision_mask = 1
	sync_to_physics = true
	_ocean = get_node_or_null("/root/Ocean")
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	HullBuilder.build(model, spec["look"])
	HullBuilder.collide(self)
	for sgn in [-1.0, 1.0]:
		var guns: Array = spec["guns"]
		for gi in range(guns.size()):
			var z: float = guns[gi]
			var c := ShipCannon.new()
			c.name = "Gun%s%d" % ["S" if sgn > 0.0 else "P", gi]
			c.ship = self
			c.team = "enemy"
			c.mannable = false
			# (a double broadside reloads for the second straight away)
			c.reload_time = 1.2 if spec["double"] else VOLLEY_EVERY - 1.0
			c.hull_damage = 26.0
			c.splash_damage = 18.0
			c.position = Vector3(sgn * (HullBuilder.half_width(z) - 0.45), HullBuilder.DECK_Y, z)
			c.rotation.y = -sgn * PI * 0.5
			model.add_child(c)
			cannons.append(c)
	_build_crew(model)
	_jolly = model.get_node_or_null("Jolly")
	# rope ladders amidships: climb aboard from the water
	for sgn in [-1.0, 1.0]:
		var lad := Ladder.new()
		lad.name = "LadderStarboard" if sgn > 0.0 else "LadderPort"
		lad.length = 2.15
		lad.rail = 0.75
		lad.deck_depth = 0.9
		lad.position = Vector3(sgn * 3.0, HullBuilder.DECK_Y, 0.6)
		lad.rotation.y = sgn * PI * 0.5
		model.add_child(lad)
	# cannon fire finds the hull through this
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 32
	hurtbox.collision_mask = 0
	var hs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 3.4, 15.6)
	hs.shape = box
	hs.position = Vector3(0, -0.2, -0.9)
	hurtbox.add_child(hs)
	add_child(hurtbox)
	hurtbox.owner = self
	hurtbox.hit_received.connect(_on_hit)
	_bark = Label3D.new()
	_bark.font = load("res://assets/fonts/PixelifySans-Regular.woff2")
	_bark.font_size = 40
	_bark.pixel_size = 0.012
	_bark.outline_size = 10
	_bark.modulate = Color(1.0, 0.82, 0.7)
	_bark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_bark.no_depth_test = true
	_bark.position = Vector3(0, 4.0, 0)
	_bark.visible = false
	add_child(_bark)
	_pos = Vector3(global_position.x, 0, global_position.z)
	_heading = global_rotation.y
	if Net.hosting:
		net_rescale(Net.hp_scale())


func is_dead() -> bool:
	return state == S.SINK


func in_combat() -> bool:
	return state in [S.HUNT, S.BROADSIDE, S.BOARD, S.HOLD, S.DECK, S.RAM, S.FLEE]


## Inside its bounds: on deck, in the rigging, on a ladder (same hull as ours).
func aboard(p: Vector3) -> bool:
	var l := global_transform.affine_inverse() * p
	return absf(l.x) < 3.4 and l.z > -9.5 and l.z < 7.5 and l.y > -0.7 and l.y < 13.0


## How the hull moved over the last tick (Player._ride_ship carries jumpers by it).
func deck_delta() -> Transform3D:
	return _deck_delta


func _place_hull(xf: Transform3D) -> void:
	_deck_delta = xf * global_transform.affine_inverse()
	global_transform = xf


func _anyone_aboard() -> bool:
	for p in Net.all_players():
		if aboard((p as Node3D).global_position):
			return true
	return false


func hull_velocity() -> Vector3:
	return Vector3(-sin(_heading), 0.0, -cos(_heading)) * speed


func _fwd() -> Vector3:
	return Vector3(-sin(_heading), 0.0, -cos(_heading))


func _right() -> Vector3:
	return Vector3(cos(_heading), 0.0, -sin(_heading))


func bark(text: String, secs: float = 1.8) -> void:
	_bark.text = text
	_bark.visible = true
	_bark_t = secs


# ==========================================================================
# Brain (host)
# ==========================================================================
func _physics_process(delta: float) -> void:
	if net_puppet:
		_puppet(delta)
		return
	st_t += delta
	_volley_cd -= delta
	_bark_t -= delta
	if _bark_t <= 0.0:
		_bark.visible = false
	var want_heading := _heading
	var want_speed := 0.0
	var tgt := _crew_ship()
	var to_t := Vector3.ZERO
	var dist := INF
	if tgt:
		to_t = tgt.global_position - _pos
		to_t.y = 0.0
		dist = to_t.length()
	# a captain on our deck: all hands repel boarders
	if state not in [S.SINK, S.DECK, S.PRIZE] and _anyone_aboard():
		_start_deck_fight()
	match state:
		S.DECK:
			want_speed = 0.0
			deck_crew = deck_crew.filter(func(g): return is_instance_valid(g) and not g.is_dead())
			if deck_crew.is_empty():
				_strike()
		S.PRIZE:
			want_speed = 0.0
			_empty_t = 0.0 if _anyone_aboard() else _empty_t + delta
			if _empty_t > SCUTTLE_AFTER:
				_start_sink(false)
		S.PATROL:
			var wp := patrol_center + Vector3(cos(_wp_a), 0, sin(_wp_a)) * patrol_radius
			var to_wp := wp - _pos
			to_wp.y = 0.0
			if to_wp.length() < 28.0:
				_wp_a += 0.8
			want_heading = atan2(-to_wp.x, -to_wp.z)
			want_speed = 5.5
			# patched up at sea after a beating (enough to fight again)
			if hull < max_hull * 0.6:
				hull = minf(hull + 1.5 * delta, max_hull * 0.6)
			if tgt and dist < NOTICE and _huntable(tgt) and hull > max_hull * 0.4:
				_set_state(S.HUNT)
				bark("A ship! Run out the guns!", 2.5)
				Net.fx("sfx", ["horn", global_position, 6.0, 0.03, 1.0])
		S.HUNT, S.BROADSIDE:
			var near_r: float = spec["range"][0]
			var far_r: float = spec["range"][1]
			if tgt == null or dist > LOSE or not _huntable(tgt):
				_set_state(S.PATROL)
				bark("Bah, let 'em go." if kind != "marine" else "They've slipped us. Back to patrol.")
			elif hull < max_hull * FLEE_AT and not _fled:
				_fled = true
				_set_state(S.FLEE)
				bark(["Fall back! Fall back!", "She's holed! Run for it!"][_rng.randi() % 2] if kind != "marine" else "Disengage! Make for open water!", 2.5)
			elif state == S.HUNT:
				var lead := tgt.global_position + _vel_of(tgt) * 2.5 - _pos
				want_heading = atan2(-lead.x, -lead.z)
				want_speed = _max_speed()
				if dist < far_r + 15.0:
					_set_state(S.BROADSIDE)
					_orbit = 1.0 if _right().dot(to_t) > 0.0 else -1.0
			else:
				# circle the target at broadside range, a side toward it
				var b := to_t.normalized()
				var tangent := Vector3.UP.cross(b) * -_orbit
				var radial := 0.0
				if dist > far_r:
					radial = 0.6
				elif dist < near_r:
					radial = -0.7
				var d := (tangent + b * radial).normalized()
				want_heading = atan2(-d.x, -d.z)
				want_speed = _max_speed() * 0.75
				if dist > far_r + 30.0:
					_set_state(S.HUNT)
				_try_volley(tgt, to_t, dist)
				_ram_cd -= delta
				# ram them: hull sound, they're slow and not too far
				if spec["rams"] and _ram_cd <= 0.0 and _volleys >= 1 and _warn_t < 0.0 and hull > max_hull * 0.5 and _speed_of(tgt) < 6.0 and dist < 45.0:
					_set_state(S.RAM)
					bark(["Ramming speed!", "Brace! We're going in!", "Run 'em down!"][_rng.randi() % 3], 2.0)
					Net.fx("sfx", ["horn", global_position, 4.0, 0.03, 0.8])
				# board them: after a couple of volleys, when they're slow or close
				elif spec["boards"] and not _boarded and _volleys >= 2 and _warn_t < 0.0 and (_speed_of(tgt) < 6.0 or dist < 30.0):
					_set_state(S.BOARD)
					bark("Grapples! Prepare to board!", 2.5)
		S.RAM:
			if tgt == null or not _huntable(tgt) or st_t > 12.0:
				_ram_cd = RAM_EVERY
				_set_state(S.BROADSIDE if tgt else S.PATROL)
			else:
				var aim := tgt.global_position + _vel_of(tgt) * clampf(dist / maxf(speed, 1.0), 0.0, 3.0) - _pos
				want_heading = atan2(-aim.x, -aim.z)
				want_speed = _max_speed() * 1.15
				# (the hit itself: _sail, when the bow meets their hull)
		S.FLEE:
			if tgt == null or dist > LOSE:
				_set_state(S.PATROL)
			elif spec["yields"] and hull < max_hull * YIELD_AT and dist < 40.0:
				_surrender()
			else:
				want_heading = atan2(to_t.x, to_t.z)
				want_speed = _max_speed()
		S.BOARD:
			if tgt == null or not _huntable(tgt):
				_set_state(S.PATROL)
			else:
				var side := 1.0 if (tgt.global_basis.x).dot(_pos - tgt.global_position) > 0.0 else -1.0
				var spot := tgt.global_position + (tgt.global_basis.x) * side * 7.4 + _vel_of(tgt) * 1.0
				var to_s := spot - _pos
				to_s.y = 0.0
				var th: float = tgt.global_rotation.y
				if to_s.length() > 8.0:
					want_heading = atan2(-to_s.x, -to_s.z)
				else:
					want_heading = lerp_angle(th, atan2(-to_s.x, -to_s.z), clampf(to_s.length() / 8.0, 0.0, 1.0) * 0.6)
				want_speed = clampf(_speed_of(tgt) + to_s.length() * 0.6, 2.0, _max_speed())
				if to_s.length() < 4.5 and dist < 10.5:
					_board(tgt)
				elif st_t > 25.0:
					_boarded = true  # couldn't catch them: back to the guns
					_set_state(S.BROADSIDE)
		S.HOLD:
			# lashed alongside while the boarders fight
			if tgt:
				var side := 1.0 if (tgt.global_basis.x).dot(_pos - tgt.global_position) > 0.0 else -1.0
				var spot := tgt.global_position + (tgt.global_basis.x) * side * 7.4
				var to_s := spot - _pos
				to_s.y = 0.0
				want_heading = lerp_angle(tgt.global_rotation.y, atan2(-to_s.x, -to_s.z), clampf(to_s.length() / 6.0, 0.0, 0.7))
				want_speed = clampf(_speed_of(tgt) + to_s.length() * 0.5, 0.0, _max_speed())
			boarders = boarders.filter(func(g): return is_instance_valid(g) and not g.is_dead())
			if boarders.is_empty() or st_t > 30.0 or tgt == null:
				_set_state(S.BROADSIDE if tgt and _huntable(tgt) else S.PATROL)
				_volley_cd = 4.0
		S.SINK:
			_sink_update(delta)
			return
	_warn_update(tgt, to_t, dist)
	_sail(delta, want_heading, want_speed)


func _set_state(s: S) -> void:
	state = s
	st_t = 0.0


## The crew's ship, if a captain is aboard (an empty ship isn't worth a shot).
func _crew_ship() -> Node3D:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship == null:
		return null
	for p in Net.all_players():
		if ship.aboard((p as Node3D).global_position):
			_target = ship
			return ship
	return null


func _huntable(t: Node3D) -> bool:
	return huntable_at(t.global_position)


## Out at sea, clear of land: somewhere they'll chase and fire on a ship.
static func huntable_at(p: Vector3) -> bool:
	for z in no_go:
		if Vector2(p.x, p.z).distance_to(z[0]) < float(z[1]) + STANDOFF:
			return false
	return true


## Steer round land: bend the course away from any no-go circle it (or the
## water just ahead) runs into.
func _steer_clear(heading: float) -> float:
	var dir := Vector3(-sin(heading), 0.0, -cos(heading))
	var push := Vector3.ZERO
	for z in no_go:
		var c := Vector3((z[0] as Vector2).x, 0.0, (z[0] as Vector2).y)
		var r := float(z[1])
		for probe in [_pos, _pos + dir * LOOK_AHEAD * 0.5, _pos + dir * LOOK_AHEAD]:
			var d: Vector3 = probe - c
			d.y = 0.0
			if d.length() < r:
				push += d.normalized() * (1.0 - d.length() / r + 0.3)
	if push == Vector3.ZERO:
		return heading
	dir = (dir + push * 1.5).normalized()
	return atan2(-dir.x, -dir.z)


func _vel_of(t: Node3D) -> Vector3:
	if t.has_method("hull_velocity"):
		return t.hull_velocity()
	return Vector3.ZERO


func _speed_of(t: Node3D) -> float:
	return absf(float(t.get("speed"))) if t.get("speed") != null else 0.0


# --------------------------------------------------------------------------
# Guns
# --------------------------------------------------------------------------
func _side_guns(side: float) -> Array:
	var out: Array = []
	for c in cannons:
		if signf((c as Node3D).position.x) == signf(side):
			out.append(c)
	return out


func _try_volley(tgt: Node3D, to_t: Vector3, dist: float) -> void:
	if _volley_cd > 0.0 or _warn_t >= 0.0 or dist > FIRE_MAX or dist < 10.0:
		return
	var side := 1.0 if _right().dot(to_t) > 0.0 else -1.0
	var beam := _right() * side
	if beam.dot(to_t.normalized()) < cos(deg_to_rad(38.0)):
		return
	for c in _side_guns(side):
		if not (c as ShipCannon).loaded():
			return
	# the warning: sparks at the muzzles, the bosun's shout
	_volley_side = side
	_warn_t = 0.0
	bark(["Fire!", "Give 'em a broadside!", "Fire as she bears!"][_rng.randi() % 3], 1.4)
	for c in _side_guns(side):
		Net.fx("sparkle", [(c as ShipCannon).muzzle(), 6, Color(1.0, 0.5, 0.2)])
	Net.fx("sfx", ["blip_low", global_position, -2.0, 0.02, 0.7])


func _warn_update(tgt: Node3D, _to_t: Vector3, dist: float) -> void:
	if _warn_t < 0.0:
		return
	var prev := _warn_t
	_warn_t += get_physics_process_delta_time()
	var guns := _side_guns(_volley_side)
	for i in range(guns.size()):
		var at := WARN + 0.24 * i
		if prev < at and _warn_t >= at:
			var c := guns[i] as ShipCannon
			if tgt:
				# lead the target, with some scatter (worse at range)
				var fly := dist / ShipCannon.MUZZLE_SPEED
				var spot := tgt.global_position + _vel_of(tgt) * fly
				var spread := (1.5 + dist * 0.06) * float(spec["scatter"])
				spot += Vector3(_rng.randf_range(-spread, spread), 0, _rng.randf_range(-spread, spread))
				spot.y = 1.0
				c.aim_at(spot)
			c.fire(self)
	if _warn_t >= WARN + 0.24 * guns.size() + 0.1:
		# a brig's second broadside, hard on the heels of the first
		if spec["double"] and not _second:
			_second = true
			_warn_t = WARN - 0.6
			bark("Again! Fire!", 1.0)
			return
		_second = false
		_warn_t = -1.0
		_volley_cd = VOLLEY_EVERY
		_volleys += 1


# --------------------------------------------------------------------------
# Ramming, running, striking
# --------------------------------------------------------------------------
## Bow first into their hull: the crew's ship takes it hard, everyone aboard
## her is thrown about, and we back off to come round again.
func _ram(tgt: Node3D) -> void:
	_ram_cd = RAM_EVERY
	var k := clampf(speed / _max_speed(), 0.4, 1.2)
	var at := _pos + _fwd() * 7.5 + Vector3(0, 1.0, 0)
	Net.fx("sfx", ["wood_crack", at, 8.0, 0.05, 0.6])
	Net.fx("sfx", ["thud", at, 6.0, 0.05, 0.5])
	Net.fx("dust", [at, 16, 1.4])
	Net.fx("splash", [Vector3(at.x, 0.3, at.z), 14, 1.4])
	if tgt is Ship:
		(tgt as Ship).hull_hit(RAM_DAMAGE * k * (1.4 if kind == "brig" else 1.0), at)
	hull = maxf(hull - max_hull * 0.06, 1.0)
	Net.everyone("_all_rammed", [Net.key_of(tgt), at, _fwd() * k])
	speed = -3.0
	_set_state(S.BROADSIDE)
	_volley_cd = maxf(_volley_cd, 3.0)


## Beaten and caught: colours struck - a prize with no fight left in her.
func _surrender() -> void:
	bark(["We yield! Don't shoot!", "Quarter! We strike!", "Enough! She's yours!"][_rng.randi() % 3], 3.0)
	_set_state(S.PRIZE)
	_empty_t = 0.0
	Net.award_xp(120, global_position, 160.0)
	_prize()
	Net.event(self, "prize", [])


# --------------------------------------------------------------------------
# Boarding
# --------------------------------------------------------------------------
func _board(tgt: Node3D) -> void:
	_boarded = true
	_set_state(S.HOLD)
	var n := 3 + clampi(Net.crew_size() - 2, 0, 2)
	var seed_value := _rng.randi()
	_spawn_boarders(n, seed_value, tgt)
	Net.event(self, "board", [n, seed_value])
	Net.fx("sfx", ["rope", global_position, 2.0, 0.05])


## The boarders are the crew who were on deck: each one is swapped for a
## grunt with the same look, where he stood, facing the way he faced.
func _spawn_boarders(n: int, seed_value: int, tgt: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var parent: Node = fleet if fleet else get_parent()
	n = mini(n, _crew.size() - 1)
	for i in range(n):
		var c: Dictionary = _crew[i + 1]
		var man := c["node"] as Humanoid
		c["gone"] = true
		man.visible = false
		_crew_gone = maxi(_crew_gone, i + 1)
		var g := PirateGrunt.new()
		g.name = "BD_%s_%d" % [name, i]
		var start := man.global_position + Vector3.UP * 0.05
		g.setup({"post": start, "yaw": man.global_rotation.y, "mode": "stand", "role": "sword", "seed": rng.randi(), "look": c["look"]})
		g.boarder = true
		g.camp = self
		parent.add_child(g)
		g.global_position = start
		g.reset_physics_interpolation()
		boarders.append(g)
		if not net_puppet and tgt:
			var land_local := Vector3(rng.randf_range(-1.8, 1.8), Ship.DECK_Y + 0.2, rng.randf_range(-4.5, 3.5))
			var t := 1.0 + 0.12 * i
			var land := tgt.global_transform * land_local + _vel_of(tgt) * t
			g.leap(land, t)
	if net_puppet:
		return
	for g in boarders:
		if is_instance_valid(g):
			Net.fx("tracer", [g.global_position + Vector3(0, 1.4, 0), tgt.global_position + Vector3(0, 1.0, 0) if tgt else g.global_position, Color(0.75, 0.6, 0.4)])


## The crew, the same men on every screen (seeded from the ship).
func _build_crew(model: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed * 7 + 3
	for i in range(mini(int(spec["crew"]), CREW_SPOTS.size())):
		var spot: Vector3 = CREW_SPOTS[i][0]
		var yaw: float = CREW_SPOTS[i][1]
		var look := PirateGrunt.crew_look(rng)
		look["name"] = "Pirate"
		if kind == "marine":
			EnemyShip.marine_look(look, rng, i == 0)
		var h := Humanoid.new()
		h.name = "Crew%d" % i
		h.setup(look)
		model.add_child(h)
		h.position = spot + Vector3(0, HullBuilder.DECK_Y, 0)
		h.rotation.y = yaw
		h.set_weapon(Props.weapon_mesh("cutlass"))
		h._attach_weapon(false)
		_crew.append({"node": h, "look": look, "spot": spot, "yaw": yaw, "gone": false, "drawn": false})


## Marine whites over a random body: white cap and shirt, a blue neckerchief,
## no pirate trimmings. The officer (at the wheel) wears a white coat.
static func marine_look(lk: Dictionary, rng: RandomNumberGenerator, officer: bool) -> void:
	var white := Color(0.93, 0.93, 0.9)
	var blue := Color(0.18, 0.28, 0.58)
	lk["name"] = "Marine"
	lk["hat"] = "cap"
	lk["hat_color"] = white
	lk["top"] = "shirt"
	lk["top_color"] = white
	lk["sleeves"] = "long"
	lk["vest"] = "none"
	lk["coat"] = "jacket" if officer else "none"
	lk["coat_color"] = white
	lk["legs"] = "trousers"
	lk["legs_color"] = blue if rng.randf() < 0.5 else white
	lk["belt"] = "belt"
	lk["scarf"] = true
	lk["scarf_color"] = blue
	lk["eyepatch"] = false
	lk["earring"] = false
	lk["pauldron"] = false
	lk["marks"] = "none"


## The crew on deck (every machine, from the ship's state): at their posts on
## patrol; cutlasses out for the chase and the gunnery; boarding, the party
## lines the rail on the side the crew's ship is on.
func _crew_update(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var near := cam != null and cam.global_position.distance_to(global_position) < CREW_SHOW
	var fighting := state in [S.HUNT, S.BROADSIDE, S.BOARD, S.HOLD]
	var side := 0.0
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	if state == S.BOARD and ship:
		side = 1.0 if _right().dot(ship.global_position - global_position) > 0.0 else -1.0
	for i in range(_crew.size()):
		var c: Dictionary = _crew[i]
		var h := c["node"] as Humanoid
		if c["gone"]:
			continue
		h.visible = near
		if not near:
			continue
		var draw := fighting and i > 0
		h.armed = draw
		if draw != bool(c["drawn"]):
			c["drawn"] = draw
			h.play("draw" if draw else "sheathe", 0.45 if draw else 0.5)
		var spot: Vector3 = c["spot"]
		var want_yaw: float = c["yaw"]
		if side != 0.0 and i > 0:
			spot = Vector3(side * (HullBuilder.half_width(spot.z) - 0.75), 0.0, spot.z)
			want_yaw = -PI * 0.5 * side
		var at := Vector3(h.position.x, 0.0, h.position.z)
		var to := spot - at
		var step := minf(to.length(), CREW_WALK * delta)
		if step > 0.001:
			at += to.normalized() * step
			want_yaw = atan2(-to.x, -to.z)
		h.position = at + Vector3(0, HullBuilder.DECK_Y, 0)
		h.rotation.y = lerp_angle(h.rotation.y, want_yaw, clampf(8.0 * delta, 0.0, 1.0))
		h.ground_speed = CREW_WALK if step > 0.001 else 0.0
		h.local_move = Vector2(0, 1)
		h.grounded = true


## Grunts ask their "camp" (this ship) for a turn to swing.
func request_token(g: Node) -> bool:
	_tokens = _tokens.filter(func(t): return is_instance_valid(t) and not t.is_dead())
	if g in _tokens:
		return true
	if _tokens.size() < 2 + Net.extra_attackers():
		_tokens.append(g)
		return true
	return false


func release_token(g: Node) -> void:
	_tokens.erase(g)


func alert_all(_at: Vector3) -> void:
	for g in boarders:
		if is_instance_valid(g):
			g.alert(0.1)


# --------------------------------------------------------------------------
# Taking fire, sinking
# --------------------------------------------------------------------------
func _on_hit(hit: HitData, _attacker: Node) -> void:
	if state == S.SINK or not hit.siege:
		return
	hull = maxf(hull - hit.damage, 0.0)
	Net.damage_number(hit.damage, global_position + Vector3(0, 3.0, 0))
	if state == S.PATROL:
		_set_state(S.HUNT)
		Net.fx("sfx", ["horn", global_position, 6.0, 0.03, 1.0])
	if hull <= 0.0:
		_start_sink()


## Sunk by gunfire (XP, flotsam), or a prize left empty and scuttled.
func _start_sink(fought: bool = true) -> void:
	_set_state(S.SINK)
	_sink_t = 0.0
	_chest_done = not fought
	hurtbox.set_deferred("monitorable", false)
	Net.event(self, "sink", [fought])
	Net.fx("sfx", ["wood_crack", global_position, 6.0, 0.05, 0.6])
	if fought:
		bark("Abandon ship!", 3.0)
		Net.fx("sfx", ["bell", global_position, 2.0, 0.02, 0.8])
		Net.award_xp(150, global_position, 160.0)
	sunk.emit(self)


func _sink_update(delta: float) -> void:
	_sink_t += delta
	var k := clampf(_sink_t / 9.0, 0.0, 1.0)
	_roll = lerpf(_roll, 0.55 * _orbit, clampf(delta * 0.6, 0.0, 1.0))
	_pitch = lerpf(_pitch, -0.12, clampf(delta * 0.4, 0.0, 1.0))
	speed = move_toward(speed, 0.0, 1.5 * delta)
	_pos += _fwd() * speed * delta
	_y = lerpf(FREEBOARD, -8.0, k * k)
	_place_hull(Transform3D(Basis.from_euler(Vector3(_pitch, _heading, _roll)), Vector3(_pos.x, _y, _pos.z)))
	_sink_fx(delta)
	if _sink_t > 1.5 and not _chest_done:
		_chest_done = true
		_drop_chest()
	if _sink_t > 10.0:
		queue_free()


func _sink_fx(delta: float) -> void:
	_smoke_t -= delta
	if _smoke_t <= 0.0:
		_smoke_t = 0.18
		var spot := global_transform * Vector3(randf_range(-2.0, 2.0), 0.8, randf_range(-6.0, 5.0))
		FX.smoke(spot, 3, 1.6, 2.4)
		FX.flame(spot, 5, 0.7, 0.6, 0.4)
		if randf() < 0.3:
			FX.splash(Vector3(spot.x, 0.2, spot.z), 4, 0.9)


## Plunder bobbing on the waves (every captain finds their own).
func _drop_chest() -> void:
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	var items: Array[ItemStack] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var picks := [["gold", rng.randi_range(14, 26)], ["treasure", rng.randi_range(1, 3)]]
	if rng.randf() < 0.6:
		picks.append(["rum", rng.randi_range(1, 2)])
	if rng.randf() < 0.35:
		picks.append([["pistol", "cutlass", "boarding_axe"][rng.randi() % 3], 1])
	for e in picks:
		var it := load("res://resources/items/%s.tres" % e[0]) as ItemData
		if it == null:
			continue
		var st := ItemStack.new()
		st.item = it
		st.quantity = int(e[1])
		items.append(st)
	bag.setup(items, false)
	bag.name = "Flotsam_%s" % name
	bag.floating = true
	var root := get_tree().current_scene
	root.add_child(bag)
	bag.global_position = Vector3(_pos.x, 0.0, _pos.z) + _right() * 4.0


## Another ship (or a dock, or the shore) is in the way: slide along it.
func _sail(delta: float, want_heading: float, want_speed: float) -> void:
	speed = move_toward(speed, want_speed, (ACCEL if want_speed > speed else ACCEL * 1.5) * delta)
	var diff := wrapf(_steer_clear(want_heading) - _heading, -PI, PI)
	var flow := clampf(absf(speed) / 4.0, 0.3, 1.0)
	var target_rate := clampf(diff * 1.2, -1.0, 1.0) * MAX_TURN * flow
	_yaw_rate = move_toward(_yaw_rate, target_rate, 1.0 * delta)
	_heading = wrapf(_heading + _yaw_rate * delta, -PI, PI)
	var motion := _fwd() * speed * delta
	if motion.length() > 0.0001:
		var col := KinematicCollision3D.new()
		if test_move(global_transform, motion, col, 0.05):
			if state == S.RAM and col.get_collider() is Ship:
				_ram(col.get_collider() as Node3D)
				return
			var n := col.get_normal()
			n.y = 0.0
			if n.length() > 0.1 and motion.dot(n) < 0.0:
				n = n.normalized()
				var travel := col.get_travel()
				travel.y = 0.0
				motion = travel + (motion - travel).slide(n) * 0.6
				speed *= 0.97
				_stuck_t += delta
				if _stuck_t > 2.0:
					# aground: back off and turn away
					_stuck_t = 0.0
					_wp_a += 1.6
					speed = -2.0
	_pos += motion
	_swell(delta)
	_place_hull(Transform3D(Basis.from_euler(Vector3(_pitch, _heading, _roll)), Vector3(_pos.x, _y, _pos.z)))
	_wake(delta)


func _wave(p: Vector3, t: float) -> float:
	if _ocean and _ocean.has_method("get_wave_height"):
		return float(_ocean.call("get_wave_height", p, t))
	return 0.0


func _swell(delta: float) -> void:
	var t: float = _ocean.call("clock") if _ocean and _ocean.has_method("clock") else Time.get_ticks_msec() / 1000.0
	var fwd := _fwd()
	var right := _right()
	var hb := _wave(_pos + fwd * 5.8, t)
	var hs := _wave(_pos - fwd * 5.8, t)
	var hp := _wave(_pos - right * 2.7, t)
	var hr := _wave(_pos + right * 2.7, t)
	var hc := _wave(_pos, t)
	var mean := (hb + hs + hp + hr + hc * 2.0) / 6.0
	var ty := lerpf(mean, hc, 0.5) * HEAVE_SCALE + FREEBOARD
	var tp := clampf(atan((hb - hs) / 11.6) * 0.35, -0.045, 0.045)
	var tr := clampf(atan((hr - hp) / 5.4) * 0.3, -0.05, 0.05) + clampf(_yaw_rate * speed * 0.01, -0.06, 0.06)
	if not _swell_ready:
		_swell_ready = true
		_y = ty
		_pitch = tp
		_roll = tr
	var w := 2.2
	_vy += ((ty - _y) * w * w - _vy * 2.0 * w) * delta
	_y += _vy * delta
	var wa := 2.6
	_vpitch += ((tp - _pitch) * wa * wa - _vpitch * 2.0 * wa) * delta
	_pitch += _vpitch * delta
	_vroll += ((tr - _roll) * wa * wa - _vroll * 2.0 * wa) * delta
	_roll += _vroll * delta


func _wake(delta: float) -> void:
	if absf(speed) > 1.0:
		Ocean.wake(self, _pos - _fwd() * 5.8, clampf(absf(speed) / 9.0, 0.0, 1.0))
	_wake_t -= delta
	if absf(speed) > 2.5 and _wake_t <= 0.0:
		_wake_t = clampf(0.5 - absf(speed) * 0.03, 0.14, 0.4)
		var bow := _pos + _fwd() * 6.4
		FX.splash(Vector3(bow.x, 0.3, bow.z), int(clampf(absf(speed) * 0.5, 2.0, 6.0)), 0.6)
		var stern := _pos - _fwd() * 6.6
		FX.splash(Vector3(stern.x, 0.1, stern.z), 3, 0.8)


func _process(delta: float) -> void:
	_crew_update(delta)
	# a battered hull smokes
	if state != S.SINK and hull < max_hull * 0.5:
		_smoke_t -= delta
		if _smoke_t <= 0.0:
			_smoke_t = 0.35 if hull < max_hull * 0.25 else 0.7
			var spot := global_transform * Vector3(randf_range(-1.8, 1.8), 0.6, randf_range(-5.0, 4.0))
			FX.smoke(spot, 2, 1.3, 2.0)
			if hull < max_hull * 0.25:
				FX.flame(spot, 3, 0.5, 0.45, 0.3)


# ==========================================================================
# Co-op
# ==========================================================================
func net_rescale(k: float) -> void:
	var frac := hull / maxf(max_hull, 1.0)
	max_hull = float(spec["hull"]) * k
	if state != S.SINK:
		hull = maxf(frac * max_hull, 1.0)


func net_pack() -> Array:
	return [_pos, _heading, _y, _pitch, _roll, speed, int(state), hull, max_hull, _bark.text if _bark.visible else "", _crew_gone, _yaw_rate]


## Not the host: sail our own copy (so the deck under a boarder moves
## smoothly) and ease it onto the host's latest state, carried forward to now.
func _puppet(delta: float) -> void:
	_bark_t -= delta
	if state == S.SINK:
		_sink_update(delta)
		return
	var last := Net.latest(self)
	if last.size() != 2 or (last[1] as Array).size() < 12:
		return
	var s: Array = last[1]
	var st := int(s[6])
	if st != state and st != S.SINK and st != S.PRIZE:
		state = st as S
	hull = float(s[7])
	max_hull = float(s[8])
	# (joined after it boarded: those men are already over the side)
	if int(s[10]) > _crew_gone:
		_crew_gone = int(s[10])
		for i in range(1, mini(_crew_gone + 1, _crew.size())):
			_crew[i]["gone"] = true
			(_crew[i]["node"] as Node3D).visible = false
	var txt := str(s[9])
	if txt != "" and (txt != _bark.text or not _bark.visible):
		_bark.text = txt
		_bark.visible = true
	elif txt == "":
		_bark.visible = false
	var ahead := clampf(Net.time() - float(last[0]), 0.0, 0.5)
	var rate := float(s[11])
	var mid := float(s[1]) + rate * ahead * 0.5
	var at: Vector3 = (s[0] as Vector3) + Vector3(-sin(mid), 0.0, -cos(mid)) * float(s[5]) * ahead
	var head := float(s[1]) + rate * ahead
	if not _copy_ready or Vector2(at.x - _pos.x, at.z - _pos.z).length() > 8.0:
		_copy_ready = true
		_pos = Vector3(at.x, 0.0, at.z)
		_heading = head
		speed = float(s[5])
		_yaw_rate = rate
	else:
		_heading = wrapf(_heading + _yaw_rate * delta, -PI, PI)
		_pos += _fwd() * speed * delta
		var k := 1.0 - exp(-2.5 * delta)
		_pos += Vector3(at.x - _pos.x, 0.0, at.z - _pos.z) * k
		_heading = lerp_angle(_heading, head, k)
		speed = lerpf(speed, float(s[5]), k)
		_yaw_rate = lerpf(_yaw_rate, rate, k)
	_swell(delta)
	_place_hull(Transform3D(Basis.from_euler(Vector3(_pitch, _heading, _roll)), Vector3(_pos.x, _y, _pos.z)))
	_wake(delta)


func net_event(what: String, args: Array) -> void:
	match what:
		"board":
			_spawn_boarders(int(args[0]), int(args[1]), null)
		"deck":
			_crew_to_deck()
		"prize":
			_prize()
		"sink":
			if state != S.SINK:
				state = S.SINK
				_sink_t = 0.0
				_chest_done = args.size() > 0 and not bool(args[0])
				hurtbox.set_deferred("monitorable", false)
				sunk.emit(self)


# --------------------------------------------------------------------------
# Boarded: the fight on our deck, and the prize
# --------------------------------------------------------------------------
func _start_deck_fight() -> void:
	_set_state(S.DECK)
	bark(["Repel boarders!", "They're on our deck!", "All hands! Cut 'em down!"][_rng.randi() % 3], 2.5)
	Net.fx("sfx", ["horn", global_position, 2.0, 0.03, 1.2])
	_crew_to_deck()
	Net.event(self, "deck", [])


## Whoever's still aboard (helmsman too) turns to fight, where he stood.
func _crew_to_deck() -> void:
	var parent: Node = fleet if fleet else get_parent()
	for i in range(_crew.size()):
		var c: Dictionary = _crew[i]
		if c["gone"]:
			continue
		var man := c["node"] as Humanoid
		c["gone"] = true
		man.visible = false
		var g := PirateGrunt.new()
		g.name = "DK_%s_%d" % [name, i]
		var start := man.global_position + Vector3.UP * 0.05
		g.setup({"post": start, "yaw": man.global_rotation.y, "mode": "stand", "role": "sword", "seed": look_seed + i, "look": c["look"]})
		g.boarder = true
		g.camp = self
		parent.add_child(g)
		g.global_position = start
		g.reset_physics_interpolation()
		deck_crew.append(g)
		if not net_puppet:
			g.alert(0.1 + 0.15 * i)


## The deck is cleared: colours struck, the captain's chest by the cabin.
func _strike() -> void:
	_set_state(S.PRIZE)
	_empty_t = 0.0
	Net.award_xp(200, global_position, 60.0)
	_prize()
	Net.event(self, "prize", [])


## (every screen) The colours come down; each captain finds their own chest.
func _prize() -> void:
	state = S.PRIZE
	if _jolly:
		_jolly.visible = false
	get_tree().call_group("hud", "show_banner", "Prize taken!", "She strikes her colours. The captain's chest is yours.", false)
	FX.sfx("bell", global_position, 0.0, 0.02, 1.2)
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	var items: Array[ItemStack] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name + "prize")
	var picks := [["gold", rng.randi_range(30, 50)], ["treasure", rng.randi_range(2, 4)], ["rum", rng.randi_range(1, 3)]]
	if rng.randf() < 0.6:
		# out at sea the steel's better than Brinehollow's: green, often blue, now and then purple
		var r := rng.randf()
		var tier := 3 if r < 0.06 else (2 if r < 0.45 else 1)
		picks.append(["%s@%d" % [["pistol", "cutlass", "boarding_axe", "katana"][rng.randi() % 4], tier], 1])
	for e in picks:
		var it := ItemDB.get_item(str(e[0]))
		var stk := ItemStack.new()
		stk.item = it
		stk.quantity = int(e[1])
		items.append(stk)
	bag.setup(items, false)
	bag.name = "Prize_%s" % name
	get_node("Model").add_child(bag)
	bag.position = Vector3(1.2, HullBuilder.DECK_Y, 4.6)
