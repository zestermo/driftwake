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
	CombatManager.apply_camera_shake(0.2 if big else 0.1)


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
	CombatManager.apply_camera_shake(0.3)
	CombatManager.apply_camera_kick(0.14, 0.3)


## Everyone within `r` of `at` (not in `already`) takes `hit`.
static func burst(p: Player, at: Vector3, r: float, hit: HitData, already: Array) -> void:
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = r
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.6, 0))
	q.collision_mask = 32
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
		return Player.HAKI_TRAIL
	return FX.tree_col("hammer", FX.EDGE) if elem else FX.tree_col("plain", FX.ACCENT)


# --------------------------------------------------------------------------
# The techniques: Skullcracker (a hop and the head down on the one in front), Rolling Quake (three slams, each
# shockwave wider), Cyclone Crusher (three turns walking, then the ground), Titan's Fall (ult: up high, down
# in a great ring, stone heaving up under them, two aftershocks). Poses: ham_skull, ham_quakes, ham_cyclone,
# ham_titan (+ ham_land).
# --------------------------------------------------------------------------
const SKULL_REACH := 4.0
const SKULL_AT := 0.44
const SKULL_DAMAGE := 30.0

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
		_:
			return false
	return true


## Everyone within `r` of `at` takes a technique hit (through the state: the ult meter, wounds, on-hit).
static func _hits_at(s, at: Vector3, r: float, base: float, knock: float, down: bool) -> void:
	for e in s._pc.enemies_in(at + Vector3(0, 0.9, 0), r):
		var hd: HitData = s._hd(base, knock, down)
		hd.breaker = true
		s._strike(e, hd)


## A hop and the head straight down on the one in front: through any guard, their wind-up broken, reeling.
static func _skull(s, delta: float) -> void:
	var p: Player = s.player
	if s._once("hop", 0.1):
		var to: Vector3 = s._target.global_position - p.global_position if is_instance_valid(s._target) else s._dir
		to.y = 0.0
		p.velocity = s._dir * maxf(to.length() - 1.3, 0.0) / 0.4 + Vector3.UP * 4.5
		Net.fx("dust", [p.global_position + Vector3(0, 0.05, 0), 6, 0.6])
	s.apply_gravity(delta)
	p.move_and_slide()
	if s._once("glint", SKULL_AT - 0.08):
		Net.fx("glint", [head(p), s._col(FX.CORE), 0.9])
	if s._once("strike", SKULL_AT) and s._target and is_instance_valid(s._target):
		var hd: HitData = s._hd(SKULL_DAMAGE, 8.0, false)
		hd.unblockable = true
		hd.breaker = true
		hd.stagger_duration = 1.2
		s._strike(s._target, hd)
		var at: Vector3 = s._body_center(s._target) + Vector3(0, 0.45, 0)
		Net.fx("impact", [at, s._col(FX.CORE)])
		Net.fx("ring", [at, Vector3.UP, 1.3, s._col(), 0.24, 0.2])
		Net.fx("dust_ring", [s._target.global_position, 10, 0.8])
		Net.fx("sfx", ["thud", at, 0.0, 0.05, 0.75])
		Net.fx("sfx", ["crunch", at, -4.0, 0.05, 0.8])
		if s._elem():
			Net.fx("rock_spikes", [s._target.global_position, 1.3, 5, randi() % 10000, 0.8, 0.6])
			Net.fx("element", ["hammer", at, Vector3.UP, 8, 4.0])
		CombatManager.apply_hitstop(0.1, [p])
		CombatManager.apply_camera_kick(0.16, 0.3)
		CombatManager.apply_camera_shake(0.2)
	if s.t > SKULL_AT and p.is_on_floor():
		p.velocity.x = 0.0
		p.velocity.z = 0.0


## Three slams stepping in, each a shockwave from where the head bites, wider than the last; the third puts
## them down.
static func _quakes(s, delta: float) -> void:
	var p: Player = s.player
	if s.t < QUAKES_AT[2]:
		s._drift(delta, 1.6)
	else:
		s._rooted(delta, 0.0)
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
		s._spin_hits(CYCLONE_R, CYCLONE_EVERY, CYCLONE_DAMAGE, 99.0, 0.0, CYCLONE_SPIN.x)
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
		CombatManager.apply_camera_shake(0.45)
		CombatManager.apply_camera_kick(0.22, 0.45)
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
				CombatManager.apply_camera_shake(0.18)
				for e in s._pc.enemies_in(at + Vector3(0, 0.9, 0), TITAN_R):
					var hd: HitData = s._hd(TITAN_AFTER_DAMAGE, 3.0, false)
					hd.stagger_duration = 0.4
					s._strike(e, hd)
