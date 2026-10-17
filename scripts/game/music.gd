extends Node
## Background music (autoload "Music"). Picks a track from what's going on
## around your own captain (each machine plays its own) and crossfades to it:
##   title   - the title screen (the game's theme)
##   village - in a town's streets: Brinehollow's square and harbour front, a chain island's village
##   island  - on foot in the wilds (on a chain island: its KitStyle "music")
##   sea     - at the helm / a cannon, aboard under way, or out on the open sea
##   combat  - enemies fighting you (or a pirate ship hunting you) nearby
##   boss    - a boss fight close by
## plus a short victory fanfare (victory()) that ducks the music for a moment.
## The calm tracks have "<name>_night" variants, the same piece arranged sparser
## with the same bars, played from DUSK to DAWN: the change crossfades slowly at
## the same position. Calm changes wait for the playing track's next bar line and
## come in on one of the new track's; fights cut in at once.
## Volume: the "Music" bus (Options > Audio > Music).

## [file, bars in the loop] (the bars give each track's bar length).
const TRACKS := {
	"title": ["res://assets/audio/music_title.ogg", 56],
	"village": ["res://assets/audio/music_village.ogg", 52],
	"village_night": ["res://assets/audio/music_village_night.ogg", 52],
	"island": ["res://assets/audio/music_island.ogg", 64],
	"island_night": ["res://assets/audio/music_island_night.ogg", 64],
	"sea": ["res://assets/audio/music_sea.ogg", 80],
	"sea_night": ["res://assets/audio/music_sea_night.ogg", 80],
	"combat": ["res://assets/audio/music_combat.ogg", 32],
	"boss": ["res://assets/audio/music_boss.ogg", 32],
	"snow": ["res://assets/audio/music_snow.ogg", 56],
	"snow_night": ["res://assets/audio/music_snow_night.ogg", 56],
	"snow_town": ["res://assets/audio/music_snow_town.ogg", 64],
	"snow_town_night": ["res://assets/audio/music_snow_town_night.ogg", 64],
	"desert": ["res://assets/audio/music_desert.ogg", 48],
	"desert_night": ["res://assets/audio/music_desert_night.ogg", 48],
	"desert_town": ["res://assets/audio/music_desert_town.ogg", 64],
	"desert_town_night": ["res://assets/audio/music_desert_town_night.ogg", 64],
	"forest": ["res://assets/audio/music_forest.ogg", 56],
	"forest_night": ["res://assets/audio/music_forest_night.ogg", 56],
}
const FIGHTS := ["combat", "boss"]
const VICTORY := "res://assets/audio/music_victory.ogg"
const BASE_DB := -5.0
const FADE := 1.8
const FAST_FADE := 0.7
const NIGHT_FADE := 6.0
const DUSK := 19.0
const DAWN := 5.5
## Fighting keeps the combat track on for a while after the last enemy.
const COMBAT_HOLD := 6.0
## Back to a calm track this soon after leaving it: it carries on where it was
## (a fight doesn't restart the island theme); the fight tracks always start over.
const RESUME_WITHIN := 120.0
## Brinehollow's town: round the square, and the harbour front out to the pier's end.
const TOWN_R := 52.0
## A chain island's village: past its plaza's edge, round each hamlet and each building.
const PLAZA_PAD := 16.0
const HAMLET_R := 22.0
const HOUSE_R := 14.0

var current: String = ""
## Force a track (tests, cutscenes); "" = automatic.
var override: String = ""

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _streams: Dictionary = {}
var _check_t: float = 0.0
var _combat_hold: float = 0.0
var _duck: float = 0.0
var _fade_rate: float = 1.0 / FADE
## By context (day and night share): [position, when left].
var _left: Dictionary = {}
var _want: String = ""
## Seconds to the playing track's next bar line, once a calm change is waiting for it.
var _cue: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _player("MusicA")
	_b = _player("MusicB")
	_active = _a
	_sting = _player("Sting")
	_sting.volume_db = BASE_DB + 1.0


func _player(n: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = n
	p.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	p.volume_db = -80.0
	add_child(p)
	return p


func _stream(track: String) -> AudioStream:
	if not _streams.has(track):
		var s: AudioStreamOggVorbis = load(TRACKS[track][0])
		s.loop = true
		_streams[track] = s
	return _streams[track]


func bar_len(track: String) -> float:
	return _stream(track).get_length() / float(TRACKS[track][1])


## "sea_night" -> "sea": the context, which day and night share.
static func context_of(track: String) -> String:
	return track.trim_suffix("_night")


## Switch to a track (crossfade over `fade` s). Same track: nothing happens. The
## other time of day of the same piece carries on from the same moment; a calm
## track left less than RESUME_WITHIN ago picks up at the bar it was in.
func play(track: String, fade: float = FADE) -> void:
	_cue = -1.0
	if track == current:
		return
	var now := Time.get_ticks_msec() * 0.001
	var at := 0.0
	var resumed := false
	if current != "" and _active.playing:
		var pos := _active.get_playback_position()
		_left[context_of(current)] = [pos, now]
		if context_of(current) == context_of(track):
			at = pos
			resumed = true
	if not resumed and track not in FIGHTS:
		var left: Array = _left.get(context_of(track), [0.0, -INF])
		if now - float(left[1]) < RESUME_WITHIN:
			at = floorf(float(left[0]) / bar_len(track)) * bar_len(track)
	current = track
	_fade_rate = 1.0 / fade
	var next := _b if _active == _a else _a
	next.stop()
	next.stream = _stream(track)
	next.volume_db = -60.0
	next.play(at)
	_active = next


## A short fanfare (a boss beaten); the music dips under it.
func victory() -> void:
	_sting.stream = load(VICTORY)
	_sting.play()
	_duck = 5.5


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.5
		_want = override if override != "" else _variant(_pick(0.5))
	if _want != current:
		_change(delta)
	else:
		_cue = -1.0
	_duck = maxf(_duck - delta, 0.0)
	var target := BASE_DB - (14.0 if _duck > 0.0 else 0.0)
	for p in [_a, _b]:
		var ap := p as AudioStreamPlayer
		if ap == _active and ap.playing:
			ap.volume_db = move_toward(ap.volume_db, target, 60.0 * _fade_rate * delta)
		elif ap.playing:
			ap.volume_db = move_toward(ap.volume_db, -60.0, 60.0 * _fade_rate * delta)
			if ap.volume_db <= -59.0:
				ap.stop()


## Toward _want: a fight at once, out of the title at once (a scene is loading),
## day <-> night now (in step), anything else on the next bar line.
func _change(delta: float) -> void:
	if _want in FIGHTS:
		play(_want, FAST_FADE)
	elif current in ["", "title"] or not _active.playing:
		play(_want)
	elif context_of(_want) == context_of(current):
		play(_want, NIGHT_FADE)
	elif _cue < 0.0:
		var bar := bar_len(current)
		_cue = bar - fmod(_active.get_playback_position(), bar)
	else:
		_cue -= delta
		if _cue <= 0.0:
			play(_want)


## The night arrangement of a calm track between DUSK and DAWN.
func _variant(track: String) -> String:
	var h: float = Weather.hour()
	var night := track + "_night"
	return night if TRACKS.has(night) and (h >= DUSK or h < DAWN) else track


## What fits right now.
func _pick(dt: float) -> String:
	var tree := get_tree()
	var cs := tree.current_scene
	if cs == null or tree.get_first_node_in_group("title_screen") != null:
		return "title"
	var me := tree.get_first_node_in_group("player") as Node3D
	if me == null:
		return context_of(current) if current != "" else "title"
	var pos := me.global_position
	for b in tree.get_nodes_in_group("bosses"):
		if is_instance_valid(b) and b.has_method("in_combat") and b.in_combat() and (b as Node3D).global_position.distance_to(pos) < 55.0:
			_combat_hold = COMBAT_HOLD
			return "boss"
	var fighting := false
	for e in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("in_combat") and e.in_combat() and (e as Node3D).global_position.distance_to(pos) < 30.0:
			if not (e.has_method("is_dead") and e.is_dead()):
				fighting = true
				break
	if not fighting:
		for s in tree.get_nodes_in_group("enemy_ships"):
			if is_instance_valid(s) and s.in_combat() and (s as Node3D).global_position.distance_to(pos) < 170.0:
				fighting = true
				break
	if fighting:
		_combat_hold = COMBAT_HOLD
		return "combat"
	_combat_hold -= dt
	if _combat_hold > 0.0 and current == "combat":
		return "combat"
	var ctx = me.get("context")
	if ctx != null and int(ctx) != 0:
		return "sea"
	var ship := tree.get_first_node_in_group("ship") as Node3D
	if ship and pos.distance_to(ship.global_position) < 9.0 and absf(float(ship.get("speed"))) > 1.5:
		return "sea"
	# swimming: whatever was on (the sea stays the sea)
	if me.has_method("is_swimming") and me.is_swimming():
		var was := context_of(current)
		return was if was not in ["", "title"] and was not in FIGHTS else "island"
	if in_village(tree, pos):
		return KitStyle.of(KitStyle.around(tree, pos)[0])["music_town"]
	# ashore on a chain island: its style's track
	var zone := KitStyle.around(tree, pos)
	if float(zone[1]) > 0.5:
		return KitStyle.of(zone[0])["music"]
	# out on the open water, far from the home island
	var ec := EnemyShip.safe_center
	if Vector2(pos.x - ec.x, pos.z - ec.z).length() > EnemyShip.SAFE_RADIUS + 40.0:
		var near_fort := false
		for f in tree.get_nodes_in_group("forts"):
			if (f as Node3D).global_position.distance_to(pos) < 45.0:
				near_fort = true
		return "island" if near_fort else "sea"
	return "island"


## In a town's streets at world `pos`: Brinehollow's square and its harbour front
## (quay, row houses, the pier), or a chain island's village (its plaza, hamlets
## and buildings, from the village plan).
static func in_village(tree: SceneTree, pos: Vector3) -> bool:
	var wg := tree.get_first_node_in_group("world_gen")
	var home: StarterIsland = wg.starter_island
	var hl := home.to_local(pos)
	var hp := Vector2(hl.x, hl.z)
	if hp.distance_to(StarterIsland.VILLAGE) < TOWN_R:
		return true
	var hb: KitHarbour = home.harbour
	var s := hb.s_of(hp)
	var t := hb.t_of(hp)
	if s > hb.s0 - 6.0 and s < hb.s1 + 6.0 and t > hb.wall(s) - hb.pier_len - 8.0 and t < hb.wall(s) + hb.plat_d + 20.0:
		return true
	for isl in wg.chain_islands.values():
		var l := (isl as Node3D).to_local(pos)
		var p := Vector2(l.x, l.z)
		var plan: Dictionary = isl.village_plan
		if p.distance_to(plan["c"]) < float(plan["plaza_r"]) + PLAZA_PAD:
			return true
		for h in plan["hamlets"]:
			if p.distance_to(h["c"]) < HAMLET_R:
				return true
		for b in plan["buildings"]:
			if p.distance_to(b["p"]) < HOUSE_R:
				return true
	return false
