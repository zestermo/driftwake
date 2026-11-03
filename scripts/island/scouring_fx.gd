class_name ScouringFX
extends Node3D
## (1.30, the Scouring's look: docs/v1_30_plan.md) What every screen sees and hears of the shelling, worked out locally
## from StrongholdScouring's shells (the same shells on every machine, so nothing goes over the net):
## - the smoke: Weather.smoke up to 1 over SMOKE_IN s once the shells fall (a dark grey sky even at noon, so the fire
##   pops), fading with the camera's distance past the ring, and clearing over SMOKE_OUT s once the crew's out;
## - each shell: fired from the ring (a glow flying a high arc for the warning's length), its whistle WHISTLE s before
##   it lands, then a huge burst where it lands (a fireball, a rising column of fire and black smoke, stone thrown,
##   a shock ring, a flash light; a column of white water on the sea), heard far off; near the camera heavy shake and
##   an orange flash, both scaled by distance;
## - the long-range glows and smoke as one MultiMesh of cards (scouring_glow.gdshader), not FX bursts: those stop at
##   FX.BURST_RANGE and the shells land across the whole island.

const SMOKE_IN := 7.0
const SMOKE_OUT := 18.0
const WHISTLE := 1.8
const ARC_H := 70.0
## Near the camera: shake to this far, the orange flash to this far.
const SHAKE_R := 60.0
const FLASH_R := 32.0
const CARDS := 320
const GLOW := Color(1.0, 0.5, 0.16)
const SMOKE_COL := Color(0.14, 0.12, 0.11)

const GLOW_SHADER := preload("res://shaders/psx/scouring_glow.gdshader")

var sc: StrongholdScouring
var level := 0.0
## [from, to, fired (clock), lands (clock)] in flight; [at, when] whistles to come.
var flights: Array = []
var _whistles: Array = []
## Cards alive: [pos, born, life, size0, size1, Color, smoke (0/1), rise m/s, seed]
var _cards: Array = []
var _mm: MultiMesh
var _t := 0.0


func setup(scouring: StrongholdScouring) -> ScouringFX:
	sc = scouring
	name = "ScouringFX"
	return self


func _ready() -> void:
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	_mm.mesh = quad
	_mm.instance_count = CARDS
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Cards"
	mmi.multimesh = _mm
	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-2000, -100, -2000), Vector3(4000, 600, 4000))
	add_child(mmi)
	# (the cards are written in world space: this node stays at the origin, unturned)
	top_level = true
	global_transform = Transform3D.IDENTITY


func _exit_tree() -> void:
	get_node("/root/Weather").smoke = 0.0


func _clock() -> float:
	return float(get_node("/root/Ocean").clock())


func _process(delta: float) -> void:
	_t += delta
	_smoke(delta)
	var now := _clock()
	if _whistles.any(func(w): return float(w[1]) <= now):
		for w in _whistles.filter(func(w): return float(w[1]) <= now):
			FX.far_sfx("shell_whistle", w[0] + Vector3.UP * 12.0, 2.0, 140.0)
		_whistles = _whistles.filter(func(w): return float(w[1]) > now)
	flights = flights.filter(func(f): return float(f[3]) > now)
	_draw_cards(now)


## The sky: thick while the shells fall, fading with our captain's distance past the ring, clearing once out.
func _smoke(delta: float) -> void:
	var want := 1.0 if sc.state == "barrage" else 0.0
	level = move_toward(level, want, delta / (SMOKE_IN if want > level else SMOKE_OUT))
	var me := get_tree().get_first_node_in_group("player") as Node3D
	var k := 1.0
	if me:
		var c: Vector3 = sc.isl.city_global(StrongholdPlan.LAND_C, 0.0)
		var d := Vector2(me.global_position.x - c.x, me.global_position.z - c.z).length()
		k = 1.0 - smoothstep(sc.RING_R + 60.0, sc.RING_R + 420.0, d)
	get_node("/root/Weather").smoke = level * k


## A shell fired at `at`, landing at clock `lands`: its flight from the ring and its whistle.
func incoming(at: Vector3, lands: float, k: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["fired", k])
	var c: Vector3 = sc.isl.city_global(StrongholdPlan.LAND_C, 0.0)
	var from := c + Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU) * sc.RING_R * 0.85 + Vector3.UP * 8.0
	var now := _clock()
	flights.append([from, at, now, lands])
	_card(from, 0.35, 10.0, 16.0, GLOW, 0.0, 0.0)
	_card(from + Vector3.UP * 2.0, 5.0, 10.0, 22.0, SMOKE_COL.lightened(0.25), 1.0, 1.2)
	_whistles.append([at, lands - WHISTLE])


## A shell bursting at `at` (normal `n`; `water`: in the sea).
func landed(at: Vector3, n: Vector3, water: bool) -> void:
	if water:
		FX.plume(at, Vector3.UP, "splash", 7, 5.0, 1.8, Color(0.92, 0.96, 1.0, 0.95), 18.0, 8.0)
		FX.water_ring(at, 7.0, 1.6)
		FX.puff(at + Vector3.UP * 3.0, "mist", 3, 6.0, 2.4, Color(0.9, 0.95, 1.0, 0.7), 2.0)
		_card(at + Vector3.UP * 4.0, 0.3, 8.0, 14.0, Color(1.0, 0.75, 0.45), 0.0, 0.0)
		_card(at + Vector3.UP * 5.0, 2.6, 9.0, 16.0, Color(0.85, 0.9, 0.95, 0.9), 1.0, 2.5)
		FX.far_sfx("cannon_hit", at, 4.0, 160.0)
		FX.far_sfx("shell_far", at, 2.0, 700.0)
		_juice(at, 0.6)
		return
	# (FX's sheet colours are taken as linear: 0.05 reads as a sooty black-brown)
	FX.blast(at + n * 0.5, n, 4.5, true, Color(0.05, 0.042, 0.038, 0.95), 3.0)
	FX.plume(at + Vector3.UP, Vector3.UP, "fireball", 5, 4.5, 1.1, Color.WHITE, 16.0, 18.0)
	FX.debris(at + n * 0.3, n + Vector3.UP, 16, Color(0.36, 0.34, 0.33), 13.0)
	FX.puff_ring(at, "dust_low", 8, 1.0, 4.5, 1.6, Color(0.22, 0.19, 0.17), 14.0)
	FX.embers(at + Vector3.UP, Vector3.UP, 18, Color(1.0, 0.45, 0.12), 11.0)
	FX.ring(at, Vector3.UP, 11.0, Color(1.0, 0.62, 0.3), 0.45, 0.35)
	FX.flash_light(at + n * 3.0, FX.FIRE_LIGHT, 14.0, 34.0, 0.8)
	_card(at + n * 3.0, 0.55, 14.0, 26.0, GLOW, 0.0, 0.0)
	_card(at + Vector3.UP * 6.0, 1.3, 8.0, 18.0, Color(1.0, 0.42, 0.12, 0.9), 0.0, 9.0)
	_card(at + Vector3.UP * 8.0, 7.0, 10.0, 30.0, SMOKE_COL, 1.0, 3.5)
	FX.far_sfx("shell_boom", at, 6.0, 170.0)
	FX.far_sfx("shell_far", at, 4.0, 800.0)
	_juice(at, 1.0)


## This screen's shake and orange flash, by the camera's distance.
func _juice(at: Vector3, k: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := cam.global_position.distance_to(at)
	var s := pow(clampf(1.0 - d / SHAKE_R, 0.0, 1.0), 1.6)
	if s > 0.01:
		CombatManager.apply_camera_shake(0.4 * s * k, 0.4)
	if d < FLASH_R:
		FX.screen_flash(at, Color(1.0, 0.56, 0.2, 0.42 * (1.0 - d / FLASH_R) * k), 0.4)


func _card(p: Vector3, life: float, s0: float, s1: float, col: Color, smoke: float, rise: float) -> void:
	if _cards.size() >= CARDS - 32:
		_cards.pop_front()
	_cards.append([p, _t, life, s0, s1, col, smoke, rise, randf()])


## The cards alive and the shells in flight (a bright head, three fading after it along the arc).
func _draw_cards(now: float) -> void:
	_cards = _cards.filter(func(c): return _t - float(c[1]) < float(c[2]))
	var i := 0
	for c in _cards:
		var u := (_t - float(c[1])) / float(c[2])
		var col: Color = c[5]
		var a := col.a * (1.0 - u * u) if float(c[6]) > 0.5 else col.a * (1.0 - u)
		if float(c[6]) > 0.5:
			a *= smoothstep(0.0, 0.08, u)
		var s := lerpf(float(c[3]), float(c[4]), sqrt(u))
		var p: Vector3 = c[0] + Vector3.UP * float(c[7]) * (_t - float(c[1]))
		_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), p))
		_mm.set_instance_color(i, Color(col.r, col.g, col.b, a))
		_mm.set_instance_custom_data(i, Color(float(c[6]), float(c[8]), 0, 0))
		i += 1
	for f in flights:
		var span := maxf(float(f[3]) - float(f[2]), 0.05)
		for j in range(4):
			if i >= CARDS:
				break
			var u := clampf((now - float(f[2]) - j * 0.035) / span, 0.0, 1.0)
			var p: Vector3 = (f[0] as Vector3).lerp(f[1], u) + Vector3.UP * ARC_H * 4.0 * u * (1.0 - u)
			_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * (3.2 - j * 0.6)), p))
			_mm.set_instance_color(i, Color(1.0, 0.62, 0.25, 1.0 - j * 0.25))
			_mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
			i += 1
	_mm.visible_instance_count = i
