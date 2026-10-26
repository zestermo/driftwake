class_name Breakable
extends Hurtbox
## Breakable places (1.23, docs/v1_23_plan.md: crates, barrels and the like break under heavy hits and ultimates). A
## hurtbox on the prop (the enemies' hurtbox layer, so every captain's swing and shot finds it); a light hit only
## knocks it (a thud and a few splinters), a heavy one (a knockdown, a breaker, a siege blow or BREAK_AT damage)
## smashes it: splinters and dust, its mesh and collider gone, on every screen (Net._all_break). It comes back
## after RETURN s once no captain is near. Hits on it give no energy, ultimate or mastery (PowerComponent).

const BREAK_AT := 22.0
const RETURN := 240.0
const RETURN_CLEAR := 40.0

var broken := false
var _back_t := 0.0
var _size := 0.5


## Make prop `body` (a StaticBody3D with its mesh and collider) breakable, `size` across.
static func add_to(body: Node3D, size: float, at: Vector3) -> void:
	var b := Breakable.new()
	b.name = "Breakable"
	b._size = size
	b.collision_layer = 32
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3.ONE * size
	cs.shape = bx
	cs.position = at
	b.add_child(cs)
	body.add_child(b)
	b.owner = body
	body.add_to_group("breakables")


func _ready() -> void:
	super._ready()
	hit_received.connect(_on_hit)


func _on_hit(data: HitData, _attacker: Node) -> void:
	if broken:
		return
	var at := (owner as Node3D).global_position + Vector3.UP * _size * 0.5
	if data.knockdown or data.breaker or data.siege or data.damage >= BREAK_AT:
		var net := get_node_or_null("/root/Net")
		if net and net.active:
			net.everyone("_all_break", [net.key_of(owner)])
		else:
			smash()
	else:
		var fx := get_node("/root/FX")
		fx.dust(at, 3, 0.4)
		fx.sfx("thud", at, -8.0)


## (every machine) splinters and dust; the prop's meshes and colliders go until it comes back.
func smash() -> void:
	if broken:
		return
	broken = true
	_back_t = RETURN
	var at := (owner as Node3D).global_position + Vector3.UP * _size * 0.5
	# (each screen its own: every machine smashes its copy through Net._all_break)
	var fx := get_node("/root/FX")
	fx.impact(at, Color(0.75, 0.6, 0.4))
	fx.dust(at, 10, 0.8)
	fx.sparkle(at, 8, Color(0.62, 0.45, 0.28))
	fx.sfx("wood_crack", at, -4.0, 0.12, 1.0)
	_show(false)


func _show(on: bool) -> void:
	for c in owner.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = on
		elif c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", not on)
	set_deferred("monitorable", on)


func _physics_process(delta: float) -> void:
	if not broken:
		return
	_back_t -= delta
	if _back_t > 0.0:
		return
	_back_t = 5.0
	for p in get_tree().get_nodes_in_group("players"):
		if (p as Node3D).global_position.distance_to((owner as Node3D).global_position) < RETURN_CLEAR:
			return
	broken = false
	_show(true)
