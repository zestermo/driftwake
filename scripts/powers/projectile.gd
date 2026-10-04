class_name Projectile
extends Node3D
## Straight-flying skill projectiles other than the Fire Fist:
##   "slash"  Flying Slash: a crescent of wind that cuts through every enemy in
##            its path (pierces), stopped by walls.
##   "seed"   Vine Snare: a seed that bursts into grasping vines on the first
##            enemy or surface it hits, rooting everyone close.

var kind: String = "slash"
var dir := Vector3.FORWARD
var speed: float = 24.0
var range_m: float = 22.0
var damage: float = 26.0
var source: Node3D
var _travel: float = 0.0
var _done: bool = false
var _hit: Array = []
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D


static func launch(tree: SceneTree, k: String, from: Vector3, direction: Vector3, src: Node3D, dmg: float) -> Projectile:
	var p := Projectile.new()
	p.kind = k
	p.dir = direction.normalized()
	p.source = src
	p.damage = dmg
	if k == "seed":
		p.speed = 20.0
		p.range_m = 24.0
	var root: Node = tree.current_scene if tree.current_scene else tree.root
	root.add_child(p)
	p.global_position = from
	if src is Player:
		(src as Player).net_power("projectile", [k, from, direction, dmg])
	return p


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if kind == "slash":
		# a thin crescent lying across the flight path
		var mb := MeshBuilder.new()
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat.albedo_color = Color(0.75, 0.9, 1.0, 0.85)
		var pts := 9
		for i in range(pts - 1):
			var a0 := lerpf(-1.1, 1.1, float(i) / float(pts - 1))
			var a1 := lerpf(-1.1, 1.1, float(i + 1) / float(pts - 1))
			var w0 := 0.12 * cos(a0 * 1.3)
			var w1 := 0.12 * cos(a1 * 1.3)
			var p0 := Vector3(sin(a0) * 1.1, 0, -cos(a0) * 0.5)
			var p1 := Vector3(sin(a1) * 1.1, 0, -cos(a1) * 0.5)
			mb.add_quad(_mat, p0 + Vector3(0, 0, -w0), p1 + Vector3(0, 0, -w1), p1 + Vector3(0, 0, w1), p0 + Vector3(0, 0, w0), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
		_mesh.mesh = mb.commit()
		_mesh.material_override = _mat
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.26
		sm.radial_segments = 6
		sm.rings = 3
		_mesh.mesh = sm
		_mat.albedo_color = Color(0.4, 0.75, 0.25)
		_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	global_basis = Basis.looking_at(dir, Vector3.UP) if absf(dir.y) < 0.98 else Basis.IDENTITY


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := dir * speed * delta
	var from := global_position
	var to := from + step
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	if source is CollisionObject3D:
		q.exclude = [(source as CollisionObject3D).get_rid()]
	var wall := space.intersect_ray(q)
	if not wall.is_empty():
		global_position = (wall["position"] as Vector3) - dir * 0.1
		_finish()
		return
	var pc := source.get("power") as PowerComponent if source and is_instance_valid(source) else null
	if pc:
		for e in pc.enemies_in(to, 1.3 if kind == "slash" else 0.5):
			if e in _hit:
				continue
			_hit.append(e)
			if kind == "slash":
				var hb := (e as Node).get("hurtbox") as Hurtbox
				if hb:
					var hd := (source as Player).melee_hit(damage)
					hd.knockback_force = 6.0
					hd.stagger_duration = 0.35
					hd.hitstop_duration = 0.05
					hd.camera_shake_intensity = 0.08
					hb.take_hit(hd, source)
					pc.add_ult(hd.damage)
					FX.impact((e as Node3D).global_position + Vector3(0, 1.0, 0), Color(0.8, 0.9, 1.0))
			else:
				global_position = to
				_finish()
				return
	global_position = to
	_travel += step.length()
	if kind == "seed":
		_mesh.rotation += Vector3(9.0, 6.0, 0.0) * delta
	elif int(_travel * 3.0) % 2 == 0:
		FX.sparkle(global_position, 1, Color(0.8, 0.95, 1.0))
	if _travel >= range_m:
		_finish()


func _finish() -> void:
	_done = true
	if kind == "seed":
		var pc := source.get("power") as PowerComponent if source and is_instance_valid(source) else null
		var at := global_position
		FX.sparkle(at, 14, Color(0.5, 0.95, 0.3))
		FX.dust_ring(at, 10, 0.7)
		FX.sfx("whoosh", at, -4.0, 0.1, 0.7)
		if pc:
			for e in pc.enemies_in(at, 2.4):
				pc.root_enemy(e as Node3D, 3.0)
				var hb := (e as Node).get("hurtbox") as Hurtbox
				if hb:
					var hd := HitData.new()
					hd.dot = true
					hd.damage = roundf(damage * pc.power_multiplier())
					hb.take_hit(hd, source)
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(_mat, "albedo_color:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
