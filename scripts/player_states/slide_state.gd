extends PlayerState
class_name SlideState
## (1.30.2) The slope slide, free for everyone (Acrobatics' Slides branch upgrades it), no key: running down ground
## steeper than START_SLOPE for a moment, or landing on it, starts one by itself. Stood up side-on like surfing the hill,
## gravity carries you down it, the stick steers, the ground's friction slows it once the slope eases; jump launches
## out of it (Slide Jump keeps all its speed, Spring Heels goes higher). Slick Slide: faster; Slide Kick: a foe you
## slide into goes down; Long Slide: less friction, so it carries on further across gentle ground.

## Slopes this steep (rad, ~29 deg) start a slide, after STEEP_S of running down them; it carries on while the slope is
## at least MIN_SLOPE (~14 deg). The hill's pull is g x sin(slope) x PULL.
const START_SLOPE := 0.5
const STEEP_S := 0.12
const MIN_SLOPE := 0.25
const PULL := 0.75
## The ground's drag (m/s^2), Long Slide's, and the top speed (Slick Slide: + slide_pct).
const FRICTION := 6.0
const FRICTION_LONG := 2.5
const TOP := 11.0
## How fast the stick turns the slide (rad/s), and pulled back against it, how hard it brakes (m/s^2).
const STEER := 2.6
const BRAKE := 7.0
## Speed a slide starts with at least, below which it ends (off a slope), and a landing's fall turned into it (x).
const START := 3.0
const STOP := 2.0
const LAND_K := 0.3
## A jump out of it keeps this share of its speed (Slide Jump: all of it).
const JUMP_KEEP := 0.6
## Slide Kick: a foe this close ahead at KICK_MIN m/s or more goes down.
const KICK_R := 1.1
const KICK_MIN := 4.0
const KICK_DAMAGE := 12.0

var _v := Vector3.ZERO
var _kicked: Array = []
var _air := 0.0
var _dust := 0.0


## A slide can start here: on the ground of a slope steep enough and going down it; `landing`: coming down onto it,
## any way you're going (a short hop onto a hill doesn't count: `fall_vy` under 4 m/s).
static func can_start(p: Player, landing: bool = false, fall_vy: float = 0.0) -> bool:
	if p.context != Player.Context.ON_FOOT or p.is_swimming() or not p.is_on_floor():
		return false
	var n := p.get_floor_normal()
	if acos(clampf(n.y, -1.0, 1.0)) < START_SLOPE or not _on_terrain(p):
		return false
	if landing:
		return absf(fall_vy) > 4.0
	var hv := Vector3(p.velocity.x, 0.0, p.velocity.z)
	return hv.length() > 1.0 and hv.normalized().dot(Vector3(n.x, 0.0, n.z).normalized()) > 0.4


## The ground underfoot is an island's hill (its "Terrain" body), not stairs, a roof, a ramp or a deck.
static func _on_terrain(p: Player) -> bool:
	for i in p.get_slide_collision_count():
		var c := p.get_slide_collision(i)
		var col := c.get_collider() as Node
		if col != null and col.name == "Terrain" and c.get_normal().y > 0.3:
			return true
	return false


## MoveState's tick: true once the captain has run down steep ground for STEEP_S (a bump's one odd normal doesn't
## start a slide).
static func auto_start(p: Player, delta: float) -> bool:
	var t := float(p.get_meta("steep_t", 0.0))
	t = t + delta if can_start(p) else 0.0
	p.set_meta("steep_t", t)
	if t < STEEP_S:
		return false
	p.set_meta("steep_t", 0.0)
	return true


func enter(data: Dictionary) -> void:
	var v: Vector3 = data.get("velocity", player.velocity)
	_v = Vector3(v.x, 0.0, v.z)
	var down := _downhill()
	_v += down * absf(float(data.get("fall_vy", 0.0))) * LAND_K
	if _v.length() < START:
		var way := down if down != Vector3.ZERO else -player.player_model.global_basis.z
		_v = _v.normalized() * START if _v.length() > 0.5 else Vector3(way.x, 0.0, way.z).normalized() * START
	_kicked = []
	_air = 0.0
	_dust = 0.0
	player.sprinting = false
	player.body_model.hold("slide")
	player.squash(-3.0)
	Net.fx("dust", [player.global_position + Vector3(0, 0.05, 0), 8, 0.6])
	Net.fx("sfx", ["whoosh", player.global_position, -10.0, 0.08, 0.8])


func exit() -> void:
	if player.body_model.current_action() == "slide":
		player.body_model.stop_action()


## Down the slope underfoot, flat (zero on the flat).
func _downhill() -> Vector3:
	if not player.is_on_floor():
		return Vector3.ZERO
	var n := player.get_floor_normal()
	var d := Vector3(n.x, 0.0, n.z)
	return d.normalized() if d.length() > 0.02 else Vector3.ZERO


func _slope() -> float:
	return acos(clampf(player.get_floor_normal().y, -1.0, 1.0)) if player.is_on_floor() else 0.0


func physics_update(delta: float) -> void:
	var pr := player.progression
	var slope := _slope()
	_v += _downhill() * player.gravity * sin(slope) * PULL * delta
	_v = _v.move_toward(Vector3.ZERO, (FRICTION_LONG if pr.has_flag("long_slide") else FRICTION) * delta)
	var input := get_movement_input()
	if input.length() > 0.1 and _v.length() > 0.1:
		var want := get_camera_relative_direction(input)
		var ang := Vector2(_v.x, _v.z).angle_to(Vector2(want.x, want.z))
		if absf(ang) > 2.4:
			_v = _v.move_toward(Vector3.ZERO, BRAKE * delta)
		else:
			_v = _v.rotated(Vector3.UP, -clampf(ang, -STEER * delta, STEER * delta))
	_v = _v.limit_length(TOP * (1.0 + pr.stat("slide_pct")))
	player.velocity.x = _v.x
	player.velocity.z = _v.z
	if player.is_on_floor():
		player.velocity.y = -2.0
	else:
		apply_gravity(delta)
	player.move_and_slide()
	_v = Vector3(player.velocity.x, 0.0, player.velocity.z)
	if _v.length() > 0.3:
		# side-on to the slide, the left shoulder leading
		player.player_model.rotation.y = lerp_angle(player.player_model.rotation.y, atan2(-_v.x, -_v.z) - PI * 0.5, minf(8.0 * delta, 1.0))
	_dust -= delta
	if _dust <= 0.0 and player.is_on_floor():
		_dust = 0.08
		Net.fx("dust", [player.global_position + Vector3(0, 0.05, 0), 2 + int(_v.length() / 5.0), 0.45])
	if pr.has_flag("slide_kick") and _v.length() >= KICK_MIN:
		_kick()

	_air = _air + delta if not player.is_on_floor() else 0.0
	if _air > 0.15:
		player.air_speed = _v.length()
		transitioned.emit(self, "Fall", {})
		return
	if wants_jump():
		var keep := 1.0 if pr.has_flag("slide_jump") else JUMP_KEEP
		player.velocity.x = _v.x * keep
		player.velocity.z = _v.z * keep
		transitioned.emit(self, "Jump", {"slide": true})
		return
	if wants_dodge():
		transitioned.emit(self, "Dodge", {})
		return
	var next := combat_input()
	if next != "":
		transitioned.emit(self, next, {"combo_index": 0})
		return
	if slope < MIN_SLOPE and _v.length() < (STOP if pr.has_flag("long_slide") else player.move_speed):
		transitioned.emit(self, "Move" if input.length() > 0.1 else "Idle", {})


## Slide Kick: the leg out into a foe's shins ahead, once a slide each; they go down.
func _kick() -> void:
	var ahead := _v.normalized()
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = KICK_R
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, player.global_position + ahead * 0.6 + Vector3(0, 0.5, 0))
	q.collision_mask = player.foe_mask()
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for res in player.get_world_3d().direct_space_state.intersect_shape(q, 8):
		var area := res["collider"] as Hurtbox
		if area == null or area.owner == null or area.owner == player or area.owner in _kicked or area.owner.is_in_group("players"):
			continue
		_kicked.append(area.owner)
		var hit := HitData.new()
		hit.damage = KICK_DAMAGE * player.damage_multiplier()
		hit.knockdown = true
		hit.knockback_force = 4.0 + _v.length() * 0.4
		hit.stagger_duration = 0.6
		hit.hitstop_duration = 0.05
		hit.impact = "punch_heavy"
		area.take_hit(hit, player)
		Net.fx("impact", [area.owner.global_position + Vector3(0, 0.4, 0), Color(1.0, 0.92, 0.75)])
		Net.fx("sfx", ["thud", player.global_position, -6.0, 0.05, 1.1])
