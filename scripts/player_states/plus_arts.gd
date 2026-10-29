class_name PlusArts
extends RefCounted
## (1.26, docs/weapons_126.md, WeaponPlus) The weapons' new moves, played in TechniqueState from their data
## (PlusMoves.MOVES): each tree's alternates (aerial, sprint attack, right-click: switched on at its variants), its
## aerial heavy (right-click in the air) and its second ultimate (a Skills entry). A move is a timeline in seconds:
##   slot   "air" (falls until it lands: "land" ops, "land_pose", then "rec" s), "sprint", "heavy", "ult"
##   kind   Player.melee_hit's kind for its blows ("" plain, "heavy", "skill")
##   pose   [action, length] played on entry; enter: ops at once; at: [[t, op...]]; ticks: [[from, to, every, op...]]
##          (an air move's stop when it lands); end: [[t, op...]] like at, after the ticks
##   dash   [[from, to, speed]] driven along the aim (ground); hang [[from, to, vertical speed]] (air)
##   fin    ops once an "each" has gone through its foes; need: refunded when the each finds nobody
## Ops (s is the TechniqueState, its helpers do the work; damage through Player.melee_hit so the Edy and the tree's
## bonuses count):
##   aim r · hop fwd up · dive speed · through · blink behind|side|front · pose a len · hold a blend · stop
##   cone reach cos dmg knock flags · ring reach dmg knock flags · line len width dmg knock flags · hit reach dmg knock
##   flags (the aimed foe) · fire reach n dmg flags (shots) · proj kind dmg · drag reach dmg (inward)
##   each reach n every tail op... (one op per foe round you, closest first; each_at: round the mark) · mark (the
##   reticle's spot) · here (where you stand) · zone r dmg flags (bolts on everyone round the mark) · chase dmg flags
##   pose len (up to the last foe of the each, spiked down)
##   glint [size] · trail secs · spin secs · slam r · gather · vortex secs r · moment · flash a · invuln on · shake a
##   kick a secs · sfx name db pitch · spray n
## Per-foe ops (each): blinkcut dmg flags · erupt dmg flags · bolt dmg flags · bounce dmg flags · crash dmg flags ·
##   fire dmg flags. Flags (a space-separated string): down launch launch2 spike unblock breaker sever bleed pin pull
##   ranged; "grow" (bounce): harder each foe; "last_down": the last foe of an each knocked down.

const LAUNCH := 9.0
const LAUNCH_HIGH := 12.5
const SPIKE := -18.0
const PIN_SECS := 1.8
## An air move that hasn't landed by now is an ordinary fall.
const AIR_MAX := 3.0
const GROW := 0.15
const FXS := preload("res://scripts/game/fx.gd")
const MOVES := PlusMoves.MOVES


static func enter(s, id: String) -> bool:
	if not MOVES.has(id):
		return false
	var m: Dictionary = MOVES[id]
	var p: Player = s.player
	s.dur = float(m["dur"])
	s.plus = {}
	if m.has("pose"):
		p.body_model.play(str(m["pose"][0]), float(m["pose"][1]))
	if m["slot"] == "air":
		p.air_uses[id] = int(p.air_uses.get(id, 0)) + 1
	for op in m.get("enter", []):
		_op(s, op)
	return true


static func update(s, delta: float) -> bool:
	if not MOVES.has(s.id):
		return false
	var m: Dictionary = MOVES[s.id]
	var air: bool = m["slot"] == "air" and not s.plus.has("landed")
	if air:
		_air(s, m, delta)
	else:
		_move(s, m, delta)
	var at: Array = m.get("at", [])
	for i in at.size():
		if s._once("at%d" % i, float(at[i][0])):
			_op(s, (at[i] as Array).slice(1))
	var ticks: Array = m.get("ticks", [])
	for i in ticks.size():
		var tk: Array = ticks[i]
		var n := int(s.plus.get("tk%d" % i, 0))
		if (air or m["slot"] != "air") and s.t >= float(tk[0]) + n * float(tk[2]) and s.t < float(tk[1]):
			s.plus["tk%d" % i] = n + 1
			_op(s, tk.slice(3))
	var end: Array = m.get("end", [])
	for i in end.size():
		if s._once("end%d" % i, float(end[i][0])):
			_op(s, (end[i] as Array).slice(1))
	_each(s, m)
	return true


## A move's own feet on the ground: driven along the aim while a dash runs, else stood.
static func _move(s, m: Dictionary, delta: float) -> void:
	for d in m.get("dash", []):
		if s.t >= float(d[0]) and s.t < float(d[1]):
			s._drift(delta, float(d[2]))
			return
	s._rooted(delta, 0.0)


## An air move: falling (or held by a hang) until it lands, then its landing and recovery.
static func _air(s, m: Dictionary, delta: float) -> void:
	var p: Player = s.player
	var held := false
	for h in m.get("hang", []):
		if s.t >= float(h[0]) and s.t < float(h[1]):
			p.velocity.y = move_toward(p.velocity.y, float(h[2]), 40.0 * delta)
			held = true
	if not held:
		s.apply_gravity(delta)
	p.move_and_slide()
	if p.is_on_floor() and s.t > 0.08:
		s.plus["landed"] = true
		p.velocity = Vector3.ZERO
		if m.has("land_pose"):
			p.body_model.play(str(m["land_pose"][0]), float(m["land_pose"][1]))
		for op in m.get("land", []):
			_op(s, op)
		s.dur = s.t + float(m.get("rec", 0.3))
	elif s.t < AIR_MAX:
		s.dur = maxf(s.dur, s.t + 0.05)


static func _each(s, m: Dictionary) -> void:
	if not s.plus.has("each"):
		return
	var e: Dictionary = s.plus["each"]
	var list: Array = e["list"]
	for i in list.size():
		if s._once("each%d" % i, float(e["t0"]) + i * float(e["every"])) and _alive(list[i]):
			_per(s, list[i], e["op"], i, i == list.size() - 1)
	if s._once("each_fin", float(e["t0"]) + list.size() * float(e["every"])):
		for op in m.get("fin", []):
			_op(s, op)


## Net, reached through the tree (a static func can't name the autoloads).
static func _net(s) -> Node:
	return (s as Node).get_node("/root/Net")


static func _alive(e) -> bool:
	return e != null and is_instance_valid(e) and (e as Node).is_inside_tree()


static func _op(s, a: Array) -> void:
	var p: Player = s.player
	match str(a[0]):
		"aim":
			var e: Node3D = s._aimed(float(a[1]))
			if e == null:
				e = s._nearest(float(a[1]), true)
			s._target = e
			if e:
				s._dir = s._flat_to(e)
				s.face_direction(s._dir, 1.0)
		"hop":
			p.velocity = s._dir * float(a[1]) + Vector3.UP * float(a[2])
		"dive":
			var to: Vector3 = s._dir + Vector3.DOWN * 0.9
			if _alive(s._target):
				to = s._target.global_position + Vector3(0, 0.5, 0) - s._chest()
			p.velocity = to.normalized() * float(a[1])
		"through":
			p.set_collision_mask_value(12, false)
		"blink":
			if _alive(s._target):
				match str(a[1]):
					"behind":
						s._blink_behind(s._target)
					"side":
						s._blink_side(s._target)
					"front":
						s._place(s._target.global_position - s._flat_to(s._target) * 1.3)
		"pose":
			p.body_model.play(str(a[1]), float(a[2]))
		"hold":
			p.body_model.hold(str(a[1]), float(a[2]))
		"stop":
			p.velocity = Vector3.ZERO
		"cone":
			_hit(s, _cone(s, float(a[1]), float(a[2])), float(a[3]), float(a[4]), str(a[5]))
			_net(s).fx("ring", [s._chest() + s._dir * float(a[1]) * 0.5, s._dir, float(a[1]) * 0.45, s._col(), 0.2, 0.16])
		"ring":
			_hit(s, s._pc.enemies_in(p.global_position + Vector3(0, 0.9, 0), float(a[1])), float(a[2]), float(a[3]), str(a[4]))
			_net(s).fx("ring", [p.global_position + Vector3(0, 0.2, 0), Vector3.UP, float(a[1]), s._col(), 0.3, 0.14])
		"line":
			_hit(s, _line(s, float(a[1]), float(a[2])), float(a[3]), float(a[4]), str(a[5]))
			_net(s).fx("ground_crack", [p.global_position + s._dir * 0.8, s._dir, float(a[1]), s._col(FXS.ACCENT) if s._elem() else Color(0, 0, 0, 0), randi() % 10000, 0.12])
			_net(s).fx("streak", [s._chest() + s._dir * 0.6, s._chest() + s._dir * float(a[1]), s._col(), 0.16, 0.35])
		"hit":
			if _alive(s._target) and s._target.global_position.distance_to(p.global_position) <= float(a[1]) + 0.6:
				_hit(s, [s._target], float(a[2]), float(a[3]), str(a[4]))
			else:
				_hit(s, _cone(s, float(a[1]), 0.3).slice(0, 1), float(a[2]), float(a[3]), str(a[4]))
		"fire":
			var list: Array = [s._target] if _alive(s._target) else []
			if list.is_empty() or int(a[2]) > 1:
				list = s._closest(float(a[1]), int(a[2]))
			for e in list:
				_shoot(s, e, float(a[3]), str(a[4]))
			if list.is_empty():
				_shoot(s, null, 0.0, "")
		"proj":
			Projectile.launch(p.get_tree(), str(a[1]), s._chest() + s._dir * 0.8, s._dir, p, float(a[2]), "elem" if s._elem() else "")
		"drag":
			s._ring(float(a[1]), float(a[2]), 2.5, false, true)
		"each", "each_at":
			var center: Vector3 = s.plus.get("at", p.global_position) if a[0] == "each_at" else p.global_position
			var list: Array = s._pc.enemies_in(center + Vector3(0, 0.9, 0), float(a[1]))
			list.sort_custom(func(x, y): return (x as Node3D).global_position.distance_to(center) < (y as Node3D).global_position.distance_to(center))
			list = list.slice(0, int(a[2]))
			if list.is_empty() and MOVES[s.id].get("need", false):
				s._refund("Nobody close enough")
				return
			s.plus["each"] = {"t0": s.t, "every": float(a[3]), "list": list, "op": a.slice(5)}
			s.dur = s.t + list.size() * float(a[3]) + float(a[4])
		"mark":
			var at: Vector3 = s._reticle_target(30.0)
			s.plus["at"] = Vector3(at.x, p.global_position.y, at.z) if at.y > p.global_position.y + 0.5 else at
		"here":
			s.plus["at"] = p.global_position
		"zone":
			var c: Vector3 = s.plus["at"]
			_net(s).fx("bolt", [c + Vector3(0, 16, 0), c, s._col(FXS.CORE), 0.16, 0.25, randi() % 10000])
			_net(s).fx("ring", [c + Vector3(0, 0.15, 0), Vector3.UP, float(a[1]), s._col(), 0.3, 0.12])
			for e in s._pc.enemies_in(c + Vector3(0, 0.9, 0), float(a[1])):
				var at: Vector3 = (e as Node3D).global_position
				_net(s).fx("bolt", [at + Vector3(randf_range(-1, 1), 9, randf_range(-1, 1)), at + Vector3(0, 0.8, 0), s._col(), 0.1, 0.2, randi() % 10000])
				_hit(s, [e], float(a[2]), 2.0, str(a[3]))
			_net(s).fx("sfx", ["thud", c, -3.0, 0.08, 1.4])
		"chase":
			var list: Array = s.plus.get("each", {}).get("list", [])
			var e = list[-1] if not list.is_empty() else null
			if _alive(e):
				var at: Vector3 = (e as Node3D).global_position
				_net(s).fx("afterimage", [p.body_model, s._col(), 0.3])
				_net(s).fx("streak", [s._chest(), at + Vector3(0, 2.4, 0), s._col(), 0.14, 0.3])
				s._place(at + Vector3(0, 1.8, 0) - s._flat_to(e) * 0.6)
				p.body_model.play(str(a[3]), float(a[4]))
				_hit(s, [e], float(a[1]), 3.0, str(a[2]))
				p.velocity = Vector3.DOWN * 12.0
				_slam(s, 3.0)
		"glint":
			_net(s).fx("glint", [_tip(s), s._col(FXS.CORE), float(a[1]) if a.size() > 1 else 0.8])
		"trail":
			_trail(s, float(a[1]))
		"spin":
			_net(s).fx("slash", [p.player_model, "spin", float(a[1]), s._col()])
		"slam":
			_slam(s, float(a[1]))
		"gather":
			_net(s).fx("gather", [s._chest(), 2.6, s._col(FXS.ACCENT) if s._elem() else s._col(), 0.4, 22])
		"vortex":
			_net(s).fx("vortex", [p, float(a[1]), float(a[2]), 3.0, s._col(), randi() % 10000])
		"moment":
			s._moment(0.4, 0.25, 0.45, 0.2)
		"flash":
			var c: Color = s._col(FXS.CORE)
			_net(s).fx("screen_flash", [p.global_position, Color(c.r, c.g, c.b, float(a[1])), 0.3])
		"invuln":
			p.hurtbox.set_deferred("monitorable", not bool(a[1]))
		"shake":
			p.cam_shake(float(a[1]))
		"kick":
			p.cam_kick(float(a[1]), float(a[2]))
		"sfx":
			_net(s).fx("sfx", [str(a[1]), p.global_position, float(a[2]), 0.05, float(a[3])])
		"spray":
			s._spray(s._chest() + s._dir * 0.8, s._dir + Vector3.UP * 0.6, int(a[1]), 4.0)
		_:
			push_error("PlusArts: no op " + str(a[0]))


## One foe of an "each": [op, dmg, flags, (pose)].
static func _per(s, e: Node3D, op: Array, i: int, last: bool) -> void:
	var p: Player = s.player
	var dmg := float(op[1])
	var flags := str(op[2])
	if last and "last_down" in flags:
		flags += " down"
	if "grow" in flags:
		dmg *= 1.0 + GROW * i
	if op.size() > 3:
		p.body_model.play(str(op[3]), 0.24)
	var at := e.global_position
	match str(op[0]):
		"blinkcut":
			s._blink_behind(e)
			_trail(s, 0.15)
			_hit(s, [e], dmg, 4.0, flags)
		"erupt":
			s._dir = s._flat_to(e)
			s.face_direction(s._dir, 1.0)
			_net(s).fx("ring", [at + Vector3(0, 0.15, 0), Vector3.UP, 1.6, s._col(), 0.3, 0.16])
			_net(s).fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP, 7, Color(0.36, 0.31, 0.26), 6.0])
			_net(s).fx("streak", [at, at + Vector3(0, 3.5, 0), s._col(FXS.ACCENT), 0.3, 0.3])
			if s._elem():
				_net(s).fx("element", [s._tree(), at + Vector3(0, 0.4, 0), Vector3.UP, 12, 6.0])
			_net(s).fx("sfx", ["rock_crash", at, -6.0, 0.08, 1.2])
			_hit(s, [e], dmg, 2.0, flags)
			p.cam_shake(0.12)
		"bolt":
			_net(s).fx("bolt", [at + Vector3(0, 12, 0), at + Vector3(0, 0.8, 0), s._col(FXS.CORE), 0.12, 0.25, randi() % 10000])
			_hit(s, [e], dmg, 2.0, flags)
		"bounce":
			var to: Vector3 = s._body_center(e)
			var from: Vector3 = s.plus.get("last", s._muzzle())
			_net(s).fx("tracer", [from, to, s._col(FXS.CORE)])
			_net(s).fx("glint", [to, s._col(FXS.CORE), 0.7 + 0.08 * i])
			_net(s).fx("sfx", ["gunshot" if i == 0 else "clash", to, -4.0, 0.06, 1.2 + 0.05 * i])
			s.plus["last"] = to
			s._strike(e, _hd(s, dmg, 2.0, flags + " ranged"))
			_impact(s, e, flags)
		"crash":
			_net(s).fx("streak", [at + Vector3(0, 6, 0), at + Vector3(0, 0.6, 0), s._col(), 0.4, 0.3])
			_net(s).fx("ring", [at + Vector3(0, 0.15, 0), Vector3.UP, 1.8, s._col(), 0.3, 0.16])
			s._spray(at + Vector3(0, 1.5, 0), Vector3.DOWN, 12, 6.0)
			_net(s).fx("dust", [at, 6, 0.7])
			_hit(s, [e], dmg, 3.0, flags)
		"fire":
			_shoot(s, e, dmg, flags)
		_:
			push_error("PlusArts: no per-foe op " + str(op[0]))


static func _hd(s, dmg: float, knock: float, flags: String) -> HitData:
	var m: Dictionary = MOVES[s.id]
	var hd := shape((s.player as Player).melee_hit(dmg, str(m["kind"])), dmg, knock, flags, m["slot"] == "ult")
	if m["slot"] == "heavy":
		hd.predictable = PlayerState.read_chance()
	return hd


## A blow made what its flags say (also the crew techniques', CrewTechniqueState).
static func shape(hd: HitData, dmg: float, knock: float, flags: String, ult: bool) -> HitData:
	var fl := flags.split(" ", false)
	hd.knockback_force = knock
	hd.knockdown = "down" in fl
	if hd.knockdown:
		hd.poise = Poise.ULT if ult else clampf(dmg * 1.2, Poise.TECH_MIN, Poise.TECH_MAX)
	hd.stagger_duration = 0.5 if hd.knockdown else 0.3
	hd.hitstop_duration = 0.07 if hd.knockdown else 0.04
	hd.camera_shake_intensity = 0.15 if hd.knockdown else 0.06
	if "launch" in fl or "launch2" in fl:
		hd.launch = LAUNCH_HIGH if "launch2" in fl else LAUNCH
		hd.stagger_duration = 0.6
	if "spike" in fl:
		hd.launch = SPIKE
	if "pin" in fl:
		hd.stagger_duration = PIN_SECS
		hd.breaker = true
	hd.unblockable = hd.unblockable or "unblock" in fl
	hd.breaker = hd.breaker or "breaker" in fl
	hd.sever = "sever" in fl
	hd.ranged = "ranged" in fl
	if "bleed" in fl:
		hd.set_meta("bleed", 4.0)
	return hd


static func _hit(s, list: Array, dmg: float, knock: float, flags: String) -> void:
	var p: Player = s.player
	for e in list:
		if not _alive(e):
			continue
		var hd := _hd(s, dmg, knock, flags)
		if "pull" in flags:
			s._strike_toward(e, hd, p.global_position - (e as Node3D).global_position)
		else:
			s._strike(e, hd)
		_impact(s, e, flags)


static func _impact(s, e: Node3D, flags: String) -> void:
	var at := e.global_position + Vector3(0, 1.1, 0)
	_net(s).fx("impact", [at, s._col(FXS.ACCENT)])
	if s._elem():
		_net(s).fx("elem_hit", [s._tree(), at, s._dir])
	if "launch" in flags:
		_net(s).fx("speed_lines", [at, Vector3.UP, s._col(), 6, 2.0, 0.25, randi() % 1000])
	if "spike" in flags or "down" in flags:
		_net(s).fx("dust", [e.global_position + Vector3(0, 0.05, 0), 6, 0.6])


## A shot from the gun hand at `e` (null: into the air ahead).
static func _shoot(s, e: Node3D, dmg: float, flags: String) -> void:
	var p: Player = s.player
	var from: Vector3 = s._muzzle()
	var to: Vector3 = s._body_center(e) if e else from + s._dir * 14.0
	p.body_model.play("shoot_r", 0.25)
	_net(s).fx("tracer", [from, to, s._col(FXS.CORE)])
	_net(s).fx("muzzle_sparks", [from, (to - from).normalized(), 8])
	_net(s).fx("sfx", ["gunshot", from, -2.0, 0.08, 1.05])
	p.cam_shake(0.05)
	if e:
		s._strike(e, _hd(s, dmg, 2.0, flags + " ranged"))
		_impact(s, e, flags)


## Everyone within `reach` in front (cos half-angle `cone`).
static func _cone(s, reach: float, cone: float) -> Array:
	var p: Player = s.player
	var out: Array = []
	for e in s._pc.enemies_in(p.global_position + Vector3(0, 0.9, 0) + s._dir * reach * 0.5, reach):
		var d: Vector3 = (e as Node3D).global_position - p.global_position
		d.y = 0.0
		if d.length() <= reach and (d.length() < 0.6 or d.normalized().dot(s._dir) >= cone):
			out.append(e)
	return out


## Everyone on a line `length` ahead, `width` either side.
static func _line(s, length: float, width: float) -> Array:
	var p: Player = s.player
	var out: Array = []
	for e in s._pc.enemies_in(p.global_position + Vector3(0, 0.9, 0) + s._dir * length * 0.5, length * 0.5 + width):
		var d: Vector3 = (e as Node3D).global_position - p.global_position
		d.y = 0.0
		var along := d.dot(s._dir)
		if along >= -0.5 and along <= length and (d - s._dir * along).length() <= width:
			out.append(e)
	return out


static func _tip(s) -> Vector3:
	match s._tree():
		"black_leg":
			return BlackLegArts.foot(s.player, true)
		"pistol":
			return s._muzzle()
	return s._blade_tip()


static func _trail(s, secs: float) -> void:
	var p: Player = s.player
	match s._tree():
		"black_leg":
			_net(s).fx("kick_swoosh", [p.body_model, secs, s._col()])
		"pistol":
			pass
		_:
			_net(s).fx("blade_swoosh", [p.body_model, secs, s._col()])


## Down into the ground: dust, stones, cracks out, a ring, a rumble.
static func _slam(s, r: float) -> void:
	var p: Player = s.player
	var at := p.global_position
	_net(s).fx("dust_ring", [at, 14, 0.9])
	_net(s).fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP, 8, Color(0.42, 0.36, 0.3), 5.0])
	var sd := randi() % 10000
	for i in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		_net(s).fx("ground_crack", [at, Vector3(cos(a), 0.0, sin(a)), r * 0.8, s._col(FXS.ACCENT) if s._elem() else Color(0, 0, 0, 0), sd + i, 0.1])
	_net(s).fx("ring", [at + Vector3(0, 0.12, 0), Vector3.UP, r, s._col(), 0.3, 0.16])
	_net(s).fx("sfx", ["rock_crash", at, -4.0, 0.06, 1.0])
	s._spray(at + Vector3(0, 0.3, 0), Vector3.UP, 10, 4.0)
	p.cam_shake(0.22)
