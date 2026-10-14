class_name ShipSpray
extends Node3D
## The ship's own white water: the bow wave curling off both sides of her stem
## and the churn astern, growing with her speed; a sheet of spray thrown up over
## the bow when she slams into a wave (with its sound), and in a blow a mist of it
## streaming aft and downwind across the deck. Every wave she meets at speed
## slaps her hull (a knock you hear). Each machine makes its own from the ship's
## synced motion and the sea, nothing is sent. One emitter per part (all in her
## own space: local_coords), asleep while the camera is far.

const SLEEP := 180.0
## The waterline in her own space (she rides FREEBOARD above the swell).
const WL := -HullBuilder.FREEBOARD + 0.1
## Where the bow wave leaves her sides, and where her stem cuts the water (her own space).
const BOW_WAVE_Z := -10.0
const STEM_Z := -12.3
## How fast the sea climbs her stem (m/s) for a slap you hear, and for a sheet of spray.
const SLAP_RISE := 1.3
const SHEET_RISE := 2.2

## How much spray is flying now (0..1): Ambience's hiss follows it.
var spray := 0.0
## Sheets thrown and slaps heard so far (tests).
var slams := 0
var slaps := 0
## How fast the sea climbed her stem last tick (m/s).
var rise := 0.0
var awake := true
var _ship: Node3D
var _bow: Array[CPUParticles3D] = []
var _stern: CPUParticles3D
var _mist: CPUParticles3D
var _sheets: Array[CPUParticles3D] = []
var _sheet_i := 0
var _imm := INF
var _slap_cd := 0.0
var _sheet_cd := 0.0
var _mist_k := 0.0


func _ready() -> void:
	_ship = get_parent()
	# everything starts at the waterline just outside her planking (never inboard,
	# never from the anchor at the cathead): the bow wave low and flat off each side
	# of the bow, the churn just aft of her transom, the sheet and mist at the stem
	for s in [-1.0, 1.0]:
		var e := _emitter(28, 0.9, 0.32, Color(0.93, 0.97, 1.0, 0.9), false)
		e.position = Vector3(s * (beam_at(BOW_WAVE_Z) + 0.25), WL, BOW_WAVE_Z)
		e.direction = Vector3(s, 0.45, -0.2).normalized()
		e.spread = 14.0
		e.emission_sphere_radius = 0.25
		_bow.append(e)
	_stern = _emitter(20, 1.1, 0.45, Color(0.92, 0.96, 1.0, 0.8), false)
	_stern.position = Vector3(0.0, WL, float(HullBuilder.RINGS[0][0]) + 0.5)
	_stern.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_stern.emission_box_extents = Vector3(beam_at(float(HullBuilder.RINGS[0][0])) * 0.7, 0.05, 0.3)
	_stern.direction = Vector3(0.0, 0.5, 1.0).normalized()
	_stern.spread = 30.0
	_mist = _emitter(24, 1.4, 0.55, Color(0.9, 0.95, 1.0, 0.2), false)
	_mist.position = Vector3(0.0, WL + 0.2, STEM_Z)
	_mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_mist.emission_box_extents = Vector3(0.4, 0.15, 0.3)
	_mist.direction = Vector3(0.0, 1.0, 0.25).normalized()
	_mist.spread = 25.0
	_mist.damping_min = 0.6
	_mist.damping_max = 0.6
	_mist.scale_amount_curve = FX._curve("grow")
	for i in range(2):
		var sh := _emitter(42, 1.1, 0.24, Color(0.94, 0.98, 1.0, 0.95), true)
		sh.position = Vector3(0.0, WL + 0.1, STEM_Z)
		sh.spread = 18.0
		sh.emission_sphere_radius = 0.25
		sh.scale_amount_curve = FX._curve("hold")
		_sheets.append(sh)


## Her half-width at the waterline `z` m along her (HullBuilder.RINGS), 0 past the stem.
static func beam_at(z: float) -> float:
	var r: Array = HullBuilder.RINGS
	for i in range(r.size() - 1):
		var a: Array = r[i]
		var b: Array = r[i + 1]
		if z <= float(a[0]) and z >= float(b[0]):
			var k := (float(a[0]) - z) / (float(a[0]) - float(b[0]))
			var top := lerpf(float(a[1]), float(b[1]), k)
			var bottom := lerpf(float(a[2]), float(b[2]), k)
			var top_y := lerpf(float(a[3]), float(b[3]), k)
			var bottom_y := lerpf(float(a[4]), float(b[4]), k)
			return maxf(lerpf(bottom, top, clampf((WL - bottom_y) / (top_y - bottom_y), 0.0, 1.0)), 0.0) if WL > bottom_y else 0.0
	return 0.0


func _emitter(amount: int, life: float, size: float, col: Color, burst: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = burst
	p.explosiveness = 0.85 if burst else 0.0
	p.randomness = 0.4
	p.local_coords = true
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.damping_min = 0.4
	p.damping_max = 0.8
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.scale_amount_curve = FX._curve("shrink")
	p.color_ramp = FX._fade_to_clear(col)
	p.mesh = FX._quad(size, FX._dust_mat)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _physics_process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	awake = cam == null or cam.global_position.distance_to(_ship.global_position) < SLEEP
	visible = awake
	if not awake:
		for e in _bow:
			e.emitting = false
		_stern.emitting = false
		_mist.emitting = false
		_imm = INF
		spray = 0.0
		return
	var spd := absf(float(_ship.get("speed")))
	var wx := get_node_or_null("/root/Weather")
	var wind: float = float(wx.get("wind")) if wx else 0.3
	var storm: float = float(wx.get("storm")) if wx else 0.0
	var caps: float = float(wx.call("whitecaps")) if wx else 0.0
	var w2: Vector2 = wx.call("wind_dir") if wx else Vector2(1, 0)
	var xf := _ship.global_transform
	# the wind over her deck (her own speed blows aft), in her own space
	var fwd := -xf.basis.z
	var air := Vector3(w2.x, 0.0, w2.y) * (wind * 6.0 + storm * 4.0) - Vector3(fwd.x, 0.0, fwd.z).normalized() * float(_ship.get("speed"))
	var air_l := xf.basis.orthonormalized().inverse() * air
	# under way: the bow wave and the churn astern, more and faster the faster she goes
	var way := clampf((spd - 1.5) / 7.0, 0.0, 1.0)
	for e in _bow:
		e.emitting = randf() < way
		# (a low curl: it never climbs to the cathead and its anchor)
		e.initial_velocity_min = 0.8 + spd * 0.2
		e.initial_velocity_max = 1.2 + spd * 0.3
		e.gravity = Vector3(0.0, -9.0, 0.0) + air_l * 0.25
	_stern.emitting = randf() < way * 0.8
	_stern.initial_velocity_min = 0.6 + spd * 0.1
	_stern.initial_velocity_max = 1.2 + spd * 0.2
	_meet(delta, xf, spd, caps, air_l)
	# in a blow at speed spray hangs in the air and streams aft across her deck
	var blow := clampf(caps * 1.2 - 0.1, 0.0, 1.0) * clampf((spd - 3.0) / 6.0, 0.0, 1.0)
	_mist_k = move_toward(_mist_k, blow * 0.5, delta * 0.6)
	_mist.emitting = randf() < _mist_k
	_mist.initial_velocity_min = 1.5
	_mist.initial_velocity_max = 3.0 + spd * 0.2
	_mist.gravity = Vector3(0.0, -0.5, 0.0) + air_l * 0.9
	for sh in _sheets:
		sh.gravity = Vector3(0.0, -11.0, 0.0) + air_l * 0.45
	spray = move_toward(spray, clampf(way * 0.3 + _mist_k * 0.9, 0.0, 1.0), delta * 2.0)


## The sea climbing her stem: each wave met at speed slaps the hull, a steep
## one throws a sheet of spray up over the bow.
func _meet(delta: float, xf: Transform3D, spd: float, caps: float, air_l: Vector3) -> void:
	_slap_cd -= delta
	_sheet_cd -= delta
	var stem := xf * Vector3(0.0, WL + 0.35, HullBuilder.BOW_Z + 0.8)
	var imm := float(Ocean.get_wave_height(stem)) - stem.y
	rise = 0.0 if _imm == INF else (imm - _imm) / maxf(delta, 0.0001)
	_imm = imm
	if spd < 2.0:
		return
	if rise > SLAP_RISE and _slap_cd <= 0.0:
		_slap_cd = 0.45
		slaps += 1
		var side := xf.basis.x * (2.0 if randf() < 0.5 else -2.0)
		FX.sfx("hull_wave", stem + side, -11.0 + 8.0 * clampf((rise - SLAP_RISE) / 2.5, 0.0, 1.0), 0.08)
	if rise > SHEET_RISE * (1.15 - 0.35 * caps) and spd > 3.5 and _sheet_cd <= 0.0:
		var k := clampf((rise - SHEET_RISE) / 2.5 + 0.35, 0.35, 1.0) * clampf(spd / 9.0, 0.4, 1.0)
		_sheet_cd = randf_range(0.7, 1.3)
		slams += 1
		var sh := _sheets[_sheet_i]
		_sheet_i = (_sheet_i + 1) % _sheets.size()
		sh.direction = (Vector3(randf_range(-0.15, 0.15), 1.0, -0.1) + air_l.normalized() * 0.2).normalized()
		sh.initial_velocity_min = 4.0 + 4.0 * k
		sh.initial_velocity_max = 6.0 + 6.0 * k
		sh.restart()
		_mist_k = maxf(_mist_k, 0.45 + 0.45 * k * clampf(caps + 0.4, 0.0, 1.0))
		FX.sfx("bow_spray", xf * Vector3(0.0, WL + 1.4, HullBuilder.BOW_Z), -9.0 + 7.0 * k + caps * 3.0, 0.1)
