class_name HammerArts
## The hammer's shared blows and its techniques (tree "hammer": earth - sandstone shockwaves, rock thrown up,
## cracks and stone spikes). thud() (the head into the ground: the combo's smash and spin), quake() (a
## shockwave: the heavy, Hammerfall's landing, the techniques). Techniques are run by TechniqueState (`s`: its
## helpers and timeline); enter() and update() return false for ids that aren't theirs. Poses in HammerMoves.


## Where the hammer's head is now.
static func head(p: Player) -> Vector3:
	var w: MeshInstance3D = p.body_model.weapon
	return w.global_transform * Vector3(0, 0, w.mesh.get_aabb().position.z * 0.9)


## The ground under the head.
static func head_ground(p: Player) -> Vector3:
	var h := head(p)
	return Vector3(h.x, p.global_position.y, h.z)


## The head into the ground (a combo blow): dust, a few stones and a ring of dust; `big` (the spin's end) cracks
## the ground. With the element on every blow (the tree's tier 2) the rock and ring take its colours.
static func thud(p: Player, big: bool) -> void:
	var at := head_ground(p)
	var elem := p.progression.elemental("hammer", 2)
	var face := -p.player_model.global_basis.z
	Net.fx("heavy_dust", [at, 10 if big else 6, 0.7 if big else 0.5])
	Net.fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP + face * 0.3, 6 if big else 3, FX.tree_col("hammer", FX.ACCENT), 4.0])
	Net.fx("ring", [at, Vector3.UP, 2.4 if big else 1.3, _ring_col(p, elem), 0.26, 0.16])
	if big:
		Net.fx("ground_crack", [at, face, 2.2, Color(0, 0, 0, 0), randi() % 10000, 0.1])
	if elem:
		Net.fx("element", ["hammer", at + Vector3(0, 0.2, 0), Vector3.UP, 8 if big else 5, 4.0])
	Net.fx("sfx", ["thud", at, -3.0 if big else -7.0, 0.06, 0.7 if big else 0.85])
	p.cam_shake(0.2 if big else 0.1)


## A shockwave from `at`: everyone within `r` (not in `already`) takes `hit`; rings racing out over the ground,
## dust, rock, cracks running out, the ground shaking. `elem`: stone spikes heave up round it and the rings take
## the tree's colours.
static func quake(p: Player, at: Vector3, r: float, hit: HitData, already: Array, elem: bool) -> void:
	quake_fx(p, at, r, elem)
	burst(p, at, r, hit, already)


## A shockwave's show (no hits): rings, dust, rock, cracks, the shake; stone spikes with the element.
static func quake_fx(p: Player, at: Vector3, r: float, elem: bool) -> void:
	var col := _ring_col(p, elem)
	var face := -p.player_model.global_basis.z
	Net.fx("ring", [at, Vector3.UP, r, col, 0.32, 0.12])
	Net.fx("ring", [at, Vector3.UP, r * 0.6, FX.tree_col("hammer" if elem else "plain", FX.CORE), 0.22, 0.2])
	Net.fx("dust_ring", [at, 18, 1.1])
	Net.fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP, 8, FX.tree_col("hammer", FX.ACCENT), 5.0])
	Net.fx("impact", [at + Vector3(0, 0.2, 0), FX.tree_col("hammer" if elem else "plain", FX.CORE)])
	for k in 3:
		var d := face.rotated(Vector3.UP, (k - 1) * 0.9 + randf_range(-0.2, 0.2))
		Net.fx("ground_crack", [at, d, r * 0.8, Color(0, 0, 0, 0), randi() % 10000, 0.12])
	if elem:
		Net.fx("rock_spikes", [at, r * 0.7, 7, randi() % 10000, 1.0, 0.8])
		Net.fx("element", ["hammer", at + Vector3(0, 0.3, 0), Vector3.UP, 10, 5.0])
	Net.fx("sfx", ["thud", at, 2.0, 0.05, 0.6])
	p.cam_shake(0.3)
	p.cam_kick(0.14, 0.3)


## Everyone within `r` of `at` (not in `already`) takes `hit`.
static func burst(p: Player, at: Vector3, r: float, hit: HitData, already: Array) -> void:
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = r
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.6, 0))
	q.collision_mask = p.foe_mask()
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for res in p.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var area := res["collider"] as Hurtbox
		if area and area.owner and area.owner != p and not (area.owner in already):
			already.append(area.owner)
			area.take_hit(hit, p)


## A shockwave's ring: dust before the element, sandstone after; black with a Haki coat.
static func _ring_col(p: Player, elem: bool) -> Color:
	if p.power.buff("coat"):
		return p.progression.will_tint().lightened(0.2)
	return FX.tree_col("hammer", FX.EDGE) if elem else FX.tree_col("plain", FX.ACCENT)


# --------------------------------------------------------------------------
# The techniques: Skullcracker (a hop and the head down on the one in front), Rolling Quake (three slams, each
# shockwave wider), Cyclone Crusher (three turns walking, then the ground), Titan's Fall (ult: up high, down
# in a great ring, stone heaving up under them, two aftershocks), Cannonball Swing (a golf drive: the light foe
# launched, bowling everyone it reaches), Anvil Counter (planted, the first blow rings off, the head ripped up into
# them). Poses: ham_skull, ham_quakes, ham_cyclone, ham_titan (+ ham_land), ham_drive, ham_anvil, ham_rip.
# --------------------------------------------------------------------------
const SKULL_REACH := 4.0
## The blow lands with the feet: the hop (SKULL_HOP up at 0.1 s) comes down here (Player gravity 20, falling x1.6).
const SKULL_AT := 0.46
const SKULL_HOP := 4.0
const SKULL_DAMAGE := 30.0
const SKULL_SLAM := 0.6

## Rolling Quake's third blow hops in first (QUAKES_HOP up at QUAKES_HOP_AT, down just before the slam).
const QUAKES_HOP_AT := 0.84
const QUAKES_HOP := 3.4

const DRIVE_REACH := 4.0
const DRIVE_DUR := 1.1
const DRIVE_AT := 0.5
const DRIVE_DAMAGE := 26.0
## The light foe's launch: (along, up) m/s; the bowling runs down DRIVE_LINE m at the along speed.
const DRIVE_LAUNCH := Vector2(12.5, 6.5)
const DRIVE_LINE := 10.0
const DRIVE_BOWL_R := 1.7
const DRIVE_BOWL_DAMAGE := 14.0
const DRIVE_STAGGER := 2.2

const ANVIL_PLANT := 0.16
const ANVIL_BRACE := 1.0
const ANVIL_RISE := 0.25
const ANVIL_REFUND := 0.5
const RIP_DUR := 0.62
const RIP_AT := 0.16
const RIP_REACH := 3.4
const RIP_DAMAGE := 28.0
const ANVIL_WAVE_R := 3.0
const ANVIL_WAVE_DAMAGE := 10.0

const QUAKES_AT := [0.36, 0.76, 1.16]
const QUAKES_R := [2.6, 3.2, 4.2]
const QUAKES_DAMAGE := [10.0, 12.0, 20.0]

const CYCLONE_DUR := 1.7
const CYCLONE_SPIN := Vector2(0.3, 1.3)
const CYCLONE_EVERY := 0.2
const CYCLONE_R := 3.4
const CYCLONE_DAMAGE := 7.0
const CYCLONE_SLAM := 1.38
const CYCLONE_FINAL := 18.0

const TITAN_DUR := 2.4
const TITAN_JUMP := 0.18
const TITAN_UP := 11.0
const TITAN_APEX := 0.62
const TITAN_HANG := 0.86
const TITAN_DROP := 32.0
const TITAN_R := 7.0
const TITAN_DAMAGE := 45.0
const TITAN_AFTER := [0.4, 0.8]
const TITAN_AFTER_DAMAGE := 8.0


static func enter(s, id: String) -> bool:
	var p: Player = s.player
	match id:
		"skullcracker":
			s._target = s._aimed(SKULL_REACH)
			if s._target == null:
				s._target = s._nearest(SKULL_REACH, true)
			if s._target == null:
				s._refund("Nobody close enough")
				return true
			s.dur = 0.9
			s._dir = s._flat_to(s._target)
			s.face_direction(s._dir, 1.0)
			p.body_model.play("ham_skull", s.dur)
			Net.fx("sfx", ["whoosh", p.global_position, -8.0, 0.05, 0.7])
		"rolling_quake":
			s.dur = 1.5
			p.body_model.play("ham_quakes", s.dur)
			Net.fx("sfx", ["whoosh_big", p.global_position, -8.0, 0.05, 0.7])
		"cyclone_crusher":
			s.dur = CYCLONE_DUR
			p.body_model.play("ham_cyclone", s.dur)
			Net.fx("sfx", ["whoosh_big", p.global_position, -7.0, 0.05, 0.75])
		"titans_fall":
			s.dur = TITAN_DUR
			s._victims = s._closest(TITAN_R + 3.0, 8)
			p.hurtbox.set_deferred("monitorable", false)
			p.body_model.play("ham_titan", 1.0)
			Net.fx("gather", [p.global_position + Vector3(0, 0.3, 0), 2.8, s._col(FX.ACCENT) if s._elem() else s._col(), 0.3, 18])
			Net.fx("dust_ring", [p.global_position, 10, 0.9])
		"cannonball_swing":
			s._target = s._aimed(DRIVE_REACH)
			if s._target == null:
				s._target = s._nearest(DRIVE_REACH, true)
			if s._target == null:
				s._refund("Nobody close enough")
				return true
			s.dur = DRIVE_DUR
			s._dir = s._flat_to(s._target)
			s.face_direction(s._dir, 1.0)
			p.body_model.play("ham_drive", s.dur)
			Net.fx("sfx", ["whoosh", p.global_position, -9.0, 0.05, 0.65])
		"anvil_counter":
			s.dur = ANVIL_BRACE + ANVIL_RISE
			p.is_parrying = true
			s._done["tick"] = Engine.get_physics_frames()
			p.body_model.play("ham_anvil", s.dur)
		_:
			return false
	return true


static func update(s, delta: float) -> bool:
	match s.id:
		"skullcracker":
			_skull(s, delta)
		"rolling_quake":
			_quakes(s, delta)
		"cyclone_crusher":
			_cyclone(s, delta)
		"titans_fall":
			_titan(s, delta)
		"cannonball_swing":
			_drive(s, delta)
		"anvil_counter":
			_anvil(s, delta)
		_:
			return false
	return true


## Everyone within `r` of `at` takes a technique hit (through the state: the ult meter, wounds, on-hit).
static func _hits_at(s, at: Vector3, r: float, base: float, knock: float, down: bool) -> void:
	for e in s._pc.enemies_in(at + Vector3(0, 0.9, 0), r):
		var hd: HitData = s._hd(base, knock, down)
		hd.breaker = true
		s._strike(e, hd)


## A hop and the head straight down on the one in front as the feet land: through any guard, their wind-up
## broken, reeling; then on down into the ground.
static func _skull(s, delta: float) -> void:
	var p: Player = s.player
	if s._once("hop", 0.1):
		var to: Vector3 = s._target.global_position - p.global_position if is_instance_valid(s._target) else s._dir
		to.y = 0.0
		p.velocity = s._dir * maxf(to.length() - 1.4, 0.0) / (SKULL_AT - 0.1) + Vector3.UP * SKULL_HOP
		Net.fx("dust", [p.global_position + Vector3(0, 0.05, 0), 6, 0.6])
	s.apply_gravity(delta)
	p.move_and_slide()
	if s._once("glint", SKULL_AT - 0.1):
		Net.fx("glint", [head(p), s._col(FX.CORE), 0.9])
	if s._once("swoosh", SKULL_AT - 0.1):
		Net.fx("blade_swoosh", [p.body_model, SKULL_SLAM - SKULL_AT + 0.12, s._col()])
	if not s._done.has("strike") and s.t > 0.25 and (p.is_on_floor() or s.t >= SKULL_AT + 0.06):
		s._done["strike"] = true
		p.velocity = Vector3.ZERO
		p.squash(-2.5)
		var at := head(p)
		Net.fx("dust_ring", [p.global_position, 8, 0.6])
		if s._target and is_instance_valid(s._target):
			var hd: HitData = s._hd(SKULL_DAMAGE, 8.0, false)
			hd.unblockable = true
			hd.breaker = true
			hd.stagger_duration = 1.2
			s._strike(s._target, hd)
			Net.fx("impact", [at, s._col(FX.CORE)])
			Net.fx("ring", [at, s._dir, 1.1, s._col(), 0.2, 0.18])
			Net.fx("sfx", ["crunch", at, -2.0, 0.05, 0.8])
			if s._elem():
				Net.fx("element", ["hammer", at, Vector3.UP, 8, 4.0])
			CombatManager.apply_hitstop(0.1, [p])
			s.player.cam_kick(0.16, 0.3)
	if s._once("slam", SKULL_SLAM):
		thud(p, false)
		if s._elem():
			Net.fx("rock_spikes", [head_ground(p), 1.3, 5, randi() % 10000, 0.8, 0.6])
	if s._done.has("strike"):
		p.velocity.x = 0.0
		p.velocity.z = 0.0


## Three slams stepping in, each a shockwave from where the head bites, wider than the last: a flat sweep into
## the ground at the left, a rising backhand looped over into the right, a hop and the overhead; the third puts
## them down.
static func _quakes(s, delta: float) -> void:
	var p: Player = s.player
	if s.t < QUAKES_AT[2]:
		s._drift(delta, 1.6)
	else:
		s._rooted(delta, 0.0)
	if s._once("swoosh", 0.24):
		Net.fx("blade_swoosh", [p.body_model, QUAKES_AT[2] - 0.2, s._col()])
	if s._once("hop", QUAKES_HOP_AT):
		p.velocity.y = QUAKES_HOP
		p.squash(2.0)
	for i in 3:
		if s._once("glint%d" % i, float(QUAKES_AT[i]) - 0.07):
			Net.fx("glint", [head(p), s._col(FX.CORE), 0.7])
		if not s._once("slam%d" % i, QUAKES_AT[i]):
			continue
		var last: bool = i == 2
		var at := head_ground(p)
		quake_fx(p, at, QUAKES_R[i], s._elem())
		_hits_at(s, at, QUAKES_R[i], QUAKES_DAMAGE[i], 10.0 if last else 6.0, last)
		p.squash(-3.0 if last else -2.0)
		if last:
			Net.fx("sfx", ["crunch", at, -2.0, 0.05, 0.6])
			CombatManager.apply_hitstop(0.08, [p])


## Three turns walking with the hammer out, battering everyone about you, then the head into the ground in a
## shockwave that throws them down.
static func _cyclone(s, delta: float) -> void:
	var p: Player = s.player
	if s.t >= CYCLONE_SPIN.x and s.t < CYCLONE_SPIN.y:
		s._drift(delta, 2.2)
	else:
		s._rooted(delta, 0.0)
	if s._once("swoosh", CYCLONE_SPIN.x):
		Net.fx("blade_swoosh", [p.body_model, CYCLONE_SPIN.y - CYCLONE_SPIN.x, s._col()])
	# (its own burst is the slam: the turns' end is set past the move so _spin_hits never bursts)
	if s.t < CYCLONE_SPIN.y:
		s._spin_hits(CYCLONE_R, CYCLONE_EVERY, CYCLONE_DAMAGE, 99.0, 0.0, CYCLONE_SPIN.x, true)
	if s._once("slam", CYCLONE_SLAM):
		var at := head_ground(p)
		quake_fx(p, at, CYCLONE_R + 0.4, s._elem())
		_hits_at(s, at, CYCLONE_R + 0.4, CYCLONE_FINAL, 11.0, true)
		CombatManager.apply_hitstop(0.08, [p])


## Up high with the hammer heaved overhead (the moment at the top), down with the whole weight of it: a great ring
## that throws everyone down (stone heaving up under each with the element), then two aftershocks.
static func _titan(s, delta: float) -> void:
	var p: Player = s.player
	var landed: bool = s._done.has("slam")
	if s.t < TITAN_JUMP or landed:
		s._rooted(delta, 0.0)
	elif s.t < TITAN_APEX:
		p.velocity = Vector3(0, TITAN_UP * (1.0 - (s.t - TITAN_JUMP) / (TITAN_APEX - TITAN_JUMP)), 0)
		p.move_and_slide()
	elif s.t < TITAN_HANG:
		p.velocity = Vector3.ZERO
		p.move_and_slide()
	else:
		p.velocity = Vector3(0, -TITAN_DROP, 0)
		p.move_and_slide()
	if s._once("jump", TITAN_JUMP):
		Net.fx("dust_ring", [p.global_position, 14, 1.0])
		Net.fx("sfx", ["whoosh_big", p.global_position, -3.0, 0.05, 0.6])
		p.squash(3.0)
	if s._once("moment", TITAN_APEX):
		s._moment(0.35, 0.3, 0.5, 0.3)
		Net.fx("glint", [head(p), s._col(FX.CORE), 1.4])
		Net.fx("ring", [p.global_position + Vector3(0, 1.0, 0), Vector3.UP, 3.0, s._col(), 0.35, 0.1])
	if not landed and s.t > TITAN_HANG and (p.is_on_floor() or s.t > 1.6):
		s._done["slam"] = true
		s._done["slam_t"] = s.t
		p.velocity = Vector3.ZERO
		p.body_model.play("ham_land", 1.0)
		p.squash(-6.0)
		var at := p.global_position - p.player_model.global_basis.z * 1.2
		var elem: bool = s._elem()
		quake_fx(p, at, TITAN_R, elem)
		Net.fx("ring", [at, Vector3.UP, TITAN_R * 1.3, s._col(FX.ACCENT) if elem else s._col(), 0.5, 0.08])
		for k in 6:
			Net.fx("ground_crack", [at, Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 6.0 + randf_range(-0.2, 0.2)), TITAN_R, Color(0, 0, 0, 0), randi() % 10000, 0.18])
		Net.fx("screen_flash", [p.global_position, Color(s._col(FX.CORE).r, s._col(FX.CORE).g, s._col(FX.CORE).b, 0.35), 0.25])
		Net.fx("sfx", ["crunch", at, 2.0, 0.05, 0.5])
		_hits_at(s, at, TITAN_R, TITAN_DAMAGE, 12.0, true)
		if elem:
			Net.fx("rock_spikes", [at, TITAN_R * 0.8, 12, randi() % 10000, 1.8, 1.1])
			for e in s._victims:
				if is_instance_valid(e):
					Net.fx("rock_spikes", [(e as Node3D).global_position, 0.7, 4, randi() % 10000, 1.3, 0.8])
		else:
			Net.fx("debris", [at + Vector3(0, 0.2, 0), Vector3.UP, 14, FX.tree_col("hammer", FX.ACCENT), 7.0])
		CombatManager.apply_hitstop(0.12, [p])
		s.player.cam_shake(0.45)
		s.player.cam_kick(0.22, 0.45)
		p.hurtbox.set_deferred("monitorable", true)
	if landed:
		var since: float = s.t - float(s._done["slam_t"])
		for i in 2:
			if since >= float(TITAN_AFTER[i]) and not s._done.has("after%d" % i):
				s._done["after%d" % i] = true
				var at := p.global_position - p.player_model.global_basis.z * 1.2
				Net.fx("ring", [at, Vector3.UP, TITAN_R * (0.7 + 0.2 * i), s._col(), 0.3, 0.1])
				Net.fx("dust_ring", [at, 10, 0.9])
				Net.fx("sfx", ["thud", at, -4.0, 0.05, 0.55])
				s.player.cam_shake(0.18)
				for e in s._pc.enemies_in(at + Vector3(0, 0.9, 0), TITAN_R):
					var hd: HitData = s._hd(TITAN_AFTER_DAMAGE, 3.0, false)
					hd.stagger_duration = 0.4
					s._strike(e, hd)


## A golf drive: stepping in, the hammer taken back high behind, swept down past the ground and up through the
## one in front. A light foe is launched (DRIVE_LAUNCH, a real ragdoll on every screen) and everyone the body
## reaches down the line is knocked flat; anyone heavier, or a boss, takes a long stagger instead.
static func _drive(s, delta: float) -> void:
	var p: Player = s.player
	var alive: bool = s._target != null and is_instance_valid(s._target)
	if s.t < DRIVE_AT - 0.08 and alive:
		var to: Vector3 = s._target.global_position - p.global_position
		to.y = 0.0
		s._drift(delta, clampf((to.length() - 1.8) / maxf(DRIVE_AT - 0.08 - s.t, 0.05), 0.0, 10.0))
	else:
		s._rooted(delta, 0.0)
	if s._once("swoosh", 0.36):
		Net.fx("blade_swoosh", [p.body_model, 0.34, s._col()])
	if s._once("glint", DRIVE_AT - 0.12):
		Net.fx("glint", [head(p), s._col(FX.CORE), 0.8])
	if s._once("scrape", DRIVE_AT - 0.05):
		var g := head_ground(p)
		Net.fx("dust", [g + Vector3(0, 0.05, 0), 8, 0.6])
		Net.fx("debris", [g + Vector3(0, 0.1, 0), s._dir + Vector3.UP, 4, FX.tree_col("hammer", FX.ACCENT), 5.0])
	if s._once("drive", DRIVE_AT):
		_drive_hit(s, alive)
	if s._done.has("from") and s.t > DRIVE_AT:
		var from: Vector3 = s._done["from"]
		var gone := minf((s.t - DRIVE_AT) * DRIVE_LAUNCH.x, DRIVE_LINE)
		var ball: Vector3 = from + s._dir * gone
		for e in s._pc.enemies_in(ball + Vector3(0, 0.8, 0), DRIVE_BOWL_R):
			if e in s._hit:
				continue
			s._hit.append(e)
			var hd: HitData = s._hd(DRIVE_BOWL_DAMAGE, 10.0, true)
			hd.impact = "punch_heavy"
			s._strike_toward(e, hd, s._dir + ((e as Node3D).global_position - ball).normalized() * 0.3)
			Net.fx("dust_ring", [(e as Node3D).global_position, 8, 0.7])
			Net.fx("sfx", ["thud", (e as Node3D).global_position, -2.0, 0.05, 0.8])
		for k in 3:
			if s._once("dust%d" % k, DRIVE_AT + 0.25 + k * 0.2):
				Net.fx("dust", [from + s._dir * minf((0.25 + k * 0.2) * DRIVE_LAUNCH.x, DRIVE_LINE) + Vector3(0, 0.1, 0), 4, 0.6])
		if gone >= DRIVE_LINE and s._once("down", 0.0):
			Net.fx("dust_ring", [ball, 12, 0.9])
			Net.fx("sfx", ["thud", ball, 0.0, 0.05, 0.7])
			if s._elem():
				Net.fx("rock_spikes", [ball, 1.2, 5, randi() % 10000, 0.9, 0.6])


static func _drive_hit(s, alive: bool) -> void:
	var p: Player = s.player
	var at := head(p)
	Net.fx("ring", [at, s._dir, 1.4, s._col(), 0.22, 0.16])
	Net.fx("sfx", ["whoosh_big", at, -4.0, 0.05, 0.8])
	p.squash(-2.0)
	s.player.cam_kick(0.14, 0.3)
	if not alive or (s._target as Node3D).global_position.distance_to(p.global_position) > 3.4:
		return
	var e: Node3D = s._target
	var hd: HitData = s._hd(DRIVE_DAMAGE, 4.0, false)
	hd.unblockable = true
	hd.breaker = true
	hd.impact = "punch_heavy"
	Net.fx("impact", [s._body_center(e), s._col(FX.ACCENT)])
	Net.fx("sfx", ["crunch", at, -1.0, 0.05, 0.7])
	CombatManager.apply_hitstop(0.1, [p])
	if FistArts.throwable(e) and e.has_method("launched"):
		hd.stagger_duration = 0.2
		hd.hitstop_duration = 0.0
		s._strike(e, hd)
		e.call("launched", s._dir * DRIVE_LAUNCH.x + Vector3.UP * DRIVE_LAUNCH.y)
		s._hit.append(e)
		s._done["from"] = e.global_position
		Net.fx("speed_lines", [s._body_center(e), (s._dir + Vector3.UP * 0.5).normalized(), Color(1.0, 0.97, 0.9), 8, 2.0, 0.2, randi() % 1000])
		s._spray(s._body_center(e), s._dir + Vector3.UP * 0.5, 10, 6.0)
	else:
		hd.stagger_duration = DRIVE_STAGGER
		s._strike(e, hd)
		Net.fx("ring", [s._body_center(e), Vector3.UP, 1.2, s._col(FX.CORE), 0.3, 0.12])


## Planted: the head dropped onto the ground ahead and both hands braced on the butt (a parry for ANVIL_BRACE s).
## The first blow rings off it and you rip the head up into their chin, a shockwave at your feet; nothing comes:
## half the energy back.
static func _anvil(s, delta: float) -> void:
	var p: Player = s.player
	s._rooted(delta, 0.0)
	if s._once("plant", ANVIL_PLANT):
		var g := head_ground(p)
		Net.fx("dust", [g + Vector3(0, 0.05, 0), 6, 0.6])
		Net.fx("ring", [g + Vector3(0, 0.05, 0), Vector3.UP, 1.0, _ring_col(p, s._elem()), 0.2, 0.18])
		Net.fx("sfx", ["thud", g, -5.0, 0.05, 0.8])
		s.player.cam_shake(0.08)
	if not s._done.has("rip"):
		if p.parried_tick >= int(s._done["tick"]) and is_instance_valid(p.parried_by):
			_ring_off(s, p.parried_by)
		elif s._once("open", ANVIL_BRACE):
			p.is_parrying = false
			s._pc.energy += float(Skills.get_skill("anvil_counter")["cost"]) * ANVIL_REFUND
		return
	var rip: float = s._done["rip"]
	if s._once("swoosh", rip + 0.06):
		Net.fx("blade_swoosh", [p.body_model, 0.24, s._col()])
	if not s._once("rip_hit", rip + RIP_AT):
		return
	var at := head(p)
	var e: Node3D = s._target
	if is_instance_valid(e) and e.global_position.distance_to(p.global_position) < RIP_REACH:
		var hd: HitData = s._hd(RIP_DAMAGE, 12.0, true)
		hd.unblockable = true
		hd.breaker = true
		hd.impact = "punch_heavy"
		s._strike_toward(e, hd, s._flat_to(e))
		Net.fx("impact", [at, s._col(FX.ACCENT)])
	var feet: Vector3 = p.global_position + s._dir * 0.5
	quake_fx(p, feet, ANVIL_WAVE_R, s._elem())
	for o in s._pc.enemies_in(feet + Vector3(0, 0.9, 0), ANVIL_WAVE_R):
		if o == e:
			continue
		var hw: HitData = s._hd(ANVIL_WAVE_DAMAGE, 9.0, true)
		hw.breaker = true
		s._strike_toward(o, hw, s._flat_to(o))
	Net.fx("sfx", ["crunch", at, -2.0, 0.05, 0.7])
	p.squash(3.0)
	CombatManager.apply_hitstop(0.08, [p])


## The blow rings off the braced haft like a hammer on an anvil (the attacker reels: Player's parry told them), and
## the rip up begins.
static func _ring_off(s, foe: Node3D) -> void:
	var p: Player = s.player
	s._done["rip"] = s.t
	s._target = foe
	s.dur = s.t + RIP_DUR
	p.is_parrying = false
	s._dir = s._flat_to(foe)
	s.face_direction(s._dir, 1.0)
	p.body_model.play("ham_rip", RIP_DUR)
	var at: Vector3 = head(p).lerp(s._chest(), 0.6)
	Net.fx("ring", [at, s._dir, 1.5, s._col(FX.CORE), 0.3, 0.1])
	Net.fx("ring", [at, s._dir, 0.8, s._col(), 0.2, 0.16])
	Net.fx("parry_sparks", [at, s._dir])
	Net.fx("sfx", ["parry", at, 0.0, 0.05, 0.55])
	Net.fx("sfx", ["blip_high", at, -6.0, 0.0, 0.45])
	CombatManager.apply_hitstop(0.1, [p])
	s.player.cam_kick(0.12, 0.25)
