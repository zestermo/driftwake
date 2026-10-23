class_name GreatswordArts
## The greatsword's shared blows and its techniques (tree "greatsword": gale - white air pressure, a jade edge; gusts
## torn off the swings, crescents of air flung off the big ones). shape_hit() (a design's bleed on every cut),
## swing_fx() (a combo blow's show, bigger as its momentum builds), charged() / cleave_hit() / cleave_fx() (the
## charged cleave), fall_land() (Falling Cleave's landing). Techniques are run by TechniqueState (`s`: its helpers and
## timeline); enter() and update() return false for ids that aren't theirs. Poses in GreatswordMoves.


## Where the blade's point is now.
static func tip(p: Player) -> Vector3:
	var w: MeshInstance3D = p.body_model.weapon
	return w.global_transform * Vector3(0, 0, w.mesh.get_aabb().position.z * 0.92)


## A greatsword hit's design traits: the sawtooth's cuts open a wound.
static func shape_hit(p: Player, hit: HitData) -> void:
	var bleed := WeaponDesigns.great(p.equipped_weapon.design, "bleed", 0.0)
	if bleed > 0.0:
		hit.set_meta("bleed", bleed)


## The cleave's charge reached `level` (1, 2): air drawn in round the raised blade, a glint off it, a rising note; at
## the top a ring round the feet (and the wind torn round you with the element).
static func charged(p: Player, level: int) -> void:
	var at := tip(p)
	var elem := p.progression.elemental("greatsword")
	var col := FX.tree_col("greatsword" if elem else "plain", FX.EDGE if level == 1 else FX.CORE)
	Net.fx("gather", [at, 0.9 + 0.5 * level, col, 0.22, 8 + 6 * level])
	Net.fx("glint", [at, col, 0.6 + 0.3 * level])
	Net.fx("sfx", ["blip_high", at, -8.0, 0.0, 0.8 + 0.2 * level])
	if level == 2:
		Net.fx("ring", [p.global_position, Vector3.UP, 2.2, col, 0.35, 0.1])
		Net.fx("dust_ring", [p.global_position, 10, 0.7])
		if elem:
			Net.fx("element", ["greatsword", p.global_position + Vector3(0, 0.4, 0), Vector3.UP, 10, 4.0])
	p.squash(1.0 + level)


## The cleave's blow at charge `level` (0-2): through any wind-up and staggering long (x the design's weight); a full
## charge can't be blocked and knocks them flat.
static func cleave_hit(p: Player, hit: HitData, level: int) -> void:
	var wt := WeaponDesigns.great(p.equipped_weapon.design, "weight")
	hit.breaker = true
	hit.knockback_force = (9.0 + 3.0 * level) * wt
	hit.stagger_duration = (0.7 + 0.25 * level) * wt
	hit.hitstop_duration = 0.09 + 0.03 * level
	hit.camera_shake_intensity = 0.18 + 0.08 * level
	hit.knockdown = level == 2
	hit.unblockable = hit.unblockable or level == 2
	shape_hit(p, hit)


## A full-charge cleave's crescent of air: its damage.
const GALE_DAMAGE := 18.0

## The cleave meeting the ground ahead: a crack run out down its line, dust, a ring; harder the more it was charged;
## a full charge flings a crescent of air on down the line (Projectile "gale", in the tree's colours with the element).
static func cleave_fx(p: Player, level: int) -> void:
	var face := -p.player_model.global_basis.z
	face.y = 0.0
	face = face.normalized()
	var elem := p.progression.elemental("greatsword", 2)
	var tree := "greatsword" if elem else "plain"
	var at := p.global_position + face * 1.7
	Net.fx("ground_crack", [at - face * 0.4, face, 1.6 + 1.6 * level, Color(0, 0, 0, 0), randi() % 10000, 0.1])
	Net.fx("heavy_dust", [at, 8 + 4 * level, 0.6 + 0.15 * level])
	Net.fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP + face * 0.3, 3 + 2 * level, Color(0.35, 0.3, 0.25), 4.5])
	Net.fx("ring", [at, Vector3.UP, 1.4 + 0.7 * level, FX.tree_col(tree, FX.EDGE), 0.26, 0.12])
	Net.fx("sfx", ["thud", at, -4.0 + 2.0 * level, 0.05, 0.8 - 0.05 * level])
	if elem:
		Net.fx("element", ["greatsword", at + Vector3(0, 0.3, 0), face + Vector3.UP * 0.4, 8 + 4 * level, 5.0])
	if level == 2:
		Projectile.launch(p.get_tree(), "gale", p.global_position + Vector3(0, 1.2, 0) + face * 1.2, face, p, GALE_DAMAGE, "elem" if p.progression.elemental("greatsword") else "")
		Net.fx("sfx", ["whoosh_big", at, -2.0, 0.05, 0.65])
	p.cam_kick(0.12 + 0.06 * level, 0.3)


## A combo blow's show: with momentum built, a ring of air pressure off the point and a rising whoosh; with the
## element on every blow (the tree's tier 2) the wind tears off it. `big`: the turn or the running cleave.
static func swing_fx(p: Player, mom: int, big: bool) -> void:
	var at := tip(p)
	var face := -p.player_model.global_basis.z
	var elem := p.progression.elemental("greatsword", 2)
	var col := FX.tree_col("greatsword" if elem else "plain", FX.EDGE)
	if mom > 0 or big:
		Net.fx("ring", [at, face, 0.8 + 0.3 * mom + (0.5 if big else 0.0), col, 0.2, 0.12])
		Net.fx("sfx", ["whoosh_big", p.global_position, -9.0 + 1.5 * mom, 0.06, 0.85 + 0.08 * mom])
	if elem:
		Net.fx("element", ["greatsword", at, face + Vector3.UP * 0.2, 5 + 2 * mom, 4.0 + mom])
	if mom >= 2 or big:
		p.cam_kick(0.06 + 0.03 * mom, 0.22)


## Falling Cleave's landing: the blade driven into the ground ahead, a cleave line split out in front; everyone on it
## (not those struck on the way down) is knocked flat.
const FALL_LINE := 4.5
const FALL_DAMAGE := 18.0


static func fall_land(p: Player, already: Array, recover: float) -> void:
	p.body_model.play("gs_land", recover)
	p.squash(-5.0)
	var face := -p.player_model.global_basis.z
	face.y = 0.0
	face = face.normalized()
	var wt := WeaponDesigns.great(p.equipped_weapon.design, "weight")
	var hit := HitData.new()
	hit.damage = FALL_DAMAGE * p.damage_multiplier()
	hit.knockdown = true
	hit.breaker = true
	hit.knockback_force = 9.0 * wt
	hit.stagger_duration = 0.5
	hit.hitstop_duration = 0.07
	hit.camera_shake_intensity = 0.0
	hit.impact = "slice_heavy"
	hit.sever = true
	for e in p.power.enemies_in(p.global_position + face * FALL_LINE * 0.5 + Vector3(0, 0.8, 0), FALL_LINE * 0.6):
		var rel := (e as Node3D).global_position - p.global_position
		rel.y = 0.0
		var along := rel.dot(face)
		if e in already or along < -0.8 or along > FALL_LINE or (rel - face * along).length() > 1.5:
			continue
		var hb := (e as Node).get("hurtbox") as Hurtbox
		if hb:
			hb.take_hit(hit, p)
	cleave_fx(p, 1)
	p.cam_shake(0.25)


## A parried blow turned aside on the flat: the blade shoved out into them, a ring of air off it (the deflect pose
## sells the rest).
static func parried(p: Player, attacker: Node) -> void:
	var at := tip(p).lerp(p.global_position + Vector3(0, 1.1, 0), 0.6)
	var face := -p.player_model.global_basis.z
	var elem := p.progression.elemental("greatsword", 2)
	Net.fx("ring", [at, face, 1.1, FX.tree_col("greatsword" if elem else "plain", FX.EDGE), 0.2, 0.14])
	if elem:
		Net.fx("element", ["greatsword", at, face, 6, 4.0])
	if attacker is Node3D and is_instance_valid(attacker):
		p.cam_kick(0.08, 0.2)


# --------------------------------------------------------------------------
# The techniques: Guardbreaker (a rising cut that knocks the guard up, then the blade brought down on them), Crescent
# Gale (one huge flat sweep that flings a crescent of air down the line), Tempest Turns (three turns, each quicker
# than the last, the momentum breaking in a burst), Skysplitter (ult: up high, the moment, down in one cleave that
# splits the ground in a line and flings three crescents of air along it). Poses: gs_guardbreak, gs_crescent,
# gs_tempest, gs_sky (+ gs_land).
# --------------------------------------------------------------------------
const BREAK_REACH := 4.5
const BREAK_LIFT := 0.22
const BREAK_AT := 0.55
const BREAK_DAMAGE := [10.0, 30.0]

const CRESCENT_AT := 0.3
const CRESCENT_DAMAGE := 16.0
const CRESCENT_GALE := 24.0

## Updraft: the rising cut at UP_RISE, the leap after them to the apex, the cleave at UP_CLEAVE, the crash on landing.
const UP_DUR := 1.0
const UP_REACH := 4.0
const UP_RISE := 0.22
const UP_LEAP := 0.26
const UP_APEX := 0.58
const UP_CLEAVE := 0.7
const UP_V := 10.0
const UP_THROW := Vector2(1.5, 11.0)
const UP_DROP := 26.0
const UP_DAMAGE := [12.0, 22.0]
const UP_CRASH_R := 3.2
const UP_CRASH_DAMAGE := 12.0

## Gatekeeper: held up to GATE_MAX (at least GATE_MIN), then the wrench (RISE_DUR long, the cut at RISE_AT).
const GATE_MAX := 1.5
const GATE_MIN := 0.3
const RISE_DUR := 0.6
const RISE_AT := 0.16
const RISE_REACH := 3.2
const RISE_DAMAGE := 18.0
const RISE_GALE := 20.0

const TEMPEST_DUR := 1.7
const TEMPEST_R := 3.8
const TEMPEST_DAMAGE := 8.0
const TEMPEST_BURST := 1.42
const TEMPEST_FINAL := 24.0

const SKY_DUR := 2.3
const SKY_JUMP := 0.18
const SKY_UP := 10.0
const SKY_APEX := 0.55
const SKY_HANG := 0.78
const SKY_DROP := 30.0
const SKY_LINE := 12.0
const SKY_WIDTH := 1.8
const SKY_DAMAGE := 48.0
const SKY_RING := 4.0
const SKY_RING_DAMAGE := 22.0
const SKY_GALE := 26.0


static func enter(s, id: String) -> bool:
	var p: Player = s.player
	match id:
		"guardbreaker":
			s._target = s._aimed(BREAK_REACH)
			if s._target == null:
				s._target = s._nearest(BREAK_REACH, true)
			if s._target == null:
				s._refund("Nobody close enough")
				return true
			s.dur = 0.95
			s._dir = s._flat_to(s._target)
			s.face_direction(s._dir, 1.0)
			p.body_model.play("gs_guardbreak", s.dur)
			Net.fx("sfx", ["whoosh", p.global_position, -8.0, 0.05, 0.8])
		"crescent_gale":
			s.dur = 0.8
			p.body_model.play("gs_crescent", s.dur)
			Net.fx("gather", [tip(p), 1.0, s._col(), 0.2, 8])
		"updraft":
			s._target = s._aimed(UP_REACH)
			if s._target == null:
				s._target = s._nearest(UP_REACH, true)
			if s._target == null:
				s._refund("Nobody close enough")
				return true
			s.dur = 2.4
			s._dir = s._flat_to(s._target)
			s.face_direction(s._dir, 1.0)
			p.body_model.play("gs_updraft", UP_DUR)
			Net.fx("sfx", ["whoosh", p.global_position, -8.0, 0.05, 0.75])
		"gatekeeper":
			s.dur = GATE_MAX + RISE_DUR
			p.is_parrying = true
			s._pc.add_buff("bat_shots", GATE_MAX + 0.1)
			p.body_model.play("gs_gate", GATE_MAX)
			Net.fx("sfx", ["whoosh", p.global_position, -9.0, 0.05, 0.7])
		"tempest_turns":
			s.dur = TEMPEST_DUR
			p.body_model.play("gs_tempest", s.dur)
			Net.fx("sfx", ["whoosh_big", p.global_position, -8.0, 0.05, 0.8])
		"skysplitter":
			s.dur = SKY_DUR
			s._victims = s._closest(SKY_LINE, 8)
			p.hurtbox.set_deferred("monitorable", false)
			p.body_model.play("gs_sky", 1.0)
			Net.fx("gather", [p.global_position + Vector3(0, 0.6, 0), 2.6, s._col(FX.ACCENT) if s._elem() else s._col(), 0.3, 18])
			Net.fx("dust_ring", [p.global_position, 10, 0.9])
		_:
			return false
	return true


static func update(s, delta: float) -> bool:
	match s.id:
		"guardbreaker":
			_guardbreak(s, delta)
		"crescent_gale":
			_crescent(s, delta)
		"updraft":
			_updraft(s, delta)
		"gatekeeper":
			_gatekeeper(s, delta)
		"tempest_turns":
			_tempest(s, delta)
		"skysplitter":
			_sky(s, delta)
		_:
			return false
	return true


## Everyone on the line from `from` along `dir` (`length` long, `width` either side) takes a technique hit; how many.
static func _line(s, from: Vector3, dir: Vector3, length: float, width: float, base: float, knock: float, down: bool) -> int:
	var n := 0
	for e in s._pc.enemies_in(from + dir * length * 0.5 + Vector3(0, 0.8, 0), length * 0.6):
		var rel: Vector3 = (e as Node3D).global_position - from
		rel.y = 0.0
		var along := rel.dot(dir)
		if along < -0.8 or along > length or (rel - dir * along).length() > width:
			continue
		var hd: HitData = s._hd(base, knock, down)
		hd.breaker = true
		shape_hit(s.player, hd)
		s._strike(e, hd)
		n += 1
	return n


## A step in, a short rising cut that knocks their guard up (it can't be blocked), the blade wheeled on overhead, then
## brought straight down on them: through any guard, their wind-up broken, reeling.
static func _guardbreak(s, delta: float) -> void:
	var p: Player = s.player
	if s.t < BREAK_LIFT and s._target and is_instance_valid(s._target):
		var to: Vector3 = s._target.global_position - p.global_position
		to.y = 0.0
		s._drift(delta, clampf((to.length() - 1.7) / BREAK_LIFT, 0.0, 9.0))
	else:
		s._rooted(delta, 0.0)
	var alive: bool = s._target != null and is_instance_valid(s._target)
	# (the real blade's trail over the rising cut and over the crush, as gs_guardbreak keys them)
	if s._once("rise_trail", 0.12):
		Net.fx("blade_swoosh", [p.body_model, 0.18, s._col()])
	# (from over the top down, not while it's held overhead: started at 0.47 it laid a flat sheet up in the air)
	if s._once("crush_trail", 0.52):
		Net.fx("blade_swoosh", [p.body_model, 0.09, s._col()])
	if s._once("lift", BREAK_LIFT) and alive:
		var hd: HitData = s._hd(BREAK_DAMAGE[0], 1.0, false)
		hd.unblockable = true
		hd.breaker = true
		hd.stagger_duration = 0.9
		s._strike(s._target, hd)
		var at: Vector3 = s._body_center(s._target)
		Net.fx("parry_sparks", [at, s._dir])
		Net.fx("sfx", ["parry", at, -6.0, 0.05, 0.75])
	if s._once("glint", BREAK_AT - 0.08):
		Net.fx("glint", [tip(p), s._col(FX.CORE), 0.9])
	if s._once("crush", BREAK_AT) and alive:
		var hd: HitData = s._hd(BREAK_DAMAGE[1], 8.0, false)
		hd.unblockable = true
		hd.breaker = true
		hd.stagger_duration = 1.3 * WeaponDesigns.great(p.equipped_weapon.design, "weight")
		shape_hit(p, hd)
		s._strike(s._target, hd)
		var at: Vector3 = s._body_center(s._target) + Vector3(0, 0.3, 0)
		Net.fx("impact", [at, s._col(FX.CORE)])
		Net.fx("ring", [at, s._dir, 1.4, s._col(), 0.24, 0.16])
		Net.fx("ground_crack", [s._target.global_position - s._dir * 0.4, s._dir, 2.0, Color(0, 0, 0, 0), randi() % 10000, 0.1])
		Net.fx("sfx", ["slice_heavy", at, 0.0, 0.05, 0.8])
		if s._elem():
			Net.fx("element", ["greatsword", at, s._dir + Vector3.UP * 0.3, 10, 5.0])
		CombatManager.apply_hitstop(0.1, [p])
		s.player.cam_kick(0.16, 0.3)
		s.player.cam_shake(0.18)


## One huge flat sweep: everyone close in front cut, and a crescent of air flung off the edge down the line.
static func _crescent(s, delta: float) -> void:
	var p: Player = s.player
	if s.t < CRESCENT_AT:
		s._drift(delta, 2.0)
	else:
		s._rooted(delta, 0.0)
	if s._once("swoosh", CRESCENT_AT - 0.06):
		Net.fx("blade_swoosh", [p.body_model, 0.2, s._col()])
	if s._once("cut", CRESCENT_AT):
		for e in s._cone(3.2, 0.1, CRESCENT_DAMAGE, 6.0, false, false):
			Net.fx("impact", [s._body_center(e), s._col(FX.CORE)])
		Projectile.launch(p.get_tree(), "gale_flat", p.global_position + Vector3(0, 1.0, 0) + s._dir * 1.0, s._dir, p, CRESCENT_GALE, "elem" if s._elem() else "")
		Net.fx("ring", [p.global_position + Vector3(0, 1.0, 0) + s._dir * 1.2, s._dir, 1.6, s._col(), 0.22, 0.12])
		Net.fx("sfx", ["whoosh_big", p.global_position, -2.0, 0.05, 0.7])
		if s._elem():
			Net.fx("element", ["greatsword", p.global_position + Vector3(0, 1.0, 0) + s._dir, s._dir, 10, 6.0])
		p.squash(-2.5)
		s.player.cam_kick(0.14, 0.28)


## A rising cut tears a gust up under the one in front and throws them high (a boss only reels); up after them on the
## wind, the cleave at the top brings the blade down on them, and the landing's crash knocks everyone close flat.
static func _updraft(s, delta: float) -> void:
	var p: Player = s.player
	var alive: bool = s._target != null and is_instance_valid(s._target)
	var landed: bool = s._done.has("crash")
	if landed:
		s._rooted(delta, 0.0)
	elif s.t < UP_RISE:
		var to: Vector3 = (s._target.global_position - p.global_position) if alive else Vector3.ZERO
		to.y = 0.0
		s._drift(delta, clampf((to.length() - 1.8) / UP_RISE, 0.0, 9.0))
	elif s.t < UP_LEAP:
		s._rooted(delta, 0.0)
	elif s.t < UP_CLEAVE:
		# up after them: rising out of the leap and easing off at the apex, drawn in under them as you go
		var k := clampf((s.t - UP_LEAP) / (UP_APEX - UP_LEAP), 0.0, 1.0)
		var h := Vector3.ZERO
		if alive:
			h = s._target.global_position - p.global_position
			h.y = 0.0
			h = h.normalized() * clampf((h.length() - 1.2) * 4.0, 0.0, 7.0) if h.length() > 0.05 else Vector3.ZERO
		p.velocity = h + Vector3.UP * UP_V * (1.0 - k)
		p.move_and_slide()
	else:
		p.velocity = Vector3(0, -UP_DROP, 0)
		p.move_and_slide()
	if s._once("rise_trail", UP_RISE - 0.08):
		Net.fx("blade_swoosh", [p.body_model, 0.16, s._col()])
	if s._once("rise", UP_RISE):
		var at: Vector3 = p.global_position + s._dir * 1.6
		Net.fx("ring", [at + Vector3(0, 0.3, 0), Vector3.UP, 1.5, s._col(), 0.3, 0.12])
		Net.fx("dust_ring", [at, 12, 0.9])
		Net.fx("sfx", ["whoosh_big", at, -2.0, 0.05, 0.85])
		if alive:
			var hd: HitData = s._hd(UP_DAMAGE[0], 1.0, false)
			hd.unblockable = true
			hd.breaker = true
			var center: Vector3 = s._body_center(s._target)
			Net.fx("impact", [center, s._col(FX.CORE)])
			Net.fx("speed_lines", [center, Vector3.UP, s._col(FX.CORE), 8, 2.0, 0.25, randi() % 1000])
			if FistArts.throwable(s._target) and s._target.has_method("launched"):
				hd.stagger_duration = 0.2
				hd.hitstop_duration = 0.0
				s._strike(s._target, hd)
				s._target.call("launched", s._dir * UP_THROW.x + Vector3.UP * UP_THROW.y)
			else:
				hd.stagger_duration = 1.0
				s._strike(s._target, hd)
			if s._elem():
				Net.fx("element", ["greatsword", center, Vector3.UP, 10, 6.0])
		p.squash(2.5)
	if s._once("leap", UP_LEAP):
		Net.fx("dust_ring", [p.global_position, 10, 0.8])
		Net.fx("sfx", ["whoosh", p.global_position, -6.0, 0.05, 0.7])
	if s._once("glint", UP_APEX):
		Net.fx("glint", [tip(p), s._col(FX.CORE), 1.0])
	if s._once("crush_trail", UP_CLEAVE - 0.06):
		Net.fx("blade_swoosh", [p.body_model, 0.1, s._col()])
	if s._once("cleave", UP_CLEAVE) and alive and s._body_center(s._target).distance_to(s._chest()) < 3.6:
		var hd: HitData = s._hd(UP_DAMAGE[1], 4.0, true)
		hd.unblockable = true
		hd.breaker = true
		shape_hit(p, hd)
		s._strike(s._target, hd)
		var at: Vector3 = s._body_center(s._target)
		Net.fx("impact", [at, s._col(FX.CORE)])
		Net.fx("sfx", ["slice_heavy", at, 0.0, 0.05, 0.8])
		CombatManager.apply_hitstop(0.08, [p])
	if not landed and s.t > UP_CLEAVE and (p.is_on_floor() or s.t > 1.8):
		s._done["crash"] = true
		s.dur = s.t + 0.55
		p.velocity = Vector3.ZERO
		p.body_model.play("gs_land", 0.55)
		p.squash(-5.0)
		var at: Vector3 = p.global_position
		for e in s._pc.enemies_in(at + Vector3(0, 0.9, 0), UP_CRASH_R):
			var hd: HitData = s._hd(UP_CRASH_DAMAGE, 8.0, true)
			hd.breaker = true
			s._strike(e, hd)
		Net.fx("ring", [at + Vector3(0, 0.1, 0), Vector3.UP, UP_CRASH_R * 1.2, s._col(), 0.35, 0.1])
		Net.fx("dust_ring", [at, 16, 1.1])
		Net.fx("ground_crack", [at + s._dir * 0.5, s._dir, 2.4, Color(0, 0, 0, 0), randi() % 10000, 0.12])
		Net.fx("sfx", ["thud", at, 0.0, 0.05, 0.7])
		if s._elem():
			Net.fx("vortex", [p, 0.6, UP_CRASH_R, 2.0, FX.tree_col("greatsword", FX.EDGE), randi() % 10000])
		s.player.cam_shake(0.3)
		s.player.cam_kick(0.16, 0.3)


## Held: the blade driven point-down before you like a gate (every blow and shot from the front stops on the flat); let
## go (or at GATE_MAX) and it's wrenched up out of the ground in a rising cut nothing blocks, flinging a crescent of air
## up the line.
static func _gatekeeper(s, delta: float) -> void:
	var p: Player = s.player
	if not s._done.has("release"):
		s._rooted(delta, 0.0)
		var f: Vector3 = s.get_camera_forward()
		f.y = 0.0
		if f.length() > 0.01:
			s._dir = f.normalized()
			s.face_direction(s._dir, 1.0)
		if s._once("plant", 0.18):
			var at: Vector3 = p.global_position + s._dir * 0.75
			Net.fx("dust_ring", [at, 10, 0.7])
			Net.fx("ground_crack", [at, s._dir, 0.9, Color(0, 0, 0, 0), randi() % 10000, 0.08])
			Net.fx("sfx", ["thud", at, -4.0, 0.05, 0.9])
			p.squash(-1.5)
		if (s.t >= GATE_MIN and not s._key_held()) or s.t >= GATE_MAX:
			s._done["release"] = s.t
			s.dur = s.t + RISE_DUR
			p.is_parrying = false
			s._pc.buffs["bat_shots"] = 0.0
			p.body_model.play("gs_gate_rise", RISE_DUR)
		return
	s._rooted(delta, 0.0)
	if s._once("rise_trail", float(s._done["release"]) + RISE_AT - 0.06):
		Net.fx("blade_swoosh", [p.body_model, 0.16, s._col()])
	if s._once("rise", float(s._done["release"]) + RISE_AT):
		for e in s._cone(RISE_REACH, 0.3, RISE_DAMAGE, 7.0, false, true):
			Net.fx("impact", [s._body_center(e), s._col(FX.CORE)])
		var at: Vector3 = p.global_position + s._dir * 0.75
		Net.fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP + s._dir * 0.4, 6, Color(0.35, 0.3, 0.25), 5.0])
		Net.fx("dust_ring", [at, 12, 0.8])
		Projectile.launch(p.get_tree(), "gale", p.global_position + Vector3(0, 1.0, 0) + s._dir * 1.0, s._dir, p, RISE_GALE, "elem" if s._elem() else "")
		Net.fx("sfx", ["whoosh_big", p.global_position, -2.0, 0.05, 0.8])
		if s._elem():
			Net.fx("element", ["greatsword", at + Vector3(0, 0.5, 0), Vector3.UP + s._dir * 0.5, 10, 6.0])
		p.squash(2.0)
		s.player.cam_kick(0.12, 0.25)


## Three turns with the blade out, walking, each quicker than the last: a cut all round on every half turn, then the
## momentum breaking in a burst that throws them down.
static func _tempest(s, delta: float) -> void:
	var p: Player = s.player
	if s.t < TEMPEST_BURST:
		s._drift(delta, 1.6)
	else:
		s._rooted(delta, 0.0)
	var half := int(GreatswordMoves.tempest_k(s.t) * 6.0 + 0.001)
	while s._hits < mini(half, 6) and s.t < TEMPEST_BURST:
		s._hits += 1
		s._ring(TEMPEST_R, TEMPEST_DAMAGE + 1.5 * s._hits, 3.0, false, true)
		Net.fx("blade_swoosh", [p.body_model, 0.12, s._col()])
		Net.fx("sfx", ["whoosh", p.global_position, -7.0 + s._hits, 0.05, 0.9 + 0.07 * s._hits])
		if s._elem():
			Net.fx("element", ["greatsword", tip(p), Vector3.UP * 0.4 + (tip(p) - p.global_position).normalized(), 4, 5.0])
	if s._once("burst", TEMPEST_BURST):
		s._ring(TEMPEST_R + 0.6, TEMPEST_FINAL, 11.0, true, false)
		var col: Color = s._col()
		Net.fx("ring", [p.global_position, Vector3.UP, TEMPEST_R + 1.2, col, 0.32, 0.1])
		Net.fx("dust_ring", [p.global_position, 18, 1.2])
		Net.fx("sfx", ["whoosh_big", p.global_position, 2.0, 0.05, 0.75])
		if s._elem():
			Net.fx("vortex", [p, 0.8, TEMPEST_R, 2.4, FX.tree_col("greatsword", FX.EDGE), randi() % 10000])
		CombatManager.apply_hitstop(0.08, [p])
		s.player.cam_shake(0.3)


## Up high with the blade heaved overhead (the moment at the top), down in one cleave: the ground split in a line far
## ahead and everyone on it thrown down, a ring round you, three crescents of air flung down the line; with the
## element a cyclone of wind round you as you land.
static func _sky(s, delta: float) -> void:
	var p: Player = s.player
	var landed: bool = s._done.has("slam")
	if s.t < SKY_JUMP or landed:
		s._rooted(delta, 0.0)
	elif s.t < SKY_APEX:
		p.velocity = Vector3(0, SKY_UP * (1.0 - (s.t - SKY_JUMP) / (SKY_APEX - SKY_JUMP)), 0)
		p.move_and_slide()
	elif s.t < SKY_HANG:
		p.velocity = Vector3.ZERO
		p.move_and_slide()
	else:
		p.velocity = Vector3(0, -SKY_DROP, 0)
		p.move_and_slide()
	if s._once("jump", SKY_JUMP):
		Net.fx("dust_ring", [p.global_position, 14, 1.0])
		Net.fx("sfx", ["whoosh_big", p.global_position, -3.0, 0.05, 0.65])
		p.squash(3.0)
	if s._once("moment", SKY_APEX):
		s._moment(0.35, 0.3, 0.5, 0.3)
		Net.fx("glint", [tip(p), s._col(FX.CORE), 1.4])
		Net.fx("ring", [p.global_position + Vector3(0, 1.0, 0), s._dir, 2.6, s._col(), 0.35, 0.1])
	if not landed and s.t > SKY_HANG and (p.is_on_floor() or s.t > 1.5):
		s._done["slam"] = true
		p.velocity = Vector3.ZERO
		p.body_model.play("gs_land", 0.9)
		p.squash(-6.0)
		var dir: Vector3 = s._dir
		var from := p.global_position + dir * 0.6
		var elem: bool = s._elem()
		_line(s, from, dir, SKY_LINE, SKY_WIDTH, SKY_DAMAGE, 12.0, true)
		for e in s._pc.enemies_in(p.global_position + Vector3(0, 0.9, 0), SKY_RING):
			var hd: HitData = s._hd(SKY_RING_DAMAGE, 10.0, true)
			hd.breaker = true
			s._strike(e, hd)
		Net.fx("ground_crack", [from, dir, SKY_LINE, s._col(FX.ACCENT) if elem else Color(0, 0, 0, 0), randi() % 10000, 0.22])
		for k in [-1.0, 1.0]:
			Net.fx("ground_crack", [from, dir.rotated(Vector3.UP, k * 0.35), SKY_LINE * 0.45, Color(0, 0, 0, 0), randi() % 10000, 0.16])
		for i in 5:
			var at := from + dir * (i * SKY_LINE / 4.0)
			Net.fx("heavy_dust", [at, 8, 0.8])
			Net.fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP + dir * 0.3, 5, Color(0.35, 0.3, 0.25), 5.5])
			if elem:
				Net.fx("element", ["greatsword", at + Vector3(0, 0.4, 0), Vector3.UP + dir * 0.5, 8, 5.0])
		for k in [-0.18, 0.0, 0.18]:
			var d := dir.rotated(Vector3.UP, k)
			Projectile.launch(p.get_tree(), "gale", p.global_position + Vector3(0, 1.2, 0) + d * 1.2, d, p, SKY_GALE, "elem" if elem else "")
		Net.fx("ring", [p.global_position, Vector3.UP, SKY_RING * 1.3, s._col(FX.ACCENT) if elem else s._col(), 0.45, 0.08])
		Net.fx("screen_flash", [p.global_position, Color(s._col(FX.CORE).r, s._col(FX.CORE).g, s._col(FX.CORE).b, 0.35), 0.25])
		Net.fx("sfx", ["thud", from, 3.0, 0.05, 0.6])
		Net.fx("sfx", ["slice_heavy", from + dir * 3.0, 0.0, 0.05, 0.6])
		if elem:
			Net.fx("vortex", [p, 1.2, 3.2, 3.2, FX.tree_col("greatsword", FX.EDGE), randi() % 10000])
		CombatManager.apply_hitstop(0.12, [p])
		s.player.cam_shake(0.45)
		s.player.cam_kick(0.22, 0.45)
		p.hurtbox.set_deferred("monitorable", true)
