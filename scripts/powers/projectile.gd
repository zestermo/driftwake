class_name Projectile
extends Node3D
## Flying skill projectiles other than the Fire Fist:
##   "slash"  Flying Slash: a crescent of wind that cuts through every enemy in
##            its path (pierces), stopped by walls.
##   "wave"   Wind Severer: a tall crescent standing on its edge, bigger and
##            slower, knocking down everything it passes.
##   "axe"    Hatchet Throw: the thrower's axe spinning out and back to the hand,
##            cutting everything on the way out and again on the way back.
##   "seed"   Vine Snare: a seed that bursts into grasping vines on the first
##            enemy or surface it hits, rooting everyone close.

var kind: String = "slash"
var dir := Vector3.FORWARD
var speed: float = 24.0
var range_m: float = 22.0
var damage: float = 26.0
var model: String = ""
var source: Node3D
var _travel: float = 0.0
var _done: bool = false
var _back: bool = false
var _hit: Array = []
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _core: StandardMaterial3D

signal returned


static func launch(tree: SceneTree, k: String, from: Vector3, direction: Vector3, src: Node3D, dmg: float, weapon_model: String = "") -> Projectile:
	var p := Projectile.new()
	p.kind = k
	p.dir = direction.normalized()
	p.source = src
	p.damage = dmg
	p.model = weapon_model
	match k:
		"seed":
			p.speed = 20.0
			p.range_m = 24.0
		"wave":
			p.speed = 19.0
			p.range_m = 18.0
		"axe":
			p.speed = 20.0
			p.range_m = 13.0
	var root: Node = tree.current_scene if tree.current_scene else tree.root
	root.add_child(p)
	p.global_position = from
	if src is Player:
		(src as Player).net_power("projectile", [k, from, direction, dmg, weapon_model])
	return p


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if kind in ["slash", "wave"]:
		# a thin crescent lying across the flight path (stood on its edge for the
		# wave): a coloured sheath round a hot white core
		var mb := MeshBuilder.new()
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var edge := FX.tree_col(_tree(), FX.EDGE)
		_mat.albedo_color = Color(edge.r, edge.g, edge.b, 0.75)
		_core = _mat.duplicate() as StandardMaterial3D
		_core.albedo_color = Color(1, 1, 1, 0.95)
		var pts := 11
		for layer in [[_mat, 0.17, 0.0], [_core, 0.05, -0.04]]:
			var m: Material = layer[0]
			for i in range(pts - 1):
				var a0 := lerpf(-1.15, 1.15, float(i) / float(pts - 1))
				var a1 := lerpf(-1.15, 1.15, float(i + 1) / float(pts - 1))
				var w0 := float(layer[1]) * cos(a0 * 1.25)
				var w1 := float(layer[1]) * cos(a1 * 1.25)
				var p0 := Vector3(sin(a0) * 1.15, float(layer[2]) * -1.0, -cos(a0) * 0.55 + float(layer[2]))
				var p1 := Vector3(sin(a1) * 1.15, float(layer[2]) * -1.0, -cos(a1) * 0.55 + float(layer[2]))
				mb.add_quad(m, p0 + Vector3(0, 0, -w0), p1 + Vector3(0, 0, -w1), p1 + Vector3(0, 0, w1), p0 + Vector3(0, 0, w0), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
		_mesh.mesh = mb.commit()
		_mesh.material_override = _mat
		if kind == "wave":
			_mesh.scale = Vector3(1.9, 1.9, 1.6)
			_mesh.rotation.z = PI * 0.5
			_mesh.position.y = 0.6
	elif kind == "axe":
		_mesh.mesh = Props.weapon_mesh(model)
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
	if kind == "axe" and _back:
		_return_update(delta)
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
		if kind == "axe":
			_turn_back()
			return
		_finish()
		return
	if kind == "seed":
		var pc0 := _pc()
		if pc0 and not pc0.enemies_in(to, 0.5).is_empty():
			global_position = to
			_finish()
			return
	else:
		_cut_along(from, to)
	global_position = to
	_travel += step.length()
	match kind:
		"seed":
			_mesh.rotation += Vector3(9.0, 6.0, 0.0) * delta
		"axe":
			_mesh.rotation.x -= 22.0 * delta
		_:
			# a wake behind it (the wave tears the ground up as it goes)
			if int(_travel / 1.4) != int((_travel - step.length()) / 1.4):
				if kind == "wave":
					FX.dust(global_position, 4, 0.7)
				if _elemental():
					var at := global_position + Vector3.UP * (0.8 if kind == "wave" else 0.0)
					_element(at, -dir + Vector3.UP * 0.4, 3 if kind == "slash" else 5, 2.5)
	if _travel >= range_m:
		if kind == "axe":
			_turn_back()
		else:
			_finish()


func _pc() -> PowerComponent:
	return source.get("power") as PowerComponent if source and is_instance_valid(source) else null


## Cut along the whole step (a long frame mustn't skip over someone).
func _cut_along(from: Vector3, to: Vector3) -> void:
	var n := maxi(int(ceil(from.distance_to(to) / 0.8)), 1)
	for i in range(1, n + 1):
		_cut(from.lerp(to, float(i) / float(n)))


## Everything the blade passes through gets cut (once per pass).
func _cut(at: Vector3) -> void:
	var pc := _pc()
	if pc == null:
		return
	var r := 1.3
	if kind == "wave":
		r = 1.9
	elif kind == "axe":
		r = 1.1
	for e in pc.enemies_in(at + Vector3.UP * (0.6 if kind == "wave" else 0.0), r):
		if e in _hit:
			continue
		_hit.append(e)
		var hb := (e as Node).get("hurtbox") as Hurtbox
		if hb == null:
			continue
		var hd := (source as Player).melee_hit(damage, "skill")
		hd.knockback_force = 9.0 if kind == "wave" else 6.0
		hd.stagger_duration = 0.35
		hd.hitstop_duration = 0.05
		hd.camera_shake_intensity = 0.08
		hd.knockdown = kind == "wave"
		hd.sever = true
		# a thrown axe is a missile: a sword guard doesn't stop it
		hd.ranged = kind == "axe"
		hb.take_hit(hd, source)
		pc.add_ult(hd.damage)
		pc.on_sword_hit(e, hd)
		var hit_at := (e as Node3D).global_position + Vector3(0, 1.0, 0)
		FX.impact(hit_at, FX.tree_col(_tree(), FX.ACCENT))
		if kind != "axe":
			if _elemental():
				_element(hit_at, dir + Vector3.UP * 0.3, 10, 5.0)
			FX.ring(hit_at, dir, 1.1, FX.tree_col(_tree(), FX.EDGE), 0.22, 0.2)


## Its element thrown along `d`: sea spray off the cutlass's slash, petals off the katana's wave.
func _element(at: Vector3, d: Vector3, amount: int, spd: float) -> void:
	if kind == "wave":
		FX.petals(at, d, amount, FX.tree_col(_tree(), FX.ACCENT), spd * 0.8)
	else:
		FX.spray(at, d, amount, FX.tree_col(_tree(), FX.ACCENT), spd)


func _turn_back() -> void:
	_back = true
	_hit.clear()
	FX.sfx("whoosh", global_position, -6.0, 0.1, 0.9)


## The axe flies back to the thrower's hand, cutting on the way.
func _return_update(delta: float) -> void:
	if source == null or not is_instance_valid(source):
		queue_free()
		return
	var hand := source.global_position + Vector3.UP * 1.2
	var to_hand := hand - global_position
	if to_hand.length() < 0.8:
		_done = true
		returned.emit()
		queue_free()
		return
	var step := to_hand.normalized() * minf(speed * 1.1 * delta, to_hand.length())
	_cut_along(global_position, global_position + step)
	global_position += step
	_mesh.rotation.x -= 22.0 * delta


func _finish() -> void:
	_done = true
	if kind == "seed":
		var pc := _pc()
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
	if _core:
		tw.parallel().tween_property(_core, "albedo_color:a", 0.0, 0.15)
	tw.tween_callback(queue_free)


## Whose colours it flies in (FX.TREE_FX): a slash or a wave wears its tree's
## only when launched with model "elem" (the element awakened), plain steel otherwise.
func _tree() -> String:
	if kind in ["slash", "wave"] and model != "elem":
		return "plain"
	return {"slash": "sword", "wave": "katana", "axe": "axe"}.get(kind, "unarmed")


func _elemental() -> bool:
	return _tree() != "plain"
