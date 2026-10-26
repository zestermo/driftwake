class_name AdmiraltyBoom
extends StaticBody3D
## A harbour boom (docs/v1_23_plan.md, sea pursuit): iron-banded logs chained end to end across an island's mouth,
## between the Admiralty's blockade ships (Admiralty._blockade). The crew's ship can't sail through it: shoot it apart
## (crew cannon fire, HP) or ram it at speed (RAM_SPEED or faster, a knock to her hull). Built on every screen from the
## Admiralty's spawner list; the host decides when it breaks ("break" event).

const HP := 120.0
const RAM_SPEED := 7.0
const RAM_HULL := 25.0
const LOG_LEN := 5.2

var a := Vector3.ZERO
var b := Vector3.ZERO
var hp: float = HP
var hurtbox: Hurtbox
var broken: bool = false
var _check_t: float = 0.0
static var _log_mesh: Mesh


func _ready() -> void:
	add_to_group("booms")
	collision_layer = 1
	collision_mask = 0
	var d := b - a
	d.y = 0.0
	var mid := (a + b) * 0.5
	position = Vector3(mid.x, 0.0, mid.z)
	rotation.y = atan2(-d.x, -d.z)
	var length := d.length()
	var n := maxi(int(ceil(length / LOG_LEN)), 1)
	var holder := Node3D.new()
	holder.name = "Logs"
	add_child(holder)
	for i in range(n):
		var mi := MeshInstance3D.new()
		mi.mesh = _log()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 420.0
		mi.position = Vector3(0.0, 0.15, -length * 0.5 + (i + 0.5) * length / n)
		mi.rotation.y = 0.04 * (1.0 if i % 2 == 0 else -1.0)
		holder.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 2.2, length)
	cs.shape = box
	cs.position = Vector3(0, 0.1, 0)
	add_child(cs)
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 32
	hurtbox.collision_mask = 0
	var hs := CollisionShape3D.new()
	var hbox := BoxShape3D.new()
	hbox.size = Vector3(2.4, 2.6, length)
	hs.shape = hbox
	hs.position = Vector3(0, 0.3, 0)
	hurtbox.add_child(hs)
	add_child(hurtbox)
	hurtbox.owner = self
	hurtbox.hit_received.connect(_on_hit)


func is_dead() -> bool:
	return broken


## (host) The crew's ship driving into it at speed breaks through.
func _physics_process(delta: float) -> void:
	if broken or Net.is_client():
		return
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 0.2
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship == null or ship.speed < RAM_SPEED:
		return
	var bow: Vector3 = ship.global_transform * Vector3(0, 0, HullBuilder.BOW_Z)
	var p := Geometry3D.get_closest_point_to_segment(Vector3(bow.x, 0.0, bow.z), Vector3(a.x, 0.0, a.z), Vector3(b.x, 0.0, b.z))
	if p.distance_to(Vector3(bow.x, 0.0, bow.z)) < 4.0:
		ship.hull_hit(RAM_HULL, p + Vector3(0, 1.0, 0))
		Net.everyone("_all_rammed", [Net.key_of(ship), p, -ship.global_basis.z * 0.6])
		_break()


func _on_hit(hit: HitData, _attacker: Node) -> void:
	if broken or Net.is_client():
		return
	hp -= hit.damage
	Net.damage_number(hit.damage, global_position + Vector3(0, 1.5, 0))
	if hp <= 0.0:
		_break()


func _break() -> void:
	Net.event(self, "break", [])
	var adm := get_parent() as Admiralty
	shatter()
	adm.boom_broken(name)


func net_event(what: String, _args: Array) -> void:
	if what == "break":
		shatter()


## (every screen) The chain parts: splinters and splashes along it, and it's gone.
func shatter() -> void:
	if broken:
		return
	broken = true
	for i in range(5):
		var at := a.lerp(b, (i + 0.5) / 5.0)
		FX.splash(Vector3(at.x, 0.2, at.z), 8, 1.2)
		FX.dust(Vector3(at.x, 0.6, at.z), 8, 1.0)
	FX.sfx("wood_crack", global_position, 6.0, 0.05, 0.6)
	get_tree().call_group("hud", "show_toast", "The boom is broken!")
	queue_free()


static func _log() -> Mesh:
	if _log_mesh:
		return _log_mesh
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark", Color(0.8, 0.68, 0.55))
	var iron := PSXMat.lit("metal", Color(0.3, 0.3, 0.32))
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -LOG_LEN * 0.45)), 0.42, 0.42, LOG_LEN * 0.9, 6, 0.6)
	for z in [-1.6, 1.6]:
		mb.add_cylinder(iron, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, z - 0.1)), 0.45, 0.45, 0.2, 6, 1.0)
	mb.add_box(iron, Transform3D(Basis(), Vector3(0, 0, LOG_LEN * 0.475)), Vector3(0.12, 0.12, LOG_LEN * 0.1), 1.0)
	_log_mesh = mb.commit()
	return _log_mesh
