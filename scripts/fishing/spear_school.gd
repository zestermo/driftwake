class_name SpearSchool
extends Node3D
## Spearfishing (1.28, docs/life_systems_plan.md): diving in water deeper than DEEP_M, a small school of the waters'
## fish (3-5, the rod's pool off that coast, never a legendary) circles the diver. Right mouse aims (a line along the
## view, SwimState sets `aiming`), left mouse throws the spear (SPEED, REACH, RECOVER s to the next); a fish it passes
## through is landed like a rod catch (Fishing.land: the bag, the journal, Fishing mastery; no bait). The diver's own
## spear: no item. Local to the diving captain's machine (the catch is theirs, like the rod's).

const DEEP_M := 2.5
const SPEED := 18.0
const REACH := 9.0
const RECOVER := 1.2
const COUNT := Vector2i(3, 5)
const RADIUS := Vector2(2.2, 4.5)
const HIT_R := 0.5
## How quickly the school's centre follows the diver (per s).
const FOLLOW := 0.8

static var _line_mat: StandardMaterial3D

var player
var fish: Array = []
var aiming := false
var caught := 0
var _centre := Vector3.ZERO
var _cd := 0.0
var _spear: MeshInstance3D
var _spear_dir := Vector3.ZERO
var _spear_went := -1.0
var _aim: MeshInstance3D
var _im: ImmediateMesh


## A school round `p` from the catches that bite there (null when nothing would).
static func make(p) -> SpearSchool:
	var tree: SceneTree = p.get_tree()
	var at: Vector3 = p.global_position
	var night := Fishing.night(p)
	var ids := FishTable.pool(FishTable.water_at(tree, at), FishTable.theme_at(tree, at), night).filter(
		func(id): return FishTable.rarity_of(id) < 4 and str(FishTable.CATCHES[id][0]) != "")
	if ids.is_empty():
		return null
	var s := SpearSchool.new()
	s.name = "SpearSchool"
	s.player = p
	tree.current_scene.add_child(s)
	s._centre = at
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	for i in range(rng.randi_range(COUNT.x, COUNT.y)):
		var id: String = FishTable.roll(ids, 1.0, 1.0, rng)
		var lk := FishTable.look_of(id)
		var mi := MeshInstance3D.new()
		mi.mesh = FishModels.fish(str(lk[0]), float(lk[1]), lk[2], lk[3])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.add_child(mi)
		s.fish.append({"id": id, "mi": mi, "ang": rng.randf() * TAU, "r": rng.randf_range(RADIUS.x, RADIUS.y),
			"y": rng.randf_range(-0.8, 0.8), "spd": rng.randf_range(0.7, 1.3) * (1.0 if rng.randf() < 0.5 else -1.0), "ph": rng.randf() * TAU})
	s._build_spear()
	return s


func _build_spear() -> void:
	_spear = MeshInstance3D.new()
	var mb := MeshBuilder.new()
	mb.add_box(PSXMat.flat(Color(0.55, 0.42, 0.28)), Transform3D(Basis(), Vector3(0, 0, 0.2)), Vector3(0.03, 0.03, 1.2))
	mb.add_box(PSXMat.flat(Color(0.75, 0.78, 0.8)), Transform3D(Basis(), Vector3(0, 0, -0.5)), Vector3(0.05, 0.02, 0.22))
	_spear.mesh = mb.commit()
	_spear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spear.visible = false
	add_child(_spear)
	if _line_mat == null:
		_line_mat = StandardMaterial3D.new()
		_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_line_mat.albedo_color = Color(0.85, 0.95, 1.0, 0.55)
		_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_im = ImmediateMesh.new()
	_aim = MeshInstance3D.new()
	_aim.mesh = _im
	_aim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim.extra_cull_margin = 12.0
	add_child(_aim)


## Where the spear goes: along the view (the camera's forward), from the diver's chest.
func aim_dir() -> Vector3:
	var cam: Camera3D = player.get_viewport().get_camera_3d()
	return -cam.global_basis.z if cam else -player.player_model.global_basis.z


func _chest() -> Vector3:
	return player.global_position + Vector3.UP * 0.9


## Left mouse while aiming: the spear flies (false while it recovers).
func throw(dir := Vector3.ZERO) -> bool:
	if _cd > 0.0:
		return false
	_cd = RECOVER
	_spear_dir = (aim_dir() if dir == Vector3.ZERO else dir).normalized()
	_spear_went = 0.0
	_spear.global_position = _chest()
	_spear.visible = true
	_spear.look_at(_chest() + _spear_dir, Vector3.UP if absf(_spear_dir.y) < 0.98 else Vector3.RIGHT)
	FX.bubbles(_chest(), 6)
	FX.sfx("whoosh", _chest(), -6.0, 0.1, 1.3)
	return true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
	_cd = maxf(_cd - delta, 0.0)
	_centre = _centre.lerp(player.global_position, clampf(FOLLOW * delta, 0.0, 1.0))
	var t := float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)
	for f in fish:
		f["ang"] = float(f["ang"]) + float(f["spd"]) * delta * 2.0 / float(f["r"])
		var a := float(f["ang"])
		var at := _centre + Vector3(cos(a) * float(f["r"]), float(f["y"]) + 0.25 * sin(t * 1.3 + float(f["ph"])), sin(a) * float(f["r"]))
		var mi: MeshInstance3D = f["mi"]
		var ahead := at + Vector3(-sin(a), 0.0, cos(a)) * signf(float(f["spd"]))
		mi.global_position = at
		if ahead.distance_squared_to(at) > 0.0001:
			mi.look_at(ahead, Vector3.UP)
	_spear_tick(delta)
	_draw_aim()


func _spear_tick(delta: float) -> void:
	if _spear_went < 0.0:
		return
	var step := SPEED * delta
	var from := _spear.global_position
	_spear.global_position = from + _spear_dir * step
	_spear_went += step
	for f in fish.duplicate():
		if _seg_dist((f["mi"] as Node3D).global_position, from, _spear.global_position) < HIT_R:
			_catch(f)
			break
	if _spear_went >= REACH:
		_spear_went = -1.0
		_spear.visible = false


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * k)


## A fish speared: landed like a rod catch, gone from the school.
func _catch(f: Dictionary) -> void:
	var at: Vector3 = (f["mi"] as Node3D).global_position
	fish.erase(f)
	(f["mi"] as Node).queue_free()
	_spear_went = -1.0
	_spear.visible = false
	caught += 1
	FX.bubbles(at, 10)
	FX.sfx("fish_catch", at, -4.0, 0.05)
	Fishing.land(player, str(f["id"]), "", at)


func _draw_aim() -> void:
	_im.clear_surfaces()
	if not aiming or _cd > 0.0:
		return
	var a := _chest()
	var d := aim_dir().normalized()
	_im.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat)
	# a dashed line out to the spear's reach
	var n := 9
	for i in range(n):
		_im.surface_add_vertex(a + d * (REACH * (float(i) + 0.15) / n))
		_im.surface_add_vertex(a + d * (REACH * (float(i) + 0.6) / n))
	_im.surface_end()
