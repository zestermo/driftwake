class_name Projectile
extends Node3D
## Flying skill projectiles other than the Fire Fist:
##   "slash"  Flying Slash: a crescent of wind that cuts through every enemy in
##            its path (pierces), stopped by walls.
##   "wave"   Wind Severer: a tall crescent standing on its edge, bigger and
##            slower, knocking down everything it passes.
##   "gale"   a greatsword's crescent of air pressure (a full-charge cleave, its techniques): the slash's crescent
##            stood on its edge, faster and shorter-lived, staggering everything it passes ("gale_flat": lying flat,
##            wider, off a flat sweep).
##   "axe"    Hatchet Throw: the thrower's axe spinning out and back to the hand,
##            cutting everything on the way out and again on the way back.
##   "javelin" Thunder Javelin: the thrower's spear point-first down a 16 m line (piercing, breaking
##            wind-ups), a beat at the end, then yanked back to the hand on a crackle of lightning,
##            cutting the line again; the held spear is hidden while it flies (on every screen).
##   "raven_l" / "raven_r" Ravens' Return: a twin axe (the off hand's / the right's) thrown out on a loop that fans
##            out to its side RAVEN_W m, reaches RAVEN_L m ahead, crosses the other at the tip and curves home to
##            its hand in RAVEN_T s; it only shows the flight (the technique cuts on the sweep, DualAxeArts).
##   "hook"   Gallows Hook: the off hand's axe flung straight out (`direction`'s length is how far) and back to the
##            hand, slower, with whoever it hooked; shown only.
##            Thrown twin axes hide the one held in that hand while they fly and leave a ribbon along their path.
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
var _hang := -1.0
var _crackle := 0.0
var _held: Node3D
var _from := Vector3.ZERO
var _age := 0.0
var _fade := -1.0
var _ribbon: MeshInstance3D
var _rim := ImmediateMesh.new()
var _rpts: Array = []
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _core: StandardMaterial3D

signal returned

const JAVELIN_RANGE := 16.0
const JAVELIN_HANG := 0.18
const JAVELIN_BOLT := 8.0
const RAVEN_L := 10.0
const RAVEN_W := 4.5
const RAVEN_T := 1.2
const HOOK_OUT := 60.0
const HOOK_BACK := 20.0
const RIBBON_LIFE := 0.2
static var _ribbon_mat: StandardMaterial3D


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
		"gale", "gale_flat":
			p.speed = 26.0
			p.range_m = 10.0
		"axe":
			p.speed = 20.0
			p.range_m = 13.0
		"javelin":
			p.speed = 36.0
			p.range_m = JAVELIN_RANGE
		"hook":
			p.speed = HOOK_OUT
			p.range_m = direction.length()
	var root: Node = tree.current_scene if tree.current_scene else tree.root
	root.add_child(p)
	p.global_position = from
	if src is Player:
		(src as Player).net_power("projectile", [k, from, direction, dmg, weapon_model])
	return p


func _ready() -> void:
	add_to_group("projectiles")
	_mesh = MeshInstance3D.new()
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if kind == "wave":
		# Wind Severer: a tall crescent of the katana's drawn strip standing across the flight path,
		# bowed forward, its crest outside (steel; cloud and petals once awakened), stepping
		# through the strip's frames as it flies
		_mat = PetalRibbon.material(_elemental()).duplicate() as StandardMaterial3D
		_mat.vertex_color_use_as_albedo = false
		_mesh.mesh = _wave_mesh()
		_mesh.material_override = _mat
	elif kind in ["slash", "gale", "gale_flat"]:
		# a thin crescent lying across the flight path (stood on its edge for the
		# gale): a coloured sheath round a hot white core
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
		if kind == "gale":
			# (stood on its edge: the cleave's own plane, racing along the ground)
			_mesh.rotation = Vector3(0, 0, PI * 0.5)
			_mesh.scale = Vector3(1.0, 1.0, 1.3)
		elif kind == "gale_flat":
			# (a flat sweep's: lying across the line, half again as wide)
			_mesh.scale = Vector3(1.6, 1.0, 1.3)
	elif kind in ["axe", "javelin"]:
		_mesh.mesh = Props.weapon_mesh(model.trim_prefix("elem|"))
		if kind == "javelin" and source is Player and (source as Player).body_model:
			_held = (source as Player).body_model.weapon
			if _held:
				_held.visible = false
	elif _thrown():
		_mesh.mesh = Props.weapon_mesh(model.trim_prefix("elem|"))
		if source is Player and (source as Player).body_model:
			var body := (source as Player).body_model
			_held = body.weapon if kind == "raven_r" else body.offhand
			if _held:
				_held.visible = false
		if _ribbon_mat == null:
			_ribbon_mat = StandardMaterial3D.new()
			_ribbon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_ribbon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_ribbon_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			_ribbon_mat.vertex_color_use_as_albedo = true
			_ribbon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ribbon = MeshInstance3D.new()
		_ribbon.top_level = true
		_ribbon.mesh = _rim
		_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ribbon)
		_ribbon.global_transform = Transform3D.IDENTITY
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
	if _fade >= 0.0:
		_fade -= delta
		_age += delta
		_draw_ribbon(false)
		if _fade < 0.0:
			queue_free()
		return
	if _done:
		return
	if _thrown():
		_fly_update(delta)
		return
	if kind in ["axe", "javelin"] and _back:
		_return_update(delta)
		return
	if _hang >= 0.0:
		_hang_update(delta)
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
		if kind == "javelin":
			_hang = JAVELIN_HANG
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
			_axe_wake(step.length())
		"javelin":
			_javelin_wake(step.length())
		_:
			if kind == "wave":
				_mat.uv1_offset = Vector3(-floorf(_travel * 0.3 * 64.0) / 64.0, float(int(_travel * 1.4) % 8) / 8.0, 0.0)
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
		elif kind == "javelin":
			_hang = JAVELIN_HANG
		else:
			_finish()


## The wave's crescent (local: -Z ahead, standing up on +Y): 2.7 m tall, bowed forward and out to
## the right, thickest in the middle, the strip's crest (its top rows) along the outside.
static func _wave_mesh() -> ArrayMesh:
	var n := 16
	var pts: Array = []
	for i in n + 1:
		var s := float(i) / n
		pts.append(Vector3(0.6 * sin(PI * s) - 0.3, 0.1 + 2.6 * s, -0.45 * sin(PI * s)))
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var along := 0.0
	var rows: Array = []
	for i in n + 1:
		var s := float(i) / n
		var p: Vector3 = pts[i]
		var tan: Vector3 = ((pts[mini(i + 1, n)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var out := tan.cross(Vector3.BACK).normalized()
		if out.x < 0.0:
			out = -out
		var w := 1.0 * pow(sin(PI * s), 0.6) + 0.03
		if i > 0:
			along += p.distance_to(pts[i - 1])
		rows.append([p + out * w * 0.6, p - out * w * 0.4, along / 2.4])
	for i in n:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		verts.append_array([a[0], b[0], a[1], a[1], b[0], b[1]])
		uvs.append_array([Vector2(a[2], 0.002), Vector2(b[2], 0.002), Vector2(a[2], 0.123), Vector2(a[2], 0.123), Vector2(b[2], 0.002), Vector2(b[2], 0.123)])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


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
	elif kind in ["gale", "gale_flat"]:
		r = 1.8
	elif kind in ["axe", "javelin"]:
		r = 1.1
	for e in pc.enemies_in(at + Vector3.UP * (0.6 if kind == "wave" else 0.0), r):
		if e in _hit:
			continue
		_hit.append(e)
		var hb := (e as Node).get("hurtbox") as Hurtbox
		if hb == null:
			continue
		var hd := (source as Player).melee_hit(damage * (0.7 if kind == "javelin" and _back else 1.0), "skill")
		hd.knockback_force = 9.0 if kind == "wave" else 6.0
		hd.stagger_duration = 0.6 if kind.begins_with("gale") or kind == "javelin" else 0.35
		hd.breaker = kind == "javelin"
		hd.hitstop_duration = 0.05
		hd.camera_shake_intensity = 0.08
		hd.knockdown = kind == "wave"
		hd.sever = true
		# a thrown axe is a missile: a sword guard doesn't stop it
		hd.ranged = kind in ["axe", "javelin"]
		hb.take_hit(hd, source)
		pc.add_ult(hd.damage)
		pc.on_sword_hit(e, hd)
		var hit_at := (e as Node3D).global_position + Vector3(0, 1.0, 0)
		var through := (dir if not _back else (source.global_position - global_position)).normalized()
		FX.impact(hit_at, FX.tree_col(_tree(), FX.ACCENT))
		if _elemental():
			_element(hit_at, through + Vector3.UP * 0.3, 10, 5.0)
		FX.ring(hit_at, through, 1.1, FX.tree_col(_tree(), FX.EDGE), 0.22, 0.2)


## Its element thrown along `d`: sea spray off the cutlass's slash, petals off the
## katana's wave, embers off the axe.
func _element(at: Vector3, d: Vector3, amount: int, spd: float) -> void:
	FX.element(_tree(), at, d, amount, spd * (0.8 if kind == "wave" else 1.0))


## The thrown axe's wake: a drawn crescent every turn or so, cinders once its element is awakened.
func _axe_wake(moved: float) -> void:
	if int(_travel / 2.0) == int((_travel - moved) / 2.0):
		return
	# (a drawn crescent of its spin: iron, or fire once awakened)
	FX.drawn_arc("axe", global_position, Vector3.UP, -dir if not _back else dir, 0.55, PI * 1.2, 0.4, _elemental(), 0.08, int(_travel * 10.0) % 1000)
	if _elemental():
		_element(global_position, -dir + Vector3.UP * 0.5, 4, 2.0)


func _turn_back() -> void:
	_back = true
	_hit.clear()
	FX.sfx("whoosh", global_position, -6.0, 0.1, 0.9)


## The javelin's beat at the end of its line, quivering, the lightning finding it; then the yank home (with the
## element awakened, a bolt drops on everyone it pierced first: from the thrower's machine, seen on every one).
func _hang_update(delta: float) -> void:
	_hang -= delta
	_mesh.position = Vector3(0, 0.025 * sin(_hang * 90.0), 0)
	if _hang > 0.0:
		return
	_hang = -1.0
	_mesh.position = Vector3.ZERO
	var pc := _pc()
	if _elemental() and pc and (source as Player).is_local:
		for e in _hit:
			if not is_instance_valid(e):
				continue
			var c := (e as Node3D).global_position + Vector3(0, 1.0, 0)
			Net.fx("bolt", [c + Vector3(randf_range(-0.5, 0.5), 7.0, randf_range(-0.5, 0.5)), c, FX.tree_col("polearm", FX.EDGE), 0.1, 0.28, randi() % 1000])
			Net.fx("element", ["polearm", c, Vector3.UP, 6, 3.5])
			var hb := (e as Node).get("hurtbox") as Hurtbox
			if hb:
				var hd := (source as Player).melee_hit(JAVELIN_BOLT, "skill")
				hd.knockback_force = 2.0
				hd.stagger_duration = 0.5
				hb.take_hit(hd, source)
				pc.add_ult(hd.damage)
	FX.sfx("jelly_zap", global_position, -6.0, 0.08, 1.3)
	_turn_back()


## Where a returning weapon flies to: the javelin and the right raven to the thrower's right hand, the left raven
## and the hook to the left, the axe to the chest.
func _home() -> Vector3:
	if kind in ["javelin", "raven_r", "raven_l", "hook"] and source is Player and (source as Player).body_model:
		var body := (source as Player).body_model
		return (body.hand_r if kind in ["javelin", "raven_r"] else body.hand_l).global_position
	return source.global_position + Vector3.UP * 1.2


func _thrown() -> bool:
	return kind in ["raven_l", "raven_r", "hook"]


## Where a raven is `s` (0-1) of the way round its loop, from the hand it left: out on its own side
## (`side` 1 right), across the other at the tip RAVEN_L ahead, and home on the far side, a little rise mid-flight.
static func raven_offset(s: float, side: float, fwd: Vector3) -> Vector3:
	var th := TAU * s
	var right := fwd.cross(Vector3.UP).normalized()
	return fwd * RAVEN_L * (1.0 - cos(th)) * 0.5 + right * side * RAVEN_W * sin(th) + Vector3.UP * 0.6 * sin(th * 0.5)


## A thrown twin axe's flight: the ravens round their loops (eased home into the hand as it moves), the hook
## straight out and back; spinning, the ribbon laid along where it really went.
func _fly_update(delta: float) -> void:
	if source == null or not is_instance_valid(source):
		_land()
		return
	# (launch() places it after _ready: where it left from is only known here)
	if _age == 0.0:
		_from = global_position
	_age += delta
	var was := global_position
	var pos := was
	var home := false
	if kind == "hook":
		if not _back:
			pos = was + dir * minf(speed * delta, range_m - _travel)
			_travel += pos.distance_to(was)
			if _travel >= range_m - 0.01:
				_back = true
		else:
			var to := _home() - was
			pos = was + to.normalized() * minf(HOOK_BACK * delta, to.length())
			home = to.length() < 0.5
	else:
		var s := minf(_age / RAVEN_T, 1.0)
		pos = _from + raven_offset(s, 1.0 if kind == "raven_r" else -1.0, dir) + (_home() - _from) * smoothstep(0.7, 1.0, s)
		home = s >= 1.0
	var v := pos - was
	if v.length() > 0.01 and absf(v.normalized().y) < 0.98:
		global_basis = Basis.looking_at(v.normalized(), Vector3.UP)
	global_position = pos
	_mesh.rotation.x -= (18.0 if kind == "hook" else 24.0) * delta
	_draw_ribbon(true)
	if home:
		_land()


func _land() -> void:
	_done = true
	_finish_held()
	returned.emit()
	_mesh.visible = false
	_fade = RIBBON_LIFE
	FX.sfx("clack", global_position, -9.0, 0.06, 1.1)


## The ribbon behind a thrown axe: its spun disc's height laid along the real path, fading over RIBBON_LIFE.
func _draw_ribbon(sample: bool) -> void:
	if sample:
		var at := global_position
		_rpts.append([_age, at + Vector3.UP * 0.17, at - Vector3.UP * 0.12])
	while not _rpts.is_empty() and _age - float(_rpts[0][0]) > RIBBON_LIFE:
		_rpts.pop_front()
	_rim.clear_surfaces()
	if _rpts.size() < 2:
		return
	var col := _col()
	var tip := col.lerp(Color.WHITE, 0.5)
	_rim.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _ribbon_mat)
	for p in _rpts:
		var a := 1.0 - (_age - float(p[0])) / RIBBON_LIFE
		_rim.surface_set_color(Color(col.r, col.g, col.b, 0.0))
		_rim.surface_add_vertex(p[2])
		_rim.surface_set_color(Color(tip.r, tip.g, tip.b, 0.75 * a * a))
		_rim.surface_add_vertex(p[1])
	_rim.surface_end()


## The weapon flies back to the thrower's hand, cutting on the way (the javelin butt first, on its tether).
func _return_update(delta: float) -> void:
	if source == null or not is_instance_valid(source):
		_finish_held()
		queue_free()
		return
	var to_hand := _home() - global_position
	if to_hand.length() < (0.6 if kind == "javelin" else 0.8):
		_done = true
		_finish_held()
		returned.emit()
		queue_free()
		return
	var step := to_hand.normalized() * minf(speed * 1.1 * delta, to_hand.length())
	_cut_along(global_position, global_position + step)
	global_position += step
	_travel += step.length()
	if kind == "javelin":
		if to_hand.length() > 0.3:
			global_basis = Basis.looking_at(-to_hand.normalized(), Vector3.UP) if absf(to_hand.normalized().y) < 0.98 else global_basis
		_javelin_wake(step.length())
		_crackle -= delta
		if _crackle <= 0.0:
			_crackle = 0.07
			FX.bolt(_home(), global_position, _col(), 0.04, 0.09, randi() % 1000)
		return
	_mesh.rotation.x -= 22.0 * delta
	_axe_wake(step.length())


## The javelin's wake: a thin streak behind the point, sparks off it once its element is awakened.
func _javelin_wake(moved: float) -> void:
	if int(_travel / 1.6) == int((_travel - moved) / 1.6):
		return
	var back := -dir if not _back else (_home() - global_position).normalized()
	FX.streak(global_position + back * 1.8, global_position, _col(), 0.04, 0.12)
	if _elemental():
		_element(global_position, back + Vector3.UP * 0.3, 3, 2.0)


func _col() -> Color:
	return FX.tree_col(_tree(), FX.EDGE)


## The spear back in the thrower's hand (or wherever it was, if they let go of it).
func _finish_held() -> void:
	if _held and is_instance_valid(_held):
		_held.visible = true


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
## only when launched with model "elem" (the element awakened), a thrown axe when
## its model starts "elem|"; plain steel otherwise.
func _tree() -> String:
	if kind in ["slash", "wave", "gale", "gale_flat"] and model != "elem":
		return "plain"
	if (kind in ["axe", "javelin"] or _thrown()) and not model.begins_with("elem|"):
		return "plain"
	return {"slash": "sword", "wave": "katana", "axe": "axe", "javelin": "polearm", "gale": "greatsword", "gale_flat": "greatsword",
		"raven_l": "dual_axe", "raven_r": "dual_axe", "hook": "dual_axe"}.get(kind, "unarmed")


func _elemental() -> bool:
	return _tree() != "plain"
