class_name ScouringFX
extends Node3D
## (1.30, the Scouring's look: docs/v1_30_plan.md) What every screen sees and hears of the shelling, worked out locally
## from StrongholdScouring's shells and its clock (the same on every machine, so nothing goes over the net):
## - the smoke: Weather.smoke up to 1 over SMOKE_IN s once the shells fall (a dark grey sky even at noon, so the fire
##   pops), fading with our captain's distance past the ring, and clearing over SMOKE_OUT s once the crew's out;
## - the ring of warships (SHIPS Admiralty hulls SHIP_R out, a gap toward GAP): each shell fired from one (its muzzle
##   flash and smoke), a full broadside every BROADSIDE s whose shot raises columns of water off the coast;
## - each shell: a high arc for the warning's length, its shadow darkening on the ground under it, its whistle WHISTLE s
##   before it lands, then a huge burst (a white-hot flash, fireballs several captains tall, stone and tiles thrown, a
##   shock ring, a light, a dark column of smoke that lingers; a column of white water on the sea), heard far off; near
##   the camera heavy shake and an orange flash, both by distance;
## - the blazes (StrongholdScouring decides where): fires many times a captain's height on roofs, walls and yards,
##   burning on, each sending up smoke, the nearest NEAR_LIGHTS of them lighting their walls;
## - sirens from the broadcast, war drums under the barrage.
## Drawn as MultiMeshes on the GPU: the cards (glows, smoke) move themselves from a clock (scouring_glow.gdshader,
## written once when spawned), the blazes burn in scouring_fire.gdshader; only the shells in flight and their shadows
## are written each frame. FX bursts add the close detail (they stop at FX.BURST_RANGE).

const SMOKE_IN := 7.0
const SMOKE_OUT := 18.0
const WHISTLE := 1.8
const ARC_H := 70.0
## Near the camera: shake to this far, the orange flash to this far.
const SHAKE_R := 70.0
const FLASH_R := 36.0
const CARDS := 768
const LIVE := 160
const GLOW := Color(1.0, 0.5, 0.16)
const HOT := Color(1.0, 0.86, 0.55)
const SMOKE_COL := Color(0.14, 0.12, 0.11)
const BANK := Color(0.62, 0.6, 0.58)
## The blazes: at most MAX_BLAZES, three cards each ([height, width, offset] x the blaze's size), a smoke puff from each
## every BLAZE_SMOKE s, the nearest NEAR_LIGHTS lit.
const MAX_BLAZES := 26
const BLAZE_CARDS := [[1.0, 0.55, 0.0], [0.62, 0.42, 0.32], [0.7, 0.38, -0.36]]
const BLAZE_SMOKE := 1.1
const NEAR_LIGHTS := 3
## The ring: SHIPS warships SHIP_R from the island's middle (StrongholdScouring.GAP's way left open, GAP_HALF rad either
## side), a broadside every BROADSIDE s.
const SHIPS := 11
const SHIP_R := 245.0
const SHIP_SCALE := 2.2
const GAP_HALF := 0.36
const BROADSIDE := 2.6
const GUNS := 6

const GLOW_SHADER := preload("res://shaders/psx/scouring_glow.gdshader")
const FIRE_SHADER := preload("res://shaders/psx/scouring_fire.gdshader")

var sc: StrongholdScouring
var level := 0.0
## [from, to, fired (clock), lands (clock), shadow (bool)] in flight; [at, when] whistles to come; [at, when] the
## broadsides' shot falling in the sea.
var flights: Array = []
var _whistles: Array = []
var _splashes: Array = []
## The blazes: [where, size, caught (clock), next smoke (clock)].
var blazes: Array = []
## The ring's ships: [node, broadside side (world, toward the island), its rest transform].
var ships: Array = []
var _broadside := -1
var _t := 0.0
var _card_i := 0
var _cards_mm: MultiMesh
var _live_mm: MultiMesh
var _fire_mm: MultiMesh
var _cards_mat: ShaderMaterial
var _fire_mat: ShaderMaterial
var _lights: Array = []
var _light_t := 0.0
var _siren: AudioStreamPlayer
var _drums: AudioStreamPlayer


func setup(scouring: StrongholdScouring) -> ScouringFX:
	sc = scouring
	name = "ScouringFX"
	return self


func _ready() -> void:
	# (everything here is written in world space: this node stays at the origin, unturned)
	top_level = true
	global_transform = Transform3D.IDENTITY
	_cards_mat = _mat(GLOW_SHADER)
	_cards_mat.set_shader_parameter("driven", true)
	_cards_mm = _multimesh("Cards", CARDS, _cards_mat)
	_cards_mm.visible_instance_count = CARDS
	for i in range(CARDS):
		_cards_mm.set_instance_transform(i, Transform3D(Basis(Vector3.ZERO, Vector3(-1000.0, 0.01, 0.0), Vector3.ZERO), Vector3.ZERO))
	_live_mm = _multimesh("Shells", LIVE, _mat(GLOW_SHADER))
	_fire_mat = _mat(FIRE_SHADER)
	_fire_mm = _multimesh("Blazes", MAX_BLAZES * BLAZE_CARDS.size(), _fire_mat)
	for i in range(NEAR_LIGHTS):
		var l := OmniLight3D.new()
		l.shadow_enabled = false
		l.light_color = Color(1.0, 0.5, 0.2)
		l.omni_range = 26.0
		l.visible = false
		add_child(l)
		_lights.append(l)
	_siren = _loop("res://assets/audio/siren_loop.wav")
	_drums = _loop("res://assets/audio/war_drums_loop.wav")


func _mat(sh: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _multimesh(n: String, count: int, mat: ShaderMaterial) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	mm.mesh = quad
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (world space, wherever the chain put the stronghold)
	mmi.custom_aabb = AABB(Vector3(-60000, -200, -60000), Vector3(120000, 1200, 120000))
	add_child(mmi)
	return mm


func _loop(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s: AudioStreamWAV = (load(path) as AudioStreamWAV).duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	p.stream = s
	p.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
	p.volume_db = -80.0
	add_child(p)
	return p


func _exit_tree() -> void:
	get_node("/root/Weather").smoke = 0.0


func _clock() -> float:
	return float(get_node("/root/Ocean").clock())


func _process(delta: float) -> void:
	_t += delta
	var now := _clock()
	var k := _near()
	_smoke(delta, k)
	_sound(delta, k)
	if ships.is_empty() and sc.state in ["count", "barrage"]:
		_build_ring()
	if sc.state == "barrage":
		_broadsides(now)
	if _whistles.any(func(w): return float(w[1]) <= now):
		for w in _whistles.filter(func(w): return float(w[1]) <= now):
			FX.far_sfx("shell_whistle", w[0] + Vector3.UP * 12.0, 2.0, 140.0)
		_whistles = _whistles.filter(func(w): return float(w[1]) > now)
	if _splashes.any(func(w): return float(w[1]) <= now):
		for w in _splashes.filter(func(w): return float(w[1]) <= now):
			_splash(w[0], 0.7)
		_splashes = _splashes.filter(func(w): return float(w[1]) > now)
	flights = flights.filter(func(f): return float(f[3]) > now)
	_blazes(now, delta)
	_cards_mat.set_shader_parameter("now", _t)
	_cards_mat.set_shader_parameter("under", float(get_node("/root/Weather").night) * level)
	_fire_mat.set_shader_parameter("now", now)
	_bob(now)
	_draw_live(now)


## 1 near the island, fading to 0 from just past the ring out to RING_R + 420 m (our captain, or the camera).
func _near() -> float:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me == null:
		return 1.0
	var c: Vector3 = sc.isl.city_global(StrongholdPlan.LAND_C, 0.0)
	var d := Vector2(me.global_position.x - c.x, me.global_position.z - c.z).length()
	return 1.0 - smoothstep(sc.RING_R + 60.0, sc.RING_R + 420.0, d)


## The sky: thick while the shells fall, clearing once out.
func _smoke(delta: float, k: float) -> void:
	var want := 1.0 if sc.state == "barrage" else 0.0
	level = move_toward(level, want, delta / (SMOKE_IN if want > level else SMOKE_OUT))
	get_node("/root/Weather").smoke = level * k


## The sirens from the broadcast (louder while the countdown runs), the drums under the barrage; both fade once out.
func _sound(delta: float, k: float) -> void:
	var on := sc.state in ["grace", "count", "barrage"]
	var siren := (1.0 if sc.state == "count" else 0.55) if on else 0.0
	var drums := 1.0 if sc.state == "barrage" else 0.0
	_fade(_siren, siren * k, -4.0, delta)
	_fade(_drums, drums * k, -3.0, delta)


func _fade(p: AudioStreamPlayer, want: float, top_db: float, delta: float) -> void:
	var cur := db_to_linear(p.volume_db) if p.playing else 0.0
	var g := move_toward(cur, want * db_to_linear(top_db), delta * 0.25)
	if g <= 0.001:
		if p.playing:
			p.stop()
		return
	if not p.playing:
		p.play()
	p.volume_db = linear_to_db(g)


# --------------------------------------------------------------------------
# The ring of warships
# --------------------------------------------------------------------------
## The warships, side-on to the island round it, the gap toward GAP left open (one hull built, the rest copies of it).
func _build_ring() -> void:
	var c: Vector3 = sc.isl.city_global(StrongholdPlan.LAND_C, 0.0)
	var gap := gap_dir()
	var proto: Node3D = null
	for i in range(SHIPS):
		var a := atan2(gap.z, gap.x) + GAP_HALF + (TAU - GAP_HALF * 2.0) * (i + 0.5) / SHIPS
		var out := Vector3(cos(a), 0.0, sin(a))
		var at := c + out * SHIP_R + Vector3.UP * 1.2
		var ship: Node3D
		if proto == null:
			ship = Node3D.new()
			HullBuilder.build(ship, EnemyShip.KINDS["warship"]["look"])
			proto = ship
		else:
			ship = proto.duplicate()
		ship.name = "RingShip%d" % i
		add_child(ship)
		# (bow along the ring, its side to the island)
		var fwd := out.cross(Vector3.UP)
		var xf := Transform3D(Basis.looking_at(fwd, Vector3.UP).scaled(Vector3.ONE * SHIP_SCALE), at)
		ship.global_transform = xf
		for mi in ship.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(mi as MeshInstance3D).visibility_range_end = 1400.0
		ships.append([ship, -out, xf])


## The way out: from the island's middle toward the gap (world, flat).
func gap_dir() -> Vector3:
	var c: Vector3 = sc.isl.city_global(StrongholdPlan.LAND_C, 0.0)
	return (StrongholdScouring.gap_at(sc.isl) - c).normalized()


## The ships ride the swell (a slow heave and roll).
func _bob(now: float) -> void:
	for i in range(ships.size()):
		var e: Array = ships[i]
		var xf: Transform3D = e[2]
		var ph := now * 0.55 + i * 1.7
		(e[0] as Node3D).global_transform = Transform3D(xf.basis * Basis(Vector3.BACK, sin(ph) * 0.04), xf.origin + Vector3.UP * sin(ph * 0.8) * 0.6)


## A gun port on ship i: gun j of GUNS along its side toward the island.
func _gun(i: int, j: int) -> Vector3:
	var e: Array = ships[i]
	var xf: Transform3D = e[2]
	var side: Vector3 = e[1]
	var along := xf.basis.z.normalized()
	return xf.origin + side * 4.6 * SHIP_SCALE * 0.5 + along * (j - (GUNS - 1) * 0.5) * 2.2 * SHIP_SCALE + Vector3.UP * 2.2


## A gun going off: the flash, a bank of smoke rolling out from the side, the boom.
func _muzzle(at: Vector3, side: Vector3, born: float, loud: bool) -> void:
	_card(at + side * 2.0, born, 0.3, 9.0, 16.0, HOT, 0.0, 0.0)
	_card(at + side * 6.0, born, 5.5, 8.0, 22.0, BANK, 1.0, 1.0)
	if loud:
		FX.far_sfx("cannon", at, 8.0, 900.0)


## Every BROADSIDE s (from the barrage's clock, the same on every screen): a ship fires all its guns in a ripple, its
## shot falling in the sea off the island's coast.
func _broadsides(now: float) -> void:
	if ships.is_empty():
		return
	var b := int(floor(now / BROADSIDE))
	if b == _broadside:
		return
	_broadside = b
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["broadside", int(sc.isl.node["seed"]), b])
	var i := rng.randi() % ships.size()
	var side: Vector3 = ships[i][1]
	var c: Vector3 = sc.isl.city_global(StrongholdPlan.LAND_C, 0.0)
	for j in range(GUNS):
		var at := _gun(i, j)
		_muzzle(at, side, _t + j * 0.09, j % 3 == 0)
		if j % 2 == 0:
			var to := at.lerp(c, rng.randf_range(0.3, 0.55)) + Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20))
			to.y = 0.0
			var lands := now + 1.4 + rng.randf() * 0.5
			flights.append([at, to, now + j * 0.09, lands, false])
			_splashes.append([to, lands])


# --------------------------------------------------------------------------
# The shells
# --------------------------------------------------------------------------
## A shell fired at `at`, landing at clock `lands`: from a ring ship (or the ring before they're up), its flight, its
## shadow, its whistle.
func incoming(at: Vector3, lands: float, k: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["fired", k])
	var now := _clock()
	var from: Vector3
	if ships.is_empty():
		var c: Vector3 = sc.isl.city_global(StrongholdPlan.LAND_C, 0.0)
		from = c + Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU) * SHIP_R + Vector3.UP * 8.0
		_card(from, _t, 0.35, 10.0, 16.0, HOT, 0.0, 0.0)
	else:
		var i := rng.randi() % ships.size()
		from = _gun(i, rng.randi() % GUNS)
		_muzzle(from, ships[i][1], _t, rng.randf() < 0.35)
	flights.append([from, at, now, lands, true])
	_whistles.append([at, lands - WHISTLE])


## The broadsides' shot into the sea: a column of white water.
func _splash(at: Vector3, k: float) -> void:
	FX.plume(at, Vector3.UP, "splash", 6, 4.0 * k + 1.0, 1.6, Color(0.92, 0.96, 1.0, 0.95), 15.0 * k, 8.0)
	FX.water_ring(at, 6.0 * k, 1.5)
	_card(at + Vector3.UP * 4.0, _t, 1.8, 5.0 * k, 11.0 * k, Color(0.8, 0.85, 0.9, 0.55), 1.0, 2.0)
	FX.far_sfx("shell_far", at, -2.0, 600.0)


## A shell bursting at `at` (normal `n`; `water`: in the sea; `blaze`: it sets a great fire burning there).
func landed(at: Vector3, n: Vector3, water: bool, blaze := false) -> void:
	if water:
		_splash(at, 1.3)
		FX.puff(at + Vector3.UP * 3.0, "mist", 3, 6.0, 2.4, Color(0.9, 0.95, 1.0, 0.7), 2.0)
		FX.far_sfx("cannon_hit", at, 4.0, 160.0)
		_juice(at, 0.6)
		return
	var up := (n + Vector3.UP).normalized()
	# (right on top of the camera the fireball is cut down a little: the captain stays readable through it)
	var cam := get_viewport().get_camera_3d()
	var z := lerpf(0.55, 1.0, clampf(cam.global_position.distance_to(at) / 30.0, 0.0, 1.0)) if cam else 1.0
	# the white-hot flash, then fireballs several captains tall rolling up out of it
	_card(at + n * 2.0, _t, 0.15, 20.0 * z, 30.0 * z, Color(1.0, 0.95, 0.8), 0.0, 0.0)
	_card(at + n * 4.0, _t, 0.6, 16.0 * z, 28.0 * z, GLOW, 0.0, 4.0)
	_card(at + Vector3.UP * 7.0, _t + 0.08, 1.4, 12.0 * z, 24.0 * z, Color(1.0, 0.42, 0.12, 0.95), 0.0, 9.0)
	FX.flipbook(at + n * 2.0, "explosion", 3, 13.0 * z, 0.9, {"radius": 2.0, "direction": up, "spread": 40.0, "vel_min": 2.0,
		"vel_max": 6.0, "gravity": Vector3.ZERO, "damping": 3.0, "start": 0.02, "spin": 180.0, "fade": 0.75, "lit": false})
	FX.blast(at + n * 0.5, n, 6.0 * z, true, Color(0.05, 0.042, 0.038, 0.95), 3.0)
	FX.plume(at + Vector3.UP, up, "fireball", 8, 7.0 * z, 1.3, Color.WHITE, 20.0, 35.0)
	# stone and roof tiles thrown off what it hit, a shock ring along the ground, embers
	FX.debris(at + n * 0.5, up, 28, Color(0.36, 0.34, 0.33), 18.0)
	FX.debris(at + n * 0.5, up, 14, Color(0.2, 0.17, 0.17), 13.0)
	FX.puff_ring(at, "dust_low", 9, 1.5, 6.0, 1.8, Color(0.22, 0.19, 0.17), 18.0)
	FX.embers(at + Vector3.UP, Vector3.UP, 22, Color(1.0, 0.45, 0.12), 13.0)
	FX.ring(at, Vector3.UP, 15.0, Color(1.0, 0.62, 0.3), 0.5, 0.4)
	FX.flash_light(at + n * 4.0, FX.FIRE_LIGHT, 22.0, 42.0, 0.9)
	# (the dark column it leaves, rolling up for a while)
	for j in range(4):
		_card(at + Vector3.UP * (6.0 + j * 3.0), _t + 0.3 + j * 0.7, 14.0, 9.0, 36.0, SMOKE_COL, 1.0, 4.5)
	FX.far_sfx("shell_boom", at, 7.0, 180.0)
	FX.far_sfx("shell_far", at, 4.0, 800.0)
	_juice(at, 1.0)
	if blaze and blazes.size() < MAX_BLAZES:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([at.round()])
		blazes.append([at, rng.randf_range(0.8, 1.25), _clock(), 0.0])


## This screen's shake and orange flash, by the camera's distance.
func _juice(at: Vector3, k: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := cam.global_position.distance_to(at)
	var s := pow(clampf(1.0 - d / SHAKE_R, 0.0, 1.0), 1.5)
	if s > 0.01:
		CombatManager.apply_camera_shake(0.42 * s * k, 0.4)
	if d < FLASH_R:
		FX.screen_flash(at, Color(1.0, 0.56, 0.2, 0.45 * (1.0 - d / FLASH_R) * k), 0.4)


# --------------------------------------------------------------------------
# The blazes
# --------------------------------------------------------------------------
## Their cards (written when one catches), their smoke, and the nearest ones' lights flickering.
func _blazes(now: float, delta: float) -> void:
	var n := blazes.size() * BLAZE_CARDS.size()
	if _fire_mm.visible_instance_count != n:
		for b in range(blazes.size()):
			var e: Array = blazes[b]
			for j in range(BLAZE_CARDS.size()):
				var cd: Array = BLAZE_CARDS[j]
				var s: float = e[1]
				var at: Vector3 = e[0]
				var off := Vector3(cos(b * 2.3 + j), 0.0, sin(b * 2.3 + j)) * float(cd[2]) * 6.0 * s
				var data := Basis(Vector3(15.0 * s * float(cd[0]), 11.0 * s * float(cd[1]), float(b * 3 + j) * 0.37), Vector3(float(e[2]) + j * 0.4, 0, 0), Vector3.ZERO)
				_fire_mm.set_instance_transform(b * BLAZE_CARDS.size() + j, Transform3D(data, at + off))
		_fire_mm.visible_instance_count = n
	for e in blazes:
		if now >= float(e[3]):
			e[3] = now + BLAZE_SMOKE
			_card(e[0] + Vector3.UP * 12.0 * float(e[1]), _t, 13.0, 7.0, 30.0, SMOKE_COL, 1.0, 5.0)
	_light_t -= delta
	if _light_t <= 0.0:
		_light_t = 0.3
		var cam := get_viewport().get_camera_3d()
		var near := blazes.duplicate()
		if cam:
			near.sort_custom(func(a, b): return (a[0] as Vector3).distance_squared_to(cam.global_position) < (b[0] as Vector3).distance_squared_to(cam.global_position))
		for i in range(_lights.size()):
			var l: OmniLight3D = _lights[i]
			l.visible = i < near.size() and cam != null and (near[i][0] as Vector3).distance_to(cam.global_position) < 120.0
			if l.visible:
				l.global_position = near[i][0] + Vector3.UP * 5.0
	for i in range(_lights.size()):
		var l: OmniLight3D = _lights[i]
		if l.visible:
			l.light_energy = 3.2 + 0.9 * sin(_t * 13.0 + i * 2.0) + 0.6 * sin(_t * 7.3 + i)


# --------------------------------------------------------------------------
# The cards
# --------------------------------------------------------------------------
## A card from `born` (this screen's clock, _t) for `life` s: `p`, from size s0 to s1, rising `rise` m/s; smoke 1
## (blended), else a glow (added). Written once; the shader moves and fades it.
func _card(p: Vector3, born: float, life: float, s0: float, s1: float, col: Color, smoke: float, rise: float) -> void:
	var i := _card_i
	_card_i = (_card_i + 1) % CARDS
	_cards_mm.set_instance_transform(i, Transform3D(Basis(Vector3(s0, s1, rise), Vector3(born, life, 0.0), Vector3.ZERO), p))
	_cards_mm.set_instance_color(i, col)
	_cards_mm.set_instance_custom_data(i, Color(smoke, randf(), 0, 0))


## The shells in flight (a bright head, a streak of six fading after it along the arc) and their shadows growing and
## darkening on the ground as they come.
func _draw_live(now: float) -> void:
	var i := 0
	var down := Basis(Vector3.RIGHT, -PI * 0.5)
	for f in flights:
		var span := maxf(float(f[3]) - float(f[2]), 0.05)
		var u0 := (now - float(f[2])) / span
		if u0 < 0.0:
			continue
		for j in range(7):
			if i >= LIVE - 1:
				break
			var u := clampf(u0 - j * 0.012, 0.0, 1.0)
			var p: Vector3 = (f[0] as Vector3).lerp(f[1], u) + Vector3.UP * ARC_H * 4.0 * u * (1.0 - u)
			_live_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * (3.4 - j * 0.4)), p))
			_live_mm.set_instance_color(i, Color(1.0, 0.62, 0.25, 1.0 - j * 0.13) if j > 0 else HOT)
			_live_mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
			i += 1
		if f[4] and i < LIVE:
			var r := lerpf(1.2, sc.SHELL_R * 0.6, u0)
			_live_mm.set_instance_transform(i, Transform3D(down * Basis.from_scale(Vector3(r * 2.0, r * 2.0, 1.0)), f[1] + Vector3.UP * 0.08))
			_live_mm.set_instance_color(i, Color(0, 0, 0, lerpf(0.12, 0.6, u0 * u0)))
			_live_mm.set_instance_custom_data(i, Color(2.0, float(i), 0, 0))
			i += 1
	_live_mm.visible_instance_count = i
