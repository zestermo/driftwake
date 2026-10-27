class_name WillArts
## The 1.24 Will paths' skills, run by TechniqueState (`s`: its helpers and timeline); enter() and update() return false
## for ids that aren't theirs. What the paths change outside a skill is WillPowers'.
##   will_still_point  Tempo: a held breath, then the world round you slows (StillPoint, every machine)
##   will_berserk      Fury: a roar, then WillPowers' berserk buff

const STILL_REACH := 20.0
const STILL_SECS := 3.0
const STILL_COL := Color(0.75, 0.85, 1.0)
const SEA := Color(0.3, 0.72, 1.0)
const SEA_FOAM := Color(0.85, 0.95, 1.0)
## Swell throws a boarder this hard out over the rail and up; Call the Wind's reach from the ship and length.
const SWELL_OUT := 10.0
const SWELL_UP := 9.0
const SWELL_CLEAR := 1.2
const WIND_NEAR := 30.0
const WIND_SECS := 30.0


static func _net() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Net")


static func enter(s, id: String) -> bool:
	var p: Player = s.player
	var net := _net()
	match id:
		"will_still_point":
			s.dur = 0.6
			p.body_model.play("foresight", s.dur)
			net.fx("gather", [p.global_position + Vector3(0, 1.2, 0), 1.6, STILL_COL, 0.3, 14])
			net.fx("sfx", ["blip_high", p.global_position, -6.0, 0.0, 0.5])
		"will_berserk":
			s.dur = 0.75
			p.body_model.play("berserk_roar", s.dur)
			net.fx("gather", [p.global_position + Vector3(0, 1.2, 0), 1.2, WillPowers.FURY, 0.25, 12])
		"will_swell", "will_wind":
			var ship := _my_ship(p, 0.0 if id == "will_swell" else WIND_NEAR)
			if ship == null:
				s._refund("Only aboard your ship" if id == "will_swell" else "Too far from your ship")
				s.dur = 0.0
				return true
			s.dur = 0.7
			s._target = ship
			p.body_model.play("coat" if id == "will_swell" else "foresight", s.dur)
			net.fx("gather", [p.global_position + Vector3(0, 1.2, 0), 1.4, SEA, 0.3, 12])
		_:
			return false
	return true


## The crew's ship if you're aboard it (reach 0) or within `reach` m of it, else null.
static func _my_ship(p: Player, reach: float) -> Node3D:
	var ship := p.get_tree().get_first_node_in_group("ship") as Node3D
	if ship == null:
		return null
	if ship.aboard(p.global_position) or (reach > 0.0 and ship.global_position.distance_to(p.global_position) < reach):
		return ship
	return null


## Swell: a wave over the deck on every screen; the host (it runs the foes) throws every foe on it overboard.
static func swell(p: Player, ship: Node3D) -> void:
	var net := _net()
	net.everyone("_all_will", ["swell", []])
	var c := ship.global_position + Vector3(0, 1.2, 0)
	for z in [-5.0, 0.0, 5.0]:
		var at: Vector3 = ship.global_transform * Vector3(0, 1.4, z)
		net.fx("splash", [at, 10, 1.2])
		net.fx("water_arc", [at, ship.global_basis.z, Vector3.UP, 2.4, PI, 0.6])
	net.fx("sfx", ["wave_break", c, 2.0, 0.05, 0.9])
	net.fx("sfx", ["splash_big", c, 0.0, 0.05, 1.0])
	p.cam_shake(0.25)


## A swept foe's body carried with its flung limbs (its own down state only follows them across, and the bulwark
## would stop it), clear of the hull, for SWELL_CLEAR s.
class _Carry extends RefCounted:
	var body: CharacterBody3D
	var ship: Node3D
	var left := SWELL_CLEAR

	func step() -> void:
		left -= 1.0 / Engine.physics_ticks_per_second
		if left <= 0.0 or not is_instance_valid(body):
			if is_instance_valid(body) and is_instance_valid(ship):
				body.remove_collision_exception_with(ship)
			(Engine.get_main_loop() as SceneTree).physics_frame.disconnect(step)
			return
		var h = body.get("humanoid")
		if h and h.ragdoll:
			body.global_position = h.hips.global_position - Vector3.UP * h.hip_y * h.global_basis.get_scale().y


## The host's side of Swell: each foe on the deck flung out over the nearer rail, its body let through the bulwark
## (world collision off) for SWELL_CLEAR s so it follows its limbs into the sea. Returns how many.
static func swell_foes(ship: Node3D) -> int:
	var tree := ship.get_tree()
	var n := 0
	var side_x: Vector3 = ship.global_basis.x
	for e in tree.get_nodes_in_group("enemies"):
		if not (e is CharacterBody3D) or not BurnStatus.alive(e) or not e.has_method("launched") or not ship.aboard((e as Node3D).global_position):
			continue
		var body := e as CharacterBody3D
		var local: Vector3 = ship.global_transform.affine_inverse() * body.global_position
		var out: Vector3 = side_x * (1.0 if local.x >= 0.0 else -1.0)
		body.launched(out * SWELL_OUT + Vector3.UP * SWELL_UP)
		var c := _Carry.new()
		c.body = body
		c.ship = ship
		body.add_collision_exception_with(ship)
		tree.physics_frame.connect(c.step)
		tree.root.get_node("FX").spray(body.global_position + Vector3(0, 0.6, 0), out + Vector3.UP, 12, SEA_FOAM, 6.0)
		n += 1
	return n


static func update(s, delta: float) -> bool:
	var p: Player = s.player
	var net := _net()
	match s.id:
		"will_still_point":
			s._rooted(delta, 0.0)
			if s._once("still", 0.3):
				var at := p.global_position
				net.everyone("_all_will", ["still", [at, STILL_REACH, STILL_SECS]])
				net.fx("ring", [at + Vector3(0, 0.2, 0), Vector3.UP, STILL_REACH, STILL_COL, 0.6, 0.1])
				net.fx("ring", [at + Vector3(0, 1.2, 0), Vector3.UP, 3.0, Color.WHITE, 0.3, 0.12])
				net.fx("star_glint", [at + Vector3(0, 1.6, 0), 1.4, STILL_COL, 0.4])
				net.fx("sfx", ["whoosh_big", at, -4.0, 0.0, 0.45])
				p.cam_kick(0.15, 0.6)
		"will_berserk":
			s._rooted(delta, 0.0)
			if s._once("roar", 0.25):
				p.power.will.berserk()
		"will_swell":
			s._rooted(delta, 0.0)
			if s._once("stamp", 0.3) and is_instance_valid(s._target):
				swell(p, s._target)
		"will_wind":
			s._rooted(delta, 0.0)
			if s._once("call", 0.35):
				net.everyone("_all_will", ["wind", [WIND_SECS]])
				var sail_at: Vector3 = (s._target as Node3D).global_position + Vector3(0, 6.0, 0)
				net.fx("gust", [p.global_position + Vector3(0, 1.6, 0), (sail_at - p.global_position).normalized(), 16, 7.0])
				net.fx("speed_lines", [sail_at, -(s._target as Node3D).global_basis.z, SEA_FOAM, 14, 5.0, 0.6])
				net.fx("sfx", ["whoosh_big", p.global_position, 0.0, 0.05, 0.6])
				p.cam_kick(0.1, 0.5)
		_:
			return false
	return true
