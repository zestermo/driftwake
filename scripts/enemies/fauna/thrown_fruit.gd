class_name ThrownFruit
extends Node3D
## A fruit a monkey lobs at you: it arcs, and splats on what it hits. Every
## screen flies its own copy (Monkey's "throw" event); each captain only checks
## their own.

const GRAVITY := 14.0
const RADIUS := 0.45

var vel := Vector3.ZERO
var damage: float = 5.0
var color := Color(0.95, 0.6, 0.15)
var _life: float = 4.0
var _spin := Vector3.ZERO

static var _mesh: SphereMesh


func _ready() -> void:
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = 0.09
		_mesh.height = 0.2
		_mesh.radial_segments = 6
		_mesh.rings = 3
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = PSXMat.lit("", color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_spin = Vector3(randf_range(-9, 9), randf_range(-9, 9), 0)


func _physics_process(delta: float) -> void:
	var from := global_position
	vel.y -= GRAVITY * delta
	var to := from + vel * delta
	rotation += _spin * delta
	var p: Node3D = Net.local_player if Net.active else GameManager.player
	if p and is_instance_valid(p) and _hits(p, from, to):
		_hit_player(p)
		_splat(to)
		return
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_splat(hit["position"])
		return
	global_position = to
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _hits(p: Node3D, from: Vector3, to: Vector3) -> bool:
	var pts := Geometry3D.get_closest_points_between_segments(from, to, p.global_position + Vector3(0, 0.2, 0), p.global_position + Vector3(0, 1.7, 0))
	return (pts[0] as Vector3).distance_to(pts[1] as Vector3) < RADIUS


func _hit_player(p: Node3D) -> void:
	var hb := p.get_node_or_null("Hurtbox") as Hurtbox
	if hb == null or not hb.monitorable:
		return
	var hd := HitData.new()
	hd.ranged = true
	hd.impact = "punch"
	hd.damage = damage
	hd.knockback_force = 2.5
	hd.stagger_duration = 0.3
	hd.hitstop_duration = 0.03
	hd.camera_shake_intensity = 0.08
	hb.take_hit(hd, self)


func _splat(at: Vector3) -> void:
	FX.petals(at, Vector3.UP, 8, color, 2.5)
	FX.sfx("splash", at, -10.0, 0.1, 1.8)
	queue_free()
