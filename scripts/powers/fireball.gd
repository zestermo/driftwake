class_name Fireball
extends Node3D
## Fire Fist: a ball of fire that flies straight, bursting on the first enemy
## or wall it meets (or at the end of its range) and setting things ablaze.

const SPEED := 26.0
const RANGE := 32.0
const HIT_RADIUS := 0.4
const BLAST_RADIUS := 2.1
const DAMAGE := 24.0

var dir := Vector3.FORWARD
var source: Node3D
var _travel: float = 0.0
var _done: bool = false
var _core: MeshInstance3D
var _trail: CPUParticles3D
var _light: OmniLight3D


static func launch(tree: SceneTree, from: Vector3, direction: Vector3, src: Node3D) -> Fireball:
	var f := Fireball.new()
	f.dir = direction.normalized()
	f.source = src
	var root: Node = tree.current_scene if tree.current_scene else tree.root
	root.add_child(f)
	f.global_position = from
	if src is Player:
		(src as Player).net_power("fireball", [from, direction])
	return f


func _ready() -> void:
	_core = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.24
	sm.height = 0.48
	sm.radial_segments = 8
	sm.rings = 4
	_core.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.45)
	_core.material_override = m
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	var halo := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.42
	hs.height = 0.84
	hs.radial_segments = 8
	hs.rings = 4
	halo.mesh = hs
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_color = Color(1.0, 0.4, 0.08, 0.55)
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	_trail = FX.flame_emitter(self, 0.2, 26, 0.5, 0.45, true)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.omni_range = 5.0
	_light.light_energy = 2.0
	add_child(_light)


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := dir * SPEED * delta
	var from := global_position
	var to := from + step
	var space := get_world_3d().direct_space_state
	# walls / ground
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	if source:
		q.exclude = [(source as CollisionObject3D).get_rid()] if source is CollisionObject3D else []
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		global_position = (hit["position"] as Vector3) - dir * 0.15
		_explode()
		return
	# enemies (their hurtboxes)
	var sq := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = HIT_RADIUS
	sq.shape = sph
	sq.transform = Transform3D(Basis.IDENTITY, to)
	sq.collision_mask = 32
	sq.collide_with_areas = true
	sq.collide_with_bodies = false
	for r in space.intersect_shape(sq, 8):
		var hb := r["collider"] as Hurtbox
		if hb and hb.owner and BurnStatus.alive(hb.owner):
			global_position = to
			_explode()
			return
	global_position = to
	_travel += step.length()
	_core.rotation += Vector3(7.0, 5.0, 3.0) * delta
	if _travel >= RANGE:
		_explode()


func _explode() -> void:
	_done = true
	var at := global_position
	FX.flame(at, 18, 0.9, 0.55, 0.5)
	FX.impact(at, Color(1.0, 0.7, 0.3))
	FX.sfx("fire_burst", at, -2.0, 0.1, 1.1)
	var pc := source.get("power") as PowerComponent if source and is_instance_valid(source) else null
	if pc:
		var hd := HitData.new()
		hd.damage = DAMAGE
		hd.knockback_force = 6.0
		hd.stagger_duration = 0.3
		hd.hitstop_duration = 0.04
		hd.camera_shake_intensity = 0.08
		hd.unblockable = true
		pc.blast(at, BLAST_RADIUS, hd, 3.0, 6.0)
		pc.ignite_burnables(at, BLAST_RADIUS)
	_core.visible = false
	for c in get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	_trail.emitting = false
	var tw := create_tween()
	tw.tween_property(_light, "light_energy", 0.0, 0.3)
	tw.tween_callback(queue_free).set_delay(0.5)
