class_name WillArts
## The 1.24 Will paths' skills, run by TechniqueState (`s`: its helpers and timeline); enter() and update() return false
## for ids that aren't theirs. What the paths change outside a skill is WillPowers'.
##   will_still_point  Tempo: a held breath, then the world round you slows (StillPoint, every machine)
##   will_berserk      Fury: a roar, then WillPowers' berserk buff
##   will_swell        Tide: aboard, a wave over the deck; the host throws the boarders off (swell_foes)
##   will_wind         Tide: Call the Wind (Ship.will_wind on every machine)
##   will_glimpse      Sense: foes and chests marked through walls (WillSight, this screen only)
##   will_flag         Captain's Will: Plant the Flag (WarFlag on every machine)
##   will_twin         Bond: Twin Finisher's lead (the joint gauge spent); the linked crewmate's machine, told by the
##                     host (twin_net), runs will_twin_mate: both close on the foe from either side, strike, and cross
##                     their weapons through it at the same beat. Alone, the ship's broadside fires on it instead.

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
## Twin Finisher: the foe it closes on (m), its length, each one's first strike and the crossing finale (base
## damage), the finale's reach, where each stands from the foe; the beats (s).
const TWIN_REACH := 10.0
const TWIN_DUR := 1.1
const TWIN_HIT := 30.0
const TWIN_FINAL := 50.0
const TWIN_RING := 2.6
const TWIN_GAP := 1.5
const TWIN_CLOSE := 0.06
const TWIN_STRIKE := [0.3, 0.42]
const TWIN_CROSS_AT := 0.7
const TWIN_SAFE := 0.95
const GLIMPSE_SECS := 3.0
## The host lets a crewmate join only this close to the lead.
const TWIN_JOIN := 12.0


static func _net() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Net")


## A captain's weapon colour (its tree's, plain steel for one without).
static func _weapon_col(p: Player) -> Color:
	var fx := (Engine.get_main_loop() as SceneTree).root.get_node("FX")
	var tr := SkillTree.style_tree(p.style())
	return fx.tree_col(tr if fx.TREE_FX.has(tr) else "plain", 1)


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
		"will_glimpse":
			s.dur = 0.4
			p.body_model.play("foresight", s.dur)
			net.fx("sparkle", [p.global_position + Vector3(0, 1.7, 0), 12, WillSight.FOE])
		"will_flag":
			s.dur = 0.8
			p.body_model.play("coat", s.dur)
			net.fx("gather", [p.global_position + Vector3(0, 1.2, 0), 1.2, p.progression.will_tint(), 0.3, 10])
		"will_twin", "will_twin_mate":
			var lead: bool = id == "will_twin"
			var foe: Node3D = s._nearest(TWIN_REACH, false) if lead else s._target
			if foe == null:
				s._refund("Nobody close enough")
				return true
			s._target = foe
			s.dur = TWIN_DUR
			p.hurtbox.set_deferred("monitorable", false)
			p.body_model.play("thrust", 0.4)
			net.fx("gather", [p.global_position + Vector3(0, 1.2, 0), 1.4, WillBond.COL, 0.2, 12])
			if lead:
				var bond: WillBond = p.power.will.bond
				bond.gauge = 0.0
				var mate := bond.partner()
				s.set_meta("twin_with", mate)
				if mate is Player:
					net.everyone("_all_will", ["twin_ask", [net.key_of(p), net.key_of(mate), net.key_of(foe)]])
		_:
			return false
	return true


## Twin Finisher over the wire. "twin_ask" [lead, mate, foe]: the host lets the mate join if they're standing, not
## busy in another one, and within TWIN_JOIN of the lead, and tells everyone "twin"; the mate's own machine then runs
## its half.
static func twin_net(op: String, a: Array) -> void:
	var net := _net()
	var lead := net.node_of(str(a[0])) as Player
	var mate := net.node_of(str(a[1])) as Player
	var foe := net.node_of(str(a[2])) as Node3D
	if lead == null or mate == null or foe == null:
		return
	if op == "twin_ask":
		if net.is_host() and mate.health_component.current_health > 0.0 and not mate.is_bleeding() \
				and mate.current_state_name() not in ["Downed", "Technique", "Helm"] and mate.global_position.distance_to(lead.global_position) <= TWIN_JOIN:
			net.everyone("_all_will", ["twin", a])
		return
	if mate.is_local:
		var tech = mate.state_machine.get_node("Technique")
		tech.set_meta("twin_with", lead)
		mate.state_machine.force_state("Technique", {"id": "will_twin_mate", "target": foe})


## One side of Twin Finisher: close on the foe (the lead on the near side, the mate on the far side from the lead),
## strike, and both cross through it at TWIN_CROSS_AT; the lead draws the cross in both their colours (and, bonded to
## the ship, calls her broadside on it).
static func _twin(s, p: Player, delta: float) -> void:
	var net := _net()
	var lead: bool = s.id == "will_twin"
	var foe: Node3D = s._target
	var with_ = s.get_meta("twin_with") if s.has_meta("twin_with") else null
	if not is_instance_valid(foe):
		s._rooted(delta, 0.0)
		return
	if s._once("close", TWIN_CLOSE):
		var from: Vector3 = p.global_position if lead or not is_instance_valid(with_) else (with_ as Node3D).global_position
		var to := foe.global_position - from
		to.y = 0.0
		to = to.normalized() if to.length() > 0.05 else -foe.global_basis.z
		var spot := foe.global_position + to * (-TWIN_GAP if lead else TWIN_GAP)
		net.fx("afterimage", [p.body_model, WillBond.COL, 0.25])
		s._place(Vector3(spot.x, p.global_position.y, spot.z))
		s._dir = (foe.global_position - spot).normalized() * Vector3(1, 0, 1)
		s.face_direction(s._dir, 1.0)
	else:
		s._rooted(delta, 0.0)
	if s._once("strike", TWIN_STRIKE[0 if lead else 1]):
		p.body_model.play("dual_cross", 0.5)
		s._strike(foe, s._hd(TWIN_HIT, 2.0, false))
		net.fx("slash", [p.player_model, "right" if lead else "left", 0.25, _weapon_col(p)])
		net.fx("sfx", ["whoosh_big", p.global_position, -3.0, 0.05, 1.2 if lead else 1.05])
	if s._once("cross", TWIN_CROSS_AT):
		var hd: HitData = s._hd(TWIN_FINAL, 10.0, true)
		hd.unblockable = true
		for e in p.power.enemies_in(foe.global_position + Vector3(0, 0.9, 0), TWIN_RING):
			s._strike(e, hd.duplicate())
		if lead:
			var other: Color = _weapon_col(with_) if with_ is Player else WillArts.SEA
			var at := foe.global_position + Vector3(0, 1.1, 0)
			net.fx("twin_cross", [at, s._dir, 2.4, _weapon_col(p), other, 0.35])
			net.fx("ring", [foe.global_position + Vector3(0, 0.1, 0), Vector3.UP, TWIN_RING + 0.6, WillBond.COL, 0.35, 0.14])
			net.fx("sfx", ["clash", at, 2.0, 0.0, 0.8])
			s._moment(0.35, 0.25, 0.2)
			p.power.will.bond.gauge = 0.0
			if with_ != null and with_.is_in_group("ship"):
				var local: Vector3 = (with_ as Node3D).global_transform.affine_inverse() * foe.global_position
				with_.broadside(1.0 if local.x >= 0.0 else -1.0, foe.global_position, p)
		p.cam_shake(0.3)
	if s._once("safe", TWIN_SAFE):
		p.hurtbox.set_deferred("monitorable", true)


## The crew's ship if you're aboard it (reach 0) or within `reach` m of it, else null.
static func _my_ship(p: Player, reach: float) -> Node3D:
	var ship := WillBond.crew_ship(p.get_tree())
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


## The host's side of Swell: each foe on the deck flung out over the nearer rail, its body carried with its limbs
## through the bulwark (_Carry) into the sea. Returns how many.
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
		"will_glimpse":
			s._rooted(delta, 0.3)
			if s._once("see", 0.15):
				WillSight.glimpse(p, GLIMPSE_SECS)
				net.fx("ring", [p.global_position + Vector3(0, 1.0, 0), Vector3.UP, 2.0, WillSight.FOE, 0.3, 0.08])
				net.fx("sfx", ["blip_high", p.global_position, -6.0, 0.0, 0.7])
		"will_flag":
			s._rooted(delta, 0.0)
			if s._once("plant", 0.4):
				var at: Vector3 = p.global_position + s._dir * 0.8
				net.everyone("_all_will", ["flag", [Vector3(at.x, p.global_position.y, at.z), p.progression.will_tint()]])
				net.fx("sfx", ["thud", at, -2.0, 0.05, 0.8])
				p.cam_shake(0.12)
		"will_twin", "will_twin_mate":
			_twin(s, p, delta)
		_:
			return false
	return true
