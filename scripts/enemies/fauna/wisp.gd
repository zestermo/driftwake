class_name Wisp
extends Creature
## Will-o'-wisps: little lights drifting between the trees in twos and threes. By day they're
## faint, hard to see; at night they glow. Come near and they draw off ahead of you, staying just
## out of reach, leading you deeper in - then drift back to their haunt. Strike one and it gutters
## out. Harmless, but the folk say never follow one. Morphs: a cold blue-green, a marsh gold, violet.

const COLORS := [Color(0.55, 1.0, 0.85), Color(1.0, 0.82, 0.38), Color(0.78, 0.6, 1.0)]
const HOVER := 1.5
const DRIFT := 1.2
const LEAD := 4.2
const SHY := 9.0

static var _halo_mats := {}

var morph: int = 0
var _ground_y: float = 0.0
var _ray_t: float = 0.0
var _goal := Vector3.ZERO
var _bob: float = 0.0
var _core: Node3D
var _halo: MeshInstance3D


func _setup(args: Dictionary) -> void:
	kind = "wisp"
	morph = int(args.get("morph", 0))
	hostile = false
	flying = true
	max_hp = 12.0
	xp = 8
	coins = Vector2i(0, 1)
	size_k = 1.0


func _body_shape() -> Array:
	return [0.2, 0.4, Vector3(0.5, 0.5, 0.5)]


func _build() -> void:
	var col: Color = COLORS[morph % 3]
	var glow := _glow(col)
	_core = _part(model, "Core", Vector3(0, HOVER, 0), "core%d" % (morph % 3), func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(glow, Transform3D.IDENTITY, Vector3(0.11, 0.13, 0.11), rng, 0.15, 3, 6, 1.0)
		mb.add_blob(glow, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.16, 0.0)), Vector3(0.05, 0.08, 0.05), rng, 0.15, 2, 5, 1.0))
	if not _halo_mats.has(morph % 3):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = PSXMat.tex("wisp_glow")
		m.albedo_color = col
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_halo_mats[morph % 3] = m
	_halo = MeshInstance3D.new()
	_halo.name = "Halo"
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	_halo.mesh = q
	_halo.material_override = _halo_mats[morph % 3]
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.visibility_range_end = LOD_RANGE[2] + 10.0
	_core.add_child(_halo)


func _start() -> void:
	# (its light floats at HOVER: so does what you can hit)
	(hurtbox.get_child(0) as Node3D).position.y = HOVER
	_ground_y = global_position.y
	_goal = global_position
	_set_state(S.WANDER)


## The ground under it now and then (it floats over whatever the land does).
func _ground_now(delta: float) -> void:
	_ray_t -= delta
	if _ray_t > 0.0:
		return
	_ray_t = 0.5
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 4.0, global_position + Vector3.DOWN * 12.0, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_ground_y = (hit["position"] as Vector3).y


func _brain(delta: float) -> void:
	_ground_now(delta)
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			if flat(_goal - global_position).length() < 0.6 or st_t > 9.0:
				var a := _rng.randf() * TAU
				_goal = home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.0, 7.0)
				st_t = 0.0
			_want = flat(_goal - global_position).limit_length(DRIFT)
			if _night() > 0.4 and _player_ok(p) and dist < SHY:
				_set_state(S.FLEE)
		S.FLEE:
			# (ahead of the captain, out of reach, never far from its haunt)
			var away := _flee_dir(p.global_position if p else global_position)
			var keep := clampf((SHY + 2.0 - dist) / 4.0, -0.3, 1.0)
			_want = away * LEAD * keep
			if (dist > SHY * 2.2 and st_t > 3.0) or global_position.distance_to(home) > 40.0:
				_goal = home
				_set_state(S.WANDER)


func _fly(delta: float) -> void:
	_bob += delta
	var y := _ground_y + sin(_bob * 1.3 + float(morph)) * 0.35 - global_position.y
	var v := Vector3(_want.x, y * 1.5, _want.z)
	velocity = velocity.lerp(v, minf(delta * 2.5, 1.0))
	move_and_slide()


func _hurt(_hit: HitData, _attacker: Node, _dir: Vector3) -> bool:
	_set_state(S.FLEE)
	return true


func _knocked() -> void:
	flying = true


func _can_knock() -> bool:
	return false


func _cry_death() -> void:
	Net.fx("sfx", ["blip_high", global_position, -8.0, 0.2, 0.7])
	Net.fx("sparkle", [global_position + Vector3.UP * HOVER, 8, COLORS[morph % 3]])


func _tick(delta: float) -> void:
	anim_a = move_toward(anim_a, clampf(_night() * 1.4, 0.25, 1.0), delta * 0.5)


func _pose(_delta: float) -> void:
	var lit := anim_a
	var flicker := 0.85 + 0.15 * sin(_t * 9.0 + float(morph) * 2.0) * sin(_t * 3.7)
	_core.scale = Vector3.ONE * lerpf(0.45, 1.0, lit) * flicker
	_core.position.y = HOVER + sin(_t * 1.7 + float(morph)) * 0.12
	_halo.visible = state != S.DEAD and lit > 0.3
	if state == S.DEAD:
		_core.scale = Vector3.ONE * maxf(0.0, 1.0 - _dead_t * 2.0)
