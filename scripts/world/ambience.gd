extends Node
class_name Ambience
## The sound of where you are, mixed every frame for the local captain (each
## machine hears its own): the sea in layers (a deep slow swell bed, the open
## swell, water lapping close by, breakers on a far shore), the shore by how far
## the actual coastline is and what it is (surf on a beach, waves crashing on
## rock, slapping at a quay), and aboard the ship the water along her hull, waves
## slapping her at rest, her timbers creaking and the hiss of her spray; the wind
## in gusts (with the weather, stronger at sea, under way and up the mast,
## quieter inland) and the rigging whistling in it. Under water everything is
## muffled (a low-pass on the SFX and Ambience buses) under a rumble of its own.
##
## The hull under way is three loops of different lengths (rush 37 s, gurgle
## 23 s, foam 29 s) started at random points, so together they never line up
## the same way twice: the rush grows with speed, the gurgle is most of the
## sound slow, the foam comes in near full speed. Each drifts slowly in level
## and pitch, and they surge when the bow drops into a swell (the slaps and the
## spray one-shots are the ship's, with its spray: ShipSpray).
##
## Where the shore is: CoastProbe, a bearing every PROBE_EVERY s. The waves breaking on it in
## time with the swell are SeaSpray's (it reads `coast`).
##
## A themed island has its own bed (KitStyle "ambience": the jungle's insects and
## birds), strongest ashore and fading out to sea with the island's style. The
## birds in the sky (SkyBirds) are made here too.

const LOOPS := {
	"shore": "shore_surf_loop", "rock": "rock_surf_loop", "far": "far_breakers_loop", "lap": "sea_lap_loop",
	"sea": "sea_swell_loop", "deep": "sea_deep_loop", "wash": "hull_rush_loop", "gurgle": "hull_gurgle_loop",
	"foam": "hull_foam_loop", "slap": "hull_slap_loop", "creak": "ship_creak_loop", "spray": "spray_hiss_loop",
	"wind": "wind_loop", "rig": "rigging_wind_loop", "under": "underwater_loop", "jungle": "jungle_loop",
	"snow": "snow_loop",
	"desert": "desert_loop",
	"forest": "forest_loop",
}
## Each loop's level at full strength (the loops are all made about as loud as each other).
const TOP_DB := {"shore": -8.5, "rock": -9.0, "far": -11.0, "lap": -13.0, "sea": -11.0, "deep": -9.0, "wash": -9.0,
	"gurgle": -13.0, "foam": -17.0, "slap": -16.0, "creak": -15.0, "spray": -15.0, "wind": -12.5, "rig": -12.5,
	"under": -7.0, "jungle": -13.0,
	"snow": -13.5,
	"desert": -13.0,
	"forest": -13.0}
const ZONE_EVERY := 0.5
## CoastProbe's next bearing every PROBE_EVERY s (a sweep of all 16 in ~1.1 s).
const PROBE_EVERY := 0.07
## Under water: the buses' low-pass closes to this.
const UNDER_HZ := 480.0

var coast := CoastProbe.new()
var _players := {}
var _land_near := 0.0
var _land_far := 0.0
## [style, weight] round you (KitStyle.around)
var _zone: Array = ["brinehollow", 0.0]
var _bed := ""
var _zone_t := 0.0
var _probe_t := 0.0
var _bow_y := INF
var _surge := 0.0
## Game seconds, for the hull loops' slow drift.
var _clock := 0.0
## The wind's gusts (0..1 now): with the weather, more and stronger in a blow.
var gust := 0.0
var _gust_peak := 0.0
var _gust_up := false
var _gust_t := 4.0
var _gust_snd: AudioStreamPlayer
## How far under water the ears are (0 .. 1).
var under := 0.0
var _lowpass: Array = []


func _ready() -> void:
	for k in LOOPS:
		_players[k] = _loop_player("res://assets/audio/%s.wav" % LOOPS[k])
	_gust_snd = AudioStreamPlayer.new()
	var r := AudioStreamRandomizer.new()
	r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	r.random_pitch = 1.08
	for i in range(3):
		r.add_stream(-1, load("res://assets/audio/wind_gust_%d.wav" % (i + 1)))
	_gust_snd.stream = r
	_gust_snd.bus = _bus()
	add_child(_gust_snd)
	for bus in ["SFX", "Ambience"]:
		var b := AudioServer.get_bus_index(bus)
		if b < 0:
			continue
		var fx: AudioEffectLowPassFilter = null
		for e in range(AudioServer.get_bus_effect_count(b)):
			if AudioServer.get_bus_effect(b, e).resource_name == "underwater":
				fx = AudioServer.get_bus_effect(b, e)
				AudioServer.set_bus_effect_enabled(b, e, false)
		if fx == null:
			fx = AudioEffectLowPassFilter.new()
			fx.resource_name = "underwater"
			fx.db = AudioEffectFilter.FILTER_12DB
			AudioServer.add_bus_effect(b, fx)
			AudioServer.set_bus_effect_enabled(b, AudioServer.get_bus_effect_count(b) - 1, false)
		_lowpass.append([b, fx])
	var birds := SkyBirds.new()
	birds.name = "SkyBirds"
	add_child(birds)


func _exit_tree() -> void:
	_set_under(0.0)


func _bus() -> String:
	return "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"


func _loop_player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	# (in frames: the imported data is QOA-compressed, so its byte count says nothing)
	s.loop_end = int(round(s.get_length() * s.mix_rate))
	p.stream = s
	p.bus = _bus()
	p.volume_db = -60.0
	add_child(p)
	return p


func _process(delta: float) -> void:
	_clock += delta
	var me := get_tree().get_first_node_in_group("player") as Node3D
	var want := {}
	for k in LOOPS:
		want[k] = 0.0
	if me != null and me.is_inside_tree():
		_probe_t -= delta
		if _probe_t <= 0.0:
			_probe_t = PROBE_EVERY
			var ship := get_tree().get_first_node_in_group("ship") as CollisionObject3D
			coast.tick(me.get_world_3d().direct_space_state, me.global_position, [ship.get_rid()] if ship else [])
			_land_near = coast.land_near()
			_land_far = coast.land_far()
		_zone_t -= delta
		if _zone_t <= 0.0:
			_zone_t = ZONE_EVERY
			_zone = KitStyle.around(get_tree(), me.global_position)
			_bed = KitStyle.of(_zone[0])["ambience"]
		_mix(me, want, delta)
		_underwater(me, want, delta)
	for k in want:
		_level(k, want[k], delta)


## 1 within `full` m, nothing past `gone`.
func _near(d: float, full: float, gone: float) -> float:
	return pow(clampf(1.0 - (d - full) / (gone - full), 0.0, 1.0), 1.5)


func _mix(me: Node3D, want: Dictionary, delta: float) -> void:
	var wx := get_node_or_null("/root/Weather")
	var wind: float = float(wx.get("wind")) if wx else 0.3
	var storm: float = float(wx.get("storm")) if wx else 0.0
	var cloud: float = float(wx.get("in_cloud")) if wx else 0.0
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	var aboard: bool = ship != null and ship.call("aboard", me.global_position)
	var spd: float = absf(float(ship.get("speed"))) if aboard else 0.0
	var at := me.global_position
	var inland := _land_near * _land_far
	var at_sea := (1.0 - _land_near) * (1.0 - _land_far)
	var rough := clampf(float(Ocean.get("amp_mult")) * 0.6 + storm * 0.4, 0.5, 1.4)
	var beach: float = coast.nearest("beach", at)[0]
	var rock: float = coast.nearest("rock", at)[0]
	var wall: float = coast.nearest("wall", at)[0]
	var shore := minf(beach, rock)
	var swimming: bool = me.call("is_swimming")
	var wading: bool = not swimming and float(me.call("water_depth")) > 0.15
	want["shore"] = _near(beach, 6.0, 90.0) * (0.75 + 0.35 * rough)
	want["rock"] = _near(rock, 6.0, 110.0) * (0.7 + 0.4 * rough)
	want["far"] = smoothstep(25.0, 60.0, shore) * (1.0 - smoothstep(130.0, 185.0, shore)) * (0.6 + 0.5 * storm) if shore < INF else 0.0
	want["lap"] = clampf(maxf(maxf(0.85 if swimming else 0.0, 0.6 if wading else 0.0),
		maxf(_near(wall, 2.0, 30.0) * 0.8, 0.55 if coast.over_water and at.y < 4.0 and not aboard else 0.0)), 0.0, 1.0)
	want["sea"] = clampf(at_sea + (0.5 if aboard else 0.0) + (0.4 if swimming else 0.0), 0.0, 1.0) * (0.6 + 0.4 * minf(storm + wind, 1.0))
	want["deep"] = clampf(at_sea * 0.9 + (0.35 if aboard else 0.0) + (0.3 if swimming else 0.0), 0.0, 1.0) * (0.55 + 0.45 * minf(storm + wind * 0.5, 1.0))
	if aboard:
		_hull(ship, spd, want, delta)
		want["slap"] = clampf(1.0 - spd / 4.0, 0.0, 1.0) * 0.8
		want["creak"] = clampf(0.45 + spd / 20.0 + storm * 0.4, 0.0, 1.0)
		var sp := ship.get_node_or_null("ShipSpray")
		want["spray"] = clampf((float(sp.get("spray")) if sp else 0.0) + float(wx.call("whitecaps") if wx else 0.0) * 0.2, 0.0, 1.0)
	else:
		_bow_y = INF
	_gusts(wind, storm, inland, delta)
	# the wind: always a breath at sea, more with the weather, under way and up high, in gusts
	var high := clampf((at.y - 2.0) / 14.0, 0.0, 1.0)
	want["wind"] = clampf((0.12 + wind * 0.55 + storm * 0.45 + high * 0.35 + spd / 30.0 + cloud * 0.5) * (1.0 - 0.55 * inland) * (0.8 + 0.5 * gust), 0.0, 1.0)
	if aboard:
		want["rig"] = clampf((wind - 0.25) * 1.4 + storm * 0.6 + spd / 22.0 + high * 0.5 + gust * 0.35, 0.0, 1.0)
	(_players["wind"] as AudioStreamPlayer).pitch_scale = lerpf(0.9, 1.15, clampf(wind + storm * 0.5, 0.0, 1.0)) * (1.0 + 0.02 * _drift(5) + 0.07 * gust)
	if _bed != "":
		var night: float = float(wx.get("night")) if wx else 0.0
		want[_bed] = clampf(float(_zone[1]) * (0.3 + 0.7 * _land_near) * (1.0 - 0.6 * storm) * (0.85 + 0.3 * night), 0.0, 1.0)


## Gusts come and go at random, more often and stronger the harder it blows; a
## big one is heard sweeping past.
func _gusts(wind: float, storm: float, inland: float, delta: float) -> void:
	var blow := clampf(wind * 1.1 + storm * 0.8 - 0.15, 0.0, 1.0)
	# (a calm's long wait doesn't hold back a gale's gusts)
	_gust_t = minf(_gust_t - delta, 16.0 * (1.4 - blow))
	if _gust_t <= 0.0:
		_gust_t = randf_range(5.0, 16.0) * (1.4 - blow)
		_gust_peak = randf_range(0.45, 1.0) * blow
		_gust_up = true
		if _gust_peak > 0.35:
			_gust_snd.volume_db = -16.0 + 10.0 * _gust_peak - 8.0 * inland
			_gust_snd.play()
	if _gust_up:
		gust = move_toward(gust, _gust_peak, delta / 1.4)
		_gust_up = gust < _gust_peak
	else:
		gust = move_toward(gust, 0.0, delta / 2.8)


## The camera or the captain's head under the surface: everything muffled.
func _underwater(me: Node3D, want: Dictionary, delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var wet := cam != null and cam.global_position.y < float(Ocean.surface_at(cam.global_position)) - 0.05
	var bm = me.get("body_model")
	if bm != null and me.has_method("water_surface"):
		wet = wet or ((bm as Humanoid).head.global_position.y < float(me.call("water_surface")) - 0.05)
	_set_under(move_toward(under, 1.0 if wet else 0.0, delta * (5.0 if wet else 2.5)))
	want["under"] = under


func _set_under(k: float) -> void:
	if k == under:
		return
	under = k
	for e in _lowpass:
		var b: int = e[0]
		var fx: AudioEffectLowPassFilter = e[1]
		fx.cutoff_hz = 20000.0 * pow(UNDER_HZ / 20000.0, k)
		for i in range(AudioServer.get_bus_effect_count(b)):
			if AudioServer.get_bus_effect(b, i) == fx:
				AudioServer.set_bus_effect_enabled(b, i, k > 0.001)


## The water along the hull: rush, gurgle and foam by speed, each drifting on
## its own, all surging as the bow drops into a swell.
func _hull(ship: Node3D, spd: float, want: Dictionary, delta: float) -> void:
	var v := clampf(spd / 11.0, 0.0, 1.0)
	var bow_y := (ship.global_transform * Vector3(0.0, 0.0, HullBuilder.BOW_Z)).y
	var bow_vy := 0.0 if _bow_y == INF else (bow_y - _bow_y) / maxf(delta, 0.0001)
	_bow_y = bow_y
	var dive := clampf(-bow_vy / 2.5, 0.0, 1.0) * v
	_surge = move_toward(_surge, dive, delta * (6.0 if dive > _surge else 0.8))
	want["wash"] = pow(clampf(spd / 8.0, 0.0, 1.0), 0.7) * (1.0 + 0.15 * _drift(0)) * (1.0 + 0.4 * _surge)
	want["gurgle"] = clampf(spd / 3.0, 0.0, 1.0) * (1.0 - 0.35 * v) * (1.0 + 0.25 * _drift(1))
	want["foam"] = pow(clampf((spd - 4.0) / 6.0, 0.0, 1.0), 1.5) * (1.0 + 0.2 * _drift(2)) * (1.0 + 0.7 * _surge)
	(_players["wash"] as AudioStreamPlayer).pitch_scale = (0.88 + 0.2 * v + 0.04 * _surge) * (1.0 + 0.02 * _drift(3))
	(_players["gurgle"] as AudioStreamPlayer).pitch_scale = (0.92 + 0.18 * v) * (1.0 + 0.03 * _drift(4))
	(_players["foam"] as AudioStreamPlayer).pitch_scale = (0.95 + 0.1 * v) * (1.0 + 0.02 * _drift(6))


## A slow wander, -1..1, different for each k (sines that never line up).
func _drift(k: int) -> float:
	var t := _clock
	return sin(t * 0.13 + k * 1.7) * 0.5 + sin(t * 0.071 + k * 2.9) * 0.3 + sin(t * 0.037 + k * 0.6) * 0.2


func _level(k: String, v: float, delta: float) -> void:
	var p := _players[k] as AudioStreamPlayer
	var to := -60.0 if v < 0.02 else linear_to_db(v) + float(TOP_DB[k])
	p.volume_db = move_toward(p.volume_db, to, 24.0 * delta)
	if p.volume_db > -55.0 and not p.playing:
		# (from anywhere in the loop: it never comes back in at the same place)
		p.play(randf() * p.stream.get_length())
	elif p.volume_db <= -59.0 and p.playing:
		p.stop()
