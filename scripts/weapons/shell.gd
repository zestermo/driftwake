class_name Shell
extends Node3D
## A thrown or fired round that flies under gravity (the 1.24 ranged kinds): a cannonball ("ball", bursting where it
## lands), a mortar shell ("mortar", lobbed high), the Leviathan Shell ("giant"), chain shot ("chain": straight on,
## cutting through everyone on its line), a slingshot's pellet ("pellet", "pellet_big"; `extra` its trick ammo).
## Runs on every screen (Player.net_power "shell"); only the shooter's machine hits anything: its art's shell_hit
## (CannonArts, SlingArts) decides what the round does, the copies just stop where it struck.

## kind -> [radius of the round (m), gravity (m/s^2), the longest flight (s), the art that owns it]
const KINDS := {
	"ball": [0.09, 9.0, 3.0, "cannon"],
	"mortar": [0.1, 18.0, 4.0, "cannon"],
	"giant": [0.28, 6.0, 4.0, "cannon"],
	"chain": [0.22, 0.0, 1.0, "cannon"],
}

var kind := "ball"
var vel := Vector3.ZERO
var damage := 0.0
var extra := ""
var source: Node3D
var _age := 0.0
var _gravity := 9.0
var _life := 3.0
var _r := 0.09
var _done := false
var _hit: Array = []
var _puff := 0.0
var _mesh: MeshInstance3D
static var _meshes: Dictionary = {}


static func launch(tree: SceneTree, k: String, from: Vector3, v: Vector3, src: Node3D, dmg: float, ex: String = "") -> Shell:
	var s := Shell.new()
	s.kind = k
	s.vel = v
	s.source = src
	s.damage = dmg
	s.extra = ex
	var root: Node = tree.current_scene if tree.current_scene else tree.root
	root.add_child(s)
	s.global_position = from
	if src is Player:
		(src as Player).net_power("shell", [k, from, v, dmg, ex])
	return s


## The velocity that carries a round from `from` to `to` at `speed` under `g` (the low arc; straight at it when out of
## reach or with no gravity).
static func aim_v(from: Vector3, to: Vector3, speed: float, g: float) -> Vector3:
	var d := to - from
	var flat := Vector3(d.x, 0.0, d.z)
	var x := flat.length()
	if g <= 0.0 or x < 0.5:
		return d.normalized() * speed
	var v2 := speed * speed
	var disc := v2 * v2 - g * (g * x * x + 2.0 * d.y * v2)
	if disc < 0.0:
		return (flat.normalized() + Vector3.UP).normalized() * speed
	var ang := atan((v2 - sqrt(disc)) / (g * x))
	return flat.normalized() * cos(ang) * speed + Vector3.UP * sin(ang) * speed


## The velocity that lands a lobbed round on `to` after `secs` under `g` (a mortar's high arc).
static func lob_v(from: Vector3, to: Vector3, secs: float, g: float) -> Vector3:
	return (to - from) / secs + Vector3.UP * g * secs * 0.5


func _ready() -> void:
	var spec: Array = KINDS[kind]
	_r = float(spec[0])
	_gravity = float(spec[1])
	_life = float(spec[2])
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _mesh_of(kind, extra)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.visibility_range_end = 120.0
	add_child(_mesh)
	add_to_group("projectiles")


func _mine() -> bool:
	return source is Player and (source as Player).is_local


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	vel.y -= _gravity * delta
	var from := global_position
	var to := from + vel * delta
	global_position = to
	if kind == "chain":
		_mesh.rotation.y += 22.0 * delta
	else:
		_mesh.rotation.x -= 10.0 * delta
	_trail(delta)
	if source == null or not is_instance_valid(source):
		queue_free()
		return
	var space := get_world_3d().direct_space_state
	if _mine():
		var foes := _foes(space, from, to)
		for hb in foes:
			if kind == "chain":
				if not hb in _hit:
					_hit.append(hb)
					_art().shell_hit(self, hb.global_position, -vel.normalized(), hb)
			else:
				_end(GunKinds.center(hb), -vel.normalized(), hb)
				return
	var q := PhysicsRayQueryParameters3D.create(from, to + vel.normalized() * _r, 1)
	q.exclude = [source.get_rid()] if source is CollisionObject3D else []
	var h := space.intersect_ray(q)
	if not h.is_empty():
		_end(h["position"], h["normal"], null)
		return
	if _age >= _life or global_position.y < (source as Node3D).global_position.y - 40.0:
		_end(global_position, Vector3.UP, null)


## The foes' hurtboxes on this tick's path (a fat ray: the round's own size).
func _foes(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Array:
	var sq := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = _r + 0.15
	sq.shape = sh
	sq.collision_mask = (source as Player).foe_mask()
	sq.collide_with_areas = true
	sq.collide_with_bodies = false
	sq.motion = to - from
	sq.transform = Transform3D(Basis.IDENTITY, from)
	var out: Array = []
	for r in space.intersect_shape(sq, 8):
		var hb := r["collider"] as Hurtbox
		if hb and hb.owner != source and hb.owner.get("hurtbox") == hb and not hb in out:
			out.append(hb)
	return out


func _end(at: Vector3, normal: Vector3, hb: Hurtbox) -> void:
	_done = true
	if _mine():
		_art().shell_hit(self, at, normal, hb)
	queue_free()


func _art() -> Variant:
	return CannonArts


## A smoke wake behind a cannonball (each screen its own, a puff every 0.05 s).
func _trail(delta: float) -> void:
	if kind in ["ball", "mortar", "giant"]:
		_puff -= delta
		if _puff <= 0.0:
			_puff = 0.05
			FX.smoke(global_position, 1, 0.35 if kind != "giant" else 0.9, 0.6, Color(0.55, 0.53, 0.52, 0.6))


static func _mesh_of(k: String, ex: String) -> Mesh:
	var key := k + "|" + ex
	if _meshes.has(key):
		return _meshes[key]
	var mb := MeshBuilder.new()
	var iron := PSXMat.lit("metal", Color(0.3, 0.3, 0.32))
	match k:
		"chain":
			for s in [-1.0, 1.0]:
				mb.add_blob(iron, Transform3D(Basis(), Vector3(s * 0.22, 0, 0)), Vector3(0.08, 0.08, 0.08), RandomNumberGenerator.new(), 0.0, 3, 6, 1.0)
			mb.add_box(iron, Transform3D(Basis(), Vector3.ZERO), Vector3(0.44, 0.02, 0.02), 2.0)
		_:
			var r := float(KINDS[k][0])
			mb.add_blob(iron, Transform3D(), Vector3(r, r, r), RandomNumberGenerator.new(), 0.0, 4, 8, 1.0)
	var m := mb.commit()
	_meshes[key] = m
	return m
