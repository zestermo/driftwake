class_name PoisonGlob
extends Node3D
## A blob of venom lobbed in an arc (spitter bugs, the brood queen). It
## splashes on whatever it hits and poisons a captain it lands on. Every
## screen flies its own copy (FX.spit); each captain only checks their own.

const GRAVITY := 14.0
const RADIUS := 0.5

var vel := Vector3.ZERO
var damage: float = 6.0
var poison_secs: float = 4.0
var poison_dps: float = 3.0
var size: float = 1.0
var _life: float = 5.0
var _trail: float = 0.0

static var _mat: Material
static var _mesh: SphereMesh


func _ready() -> void:
	if _mat == null:
		_mat = PSXMat.glow(Color(0.5, 1.0, 0.25), 1.8)
		_mesh = SphereMesh.new()
		_mesh.radius = 0.13
		_mesh.height = 0.24
		_mesh.radial_segments = 6
		_mesh.rings = 3
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = _mat
	mi.scale = Vector3.ONE * size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _physics_process(delta: float) -> void:
	var from := global_position
	vel.y -= GRAVITY * delta
	var to := from + vel * delta
	_trail -= delta
	if _trail <= 0.0:
		_trail = 0.05
		FX.poison(from, 1, 0.22 * size)
	var p: Node3D = Net.local_player if Net.active else GameManager.player
	if p and is_instance_valid(p) and _hits(p, from, to):
		_hit_player(p)
		_splash(to)
		return
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_splash(hit["position"])
		return
	global_position = to
	_life -= delta
	if _life <= 0.0 or to.y < -2.0:
		queue_free()


func _hits(p: Node3D, from: Vector3, to: Vector3) -> bool:
	var a := p.global_position + Vector3(0, 0.2, 0)
	var b := p.global_position + Vector3(0, 1.7, 0)
	var pts := Geometry3D.get_closest_points_between_segments(from, to, a, b)
	return (pts[0] as Vector3).distance_to(pts[1] as Vector3) < RADIUS * size


func _hit_player(p: Node3D) -> void:
	var hb := p.get_node_or_null("Hurtbox") as Hurtbox
	if hb == null or not hb.monitorable:
		return
	var hc := p.get_node_or_null("HealthComponent") as HealthComponent
	var before := hc.current_health if hc else 0.0
	var hd := HitData.new()
	hd.ranged = true
	hd.damage = damage
	hd.knockback_force = 2.0
	hd.stagger_duration = 0.25
	hd.hitstop_duration = 0.03
	hd.camera_shake_intensity = 0.08
	hb.take_hit(hd, self)
	# only a blob that landed poisons (not one dodged, parried or cut)
	if hc and hc.current_health < before:
		PoisonStatus.apply(p, poison_secs, poison_dps, null)


func _splash(at: Vector3) -> void:
	FX.poison(at, 8, 0.4 * size)
	FX.sfx("splash", at, -8.0, 0.1, 1.6)
	queue_free()
