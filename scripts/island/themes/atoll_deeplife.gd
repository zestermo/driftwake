extends RefCounted
## The coral atoll's deep basin alive (1.30): big shoals of reef fish wheeling round its pillars at every depth, jacks
## in silver walls, eagle rays and turtles gliding round it (all on the shoal shader: no CPU), and its predators: reef
## sharks prowling a slow circle through it (Prowler: a diver who comes close gets a tell, then a charge and a bite;
## judged on each captain's own machine, like the morays, their circle on the shared sea clock so every screen sees them
## in the same place). Spearfishing works anywhere this deep (SpearSchool), and its pillars have spear spots
## (AtollReef.harvest). The build step: AtollTheme.steps.

const D := preload("res://scripts/island/themes/atoll_data.gd")
const SHOALS := preload("res://scripts/island/themes/atoll_shoals.gd")
const REEF := preload("res://scripts/island/themes/atoll_reef.gd")

const SCHOOLS := [8, 12]
const SCHOOL_FISH := [40, 80]
const JACKS := 2
const RAYS := 3
const TURTLES := 2
## Prowling reef sharks: how many, the big one's size.
const SHARKS := 2
const BIG := 1.7
const SEE := 160.0
## Bright reef colours for the basin's shoals: anthias orange, fusilier blue, sergeant-major yellow, chromis green.
const FISH := [Color(1.0, 0.55, 0.3), Color(0.3, 0.55, 1.0), Color(1.0, 0.9, 0.35), Color(0.45, 0.95, 0.75), Color(0.95, 0.4, 0.6), Color(0.85, 0.88, 0.95)]

static var _shark: ArrayMesh
static var _jack: ArrayMesh


static func build(isl) -> void:
	var L = isl._theme.LAND_FEATURES
	var lp: Dictionary = isl.land_plan
	var hole: Array = lp["hole"]
	var hc: Vector2 = hole[0]
	var r: float = hole[1]
	var fy: float = hole[2]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "atoll_deeplife"])
	if _shark == null:
		_shark = shark_mesh()
		_jack = _fish_big()
	var node := Node3D.new()
	node.name = "AtollDeepLife"
	isl.add_child(node)
	var fish: ArrayMesh = SHOALS._fish_mesh
	for i in range(rng.randi_range(SCHOOLS[0], SCHOOLS[1])):
		var a := rng.randf() * TAU
		var q := hc + Vector2.from_angle(a) * float(L.basin_r(lp, a)) * rng.randf_range(0.1, 0.8)
		var y := rng.randf_range(fy + 3.0, -4.0)
		SHOALS._add(node, fish, 0, Vector3(q.x, y, q.y), rng.randi_range(SCHOOL_FISH[0], SCHOOL_FISH[1]), rng.randf_range(4.0, 8.0), 2.5,
			FISH[rng.randi() % FISH.size()], rng, SEE)
	for i in range(JACKS):
		var q := hc + Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.2, 0.5)
		SHOALS._add(node, _jack, 0, Vector3(q.x, rng.randf_range(fy + 6.0, -8.0), q.y), rng.randi_range(25, 40), rng.randf_range(6.0, 10.0), 4.0, Color(0.78, 0.82, 0.86), rng, SEE)
	for i in range(RAYS + TURTLES):
		var turtle := i >= RAYS
		var q := hc + Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.0, 0.3)
		SHOALS._add(node, REEF._meshes["turtle" if turtle else "ray"], 0, Vector3(q.x, rng.randf_range(fy + 4.0, -6.0), q.y), 1 if turtle else rng.randi_range(1, 2),
			rng.randf_range(r * 0.3, r * 0.6), 2.0, Color(0.5, 0.42, 0.28) if turtle else Color(0.22, 0.26, 0.32), rng, SEE)
	for i in range(SHARKS):
		var s := Prowler.new()
		s.name = "Shark%d" % i
		s.big = i == SHARKS - 1
		s.mesh = _shark
		s.size = BIG if s.big else 1.0
		s.ring_r = r * rng.randf_range(0.35, 0.6)
		s.depth = rng.randf_range(fy * 0.55, fy * 0.3)
		s.phase = rng.randf() * TAU
		s.turn = (0.07 if s.big else 0.1) * (1.0 if i % 2 == 0 else -1.0)
		s.position = Vector3(hc.x, 0.0, hc.y)
		node.add_child(s)


## A reef shark (nose -z): a long body, the dorsal fin, the tail's two lobes, pectorals; grey over a pale belly.
static func shark_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var mat := PSXMat.lit("", Color.WHITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var grey := Color(0.45, 0.5, 0.56)
	mb.add_blob(mat, Transform3D(Basis(), Vector3(0, 0, 0)), Vector3(0.28, 0.3, 1.1), rng, 0.04, 3, 8, 0.5, grey)
	mb.add_blob(mat, Transform3D(Basis(), Vector3(0, -0.1, -0.1)), Vector3(0.24, 0.16, 0.9), rng, 0.04, 2, 7, 0.5, Color(0.85, 0.86, 0.84))
	mb.add_cone(mat, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 1.0)), 0.16, 0.7, 5, 0.5, grey.darkened(0.1))
	mb.add_tri(mat, Vector3(0, 0.25, -0.2), Vector3(0, 0.75, 0.15), Vector3(0, 0.25, 0.35), Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, grey, Vector3.RIGHT)
	mb.add_tri(mat, Vector3(0, 0.0, 1.55), Vector3(0, 0.65, 1.95), Vector3(0, 0.05, 1.75), Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, grey, Vector3.RIGHT)
	mb.add_tri(mat, Vector3(0, 0.0, 1.55), Vector3(0, -0.4, 1.85), Vector3(0, -0.02, 1.7), Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, grey, Vector3.RIGHT)
	for s in [-1.0, 1.0]:
		mb.add_tri(mat, Vector3(s * 0.2, -0.12, -0.3), Vector3(s * 0.75, -0.3, 0.1), Vector3(s * 0.2, -0.12, 0.1), Vector3.UP, Vector3.UP, Vector3.UP, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, grey, Vector3.UP)
	mb.add_backfaces(mat, 0.8)
	return mb.commit()


## A jack: the shoal's little fish scaled up and silvered (nose -z).
static func _fish_big() -> ArrayMesh:
	var src: ArrayMesh = SHOALS._fish_mesh
	var arrays := src.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(v.size()):
		v[i] *= 3.2
	arrays[Mesh.ARRAY_VERTEX] = v
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## A reef shark prowling the basin: a slow circle (ring_r round the basin's middle at `depth`, on Ocean.clock(), so
## every screen agrees); this machine's diver within NOTICE gets its tell (it turns on them, its tail beating fast,
## TELL s), then a charge (CHARGE m/s for up to CHARGE_S s) and a bite inside BITE_R; it swings back to its circle and
## won't come again for COOL s. Asleep (no work, hidden) while the camera's over WAKE m off.
class Prowler extends Node3D:
	const NOTICE := 7.0
	const TELL := 0.7
	const CHARGE := 7.5
	const CHARGE_S := 2.0
	const BITE_R := 1.8
	const BITE := 14.0
	const COOL := 7.0
	const BACK := 3.0
	const WAKE := 140.0
	var big := false
	var mesh: Mesh
	var size := 1.0
	var ring_r := 20.0
	var depth := -15.0
	var phase := 0.0
	var turn := 0.1
	var _body: MeshInstance3D
	var _at := Vector3.ZERO
	var _mode := 0
	var _t := 0.0
	var _cool := 0.0
	var _check := 0.0

	func _ready() -> void:
		_body = MeshInstance3D.new()
		_body.name = "Shark"
		_body.mesh = mesh
		_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.visibility_range_end = WAKE
		_body.scale = Vector3.ONE * size
		_body.top_level = true
		add_child(_body)
		_at = _ring(0.0)
		_place(_at, _ring(0.5) - _at)

	func _ring(ahead: float) -> Vector3:
		var a: float = phase + (float(get_node("/root/Ocean").clock()) + ahead) * turn
		return global_position + Vector3(cos(a) * ring_r, depth, sin(a) * ring_r)

	func _place(p: Vector3, dir: Vector3) -> void:
		_body.global_position = p
		if dir.length_squared() > 0.0001:
			_body.global_basis = Basis.looking_at(dir.normalized(), Vector3.UP).scaled(_body.scale)

	func _physics_process(delta: float) -> void:
		_check -= delta
		if _mode == 0 and _check > 0.0:
			return
		var cam := get_viewport().get_camera_3d()
		if _mode == 0:
			_at = _ring(0.0)
		if cam == null or cam.global_position.distance_to(_at) > WAKE:
			_check = 1.0
			_body.visible = false
			return
		_body.visible = true
		_cool -= delta
		var me := get_tree().get_first_node_in_group("player") as Player
		var target := me.global_position + Vector3(0, 0.9, 0) if me != null else Vector3.ZERO
		match _mode:
			0:
				_place(_at, _ring(0.5) - _at)
				if me != null and _cool <= 0.0 and me.is_swimming() and _at.distance_to(target) < NOTICE * (1.3 if big else 1.0):
					_mode = 1
					_t = 0.0
			1:
				_t += delta
				_at = _at.move_toward(target, 1.2 * delta)
				_place(_at + Vector3(0, sin(_t * 30.0) * 0.04, 0), target - _at)
				if _t >= TELL:
					_mode = 2
					_t = 0.0
					me.get_node("/root/FX").bubbles(_at, 6)
			2:
				_t += delta
				_at = _at.move_toward(target, CHARGE * delta)
				_place(_at, target - _at)
				if _at.distance_to(target) < BITE_R * (1.3 if big else 1.0) and me.is_swimming():
					me.health_component.take_damage(BITE * (1.4 if big else 1.0) * (1.0 - me.damage_reduction()))
					me.get_node("/root/FX").blood(target, (target - _at).normalized(), 10)
					me.get_node("/root/CombatManager").apply_camera_shake(0.2)
					me.call("_toast", "A reef shark bit you!")
					_mode = 3
					_t = 0.0
				elif _t >= CHARGE_S:
					_mode = 3
					_t = 0.0
			3:
				_t += delta
				var home := _ring(0.0)
				_at = _at.lerp(home, clampf(_t / BACK, 0.0, 1.0) * clampf(delta * 3.0, 0.0, 1.0)).move_toward(home, 3.0 * delta)
				_place(_at, home - _at + (_ring(0.5) - home))
				if _t >= BACK:
					_mode = 0
					_cool = COOL
