extends Node
## Background music (autoload "Music"). Picks a track from what's going on
## around your own captain (each machine plays its own) and crossfades to it:
##   title   - the title screen (the game's theme)
##   village - in a town's streets: Brinehollow's square and harbour front, a chain island's village
##   island  - on foot in the wilds (on a chain island: its KitStyle "music")
##   sea     - at the helm / a cannon, aboard under way, or out on the open sea: one of SEA_DAY
##             (by night SEA_NIGHT) at random, a new one each time a track has played through or
##             you put to sea again, never the same twice running; in a storm, SEA_STORM
##   combat  - enemies fighting you (or a pirate ship hunting you) nearby
##   boss    - a boss fight close by: boss_titan for a beast, boss_duel for a captain (boss_track)
## plus a short victory fanfare (victory()) that ducks the music for a moment.
## The calm tracks have "<name>_night" variants, the same piece arranged sparser
## with the same bars, played from DUSK to DAWN: the change crossfades slowly at
## the same position. Calm changes wait for the playing track's next bar line and
## come in on one of the new track's; fights cut in at once.
## Volume: the "Music" bus (Options > Audio > Music).

## [file, bars in the loop] (the bars give each track's bar length).
const TRACKS := {
	"title": ["res://assets/audio/music_title.ogg", 40],
	"village": ["res://assets/audio/music_village.ogg", 52],
	"village_night": ["res://assets/audio/music_village_night.ogg", 52],
	"island": ["res://assets/audio/music_island.ogg", 48],
	"island_night": ["res://assets/audio/music_island_night.ogg", 48],
	"sea_breeze": ["res://assets/audio/music_sea_breeze.ogg", 52],
	"sea_horizon": ["res://assets/audio/music_sea_horizon.ogg", 48],
	"sea_calm": ["res://assets/audio/music_sea_calm.ogg", 40],
	"sea_trade": ["res://assets/audio/music_sea_trade.ogg", 44],
	"sea_dawn": ["res://assets/audio/music_sea_dawn.ogg", 36],
	"sea_wander": ["res://assets/audio/music_sea_wander.ogg", 44],
	"sea_stars": ["res://assets/audio/music_sea_stars.ogg", 40],
	"sea_far": ["res://assets/audio/music_sea_far.ogg", 36],
	"sea_storm": ["res://assets/audio/music_sea_storm.ogg", 40],
	"combat_sea": ["res://assets/audio/music_combat_sea.ogg", 32],
	"combat_wild": ["res://assets/audio/music_combat_wild.ogg", 32],
	"combat_town": ["res://assets/audio/music_combat_town.ogg", 48],
	"boss_titan": ["res://assets/audio/music_boss_titan.ogg", 32],
	"boss_duel": ["res://assets/audio/music_boss_duel.ogg", 40],
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
	"volcanic": ["res://assets/audio/music_volcanic.ogg", 32],
	"volcanic_night": ["res://assets/audio/music_volcanic_night.ogg", 32],
	"volcanic_town": ["res://assets/audio/music_volcanic_town.ogg", 32],
	"volcanic_town_night": ["res://assets/audio/music_volcanic_town_night.ogg", 32],
	"atoll": ["res://assets/audio/music_atoll.ogg", 32],
	"atoll_night": ["res://assets/audio/music_atoll_night.ogg", 32],
	"atoll_town": ["res://assets/audio/music_atoll_town.ogg", 32],
	"atoll_town_night": ["res://assets/audio/music_atoll_town_night.ogg", 32],
}
## The fight by place (2026-11-09): at sea or aboard, ashore in the wilds, in a town's streets.
const COMBATS := ["combat_sea", "combat_wild", "combat_town"]
## The bosses by kind (2026-11-09): a beast or monster, a captain (a man with a blade).
const BOSSES := ["boss_titan", "boss_duel"]
const FIGHTS := ["combat_sea", "combat_wild", "combat_town", "boss_titan", "boss_duel"]
## The sea's rotation (2026-11-06): every calm sea track by day, the hushed ones by night.
const SEA_DAY := ["sea_breeze", "sea_horizon", "sea_calm", "sea_trade", "sea_dawn", "sea_wander", "sea_stars", "sea_far"]
const SEA_NIGHT := ["sea_calm", "sea_stars", "sea_dawn", "sea_horizon"]
const SEA_STORM := "sea_storm"
## Weather.storm into and out of the storm's track (apart, so a storm's edge doesn't flip it).
const STORM_IN := 0.55
const STORM_OUT := 0.35
const VICTORY := "res://assets/audio/music_victory.ogg"
const RIVAL := "res://assets/audio/music_rival.ogg"
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
## A heavy blow's dip (1.28: punch()): dB under the mix, recovering at PUNCH_RECOVER dB a second.
var _punch_db: float = 0.0
const PUNCH_RECOVER := 14.0
var _fade_rate: float = 1.0 / FADE
## By context (day and night share): [position, when left].
var _left: Dictionary = {}
var _want: String = ""
## Seconds to the playing track's next bar line, once a calm change is waiting for it.
var _cue: float = -1.0
## The sea track picked from the rotation, how long it has played, when the sea was last wanted.
var sea_pick: String = ""
var _sea_played: float = 0.0
var _sea_seen: float = -INF
var _storming := false
## Seconds this node has run (paused included), for the sea's "put to sea again".
var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
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
		Perf.mark("music %s loaded" % track)
		var s: AudioStreamOggVorbis = load(TRACKS[track][0])
		s.loop = true
		_streams[track] = s
	return _streams[track]


func bar_len(track: String) -> float:
	return _stream(track).get_length() / float(TRACKS[track][1])


## "island_night" -> "island": the context, which day and night share.
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


## A heavy blow landed near you: the music dips `db` for a beat so the hit cuts through (a sidechain feel).
func punch(db: float) -> void:
	_punch_db = maxf(_punch_db, db)


func punch_tick(delta: float) -> void:
	_punch_db = maxf(_punch_db - PUNCH_RECOVER * delta, 0.0)


## A short fanfare (a boss beaten); the music dips under it.
func victory() -> void:
	_sting.stream = load(VICTORY)
	_sting.play()
	_duck = 5.5


## (1.30) A rival crew's ship has anchored: their brass call; the music dips under it.
func rival() -> void:
	_sting.stream = load(RIVAL)
	_sting.play()
	_duck = 5.5


func _process(delta: float) -> void:
	_clock += delta
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.5
		_want = override if override != "" else _resolve(_pick(0.5))
	if current == sea_pick and _active.playing:
		_sea_played += delta
	if _want != current:
		_change(delta)
	else:
		_cue = -1.0
	_duck = maxf(_duck - delta, 0.0)
	punch_tick(delta)
	var target := BASE_DB - (14.0 if _duck > 0.0 else 0.0) - _punch_db
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
	var night := track + "_night"
	return night if TRACKS.has(night) and is_night() else track


func is_night() -> bool:
	var h: float = Weather.hour()
	return h >= DUSK or h < DAWN


## "sea" -> a track of the sea's (the storm's, or the rotation's); anything else its time of day's.
func _resolve(track: String) -> String:
	return sea_track() if track == "sea" else _variant(track)


## The sea's track now: the storm's in a storm; else the rotation's pick, a new one once it has
## played through, when you put to sea again after a while, or when the pool changes at dusk/dawn.
func sea_track() -> String:
	var now := _clock
	var st: float = Weather.storm
	_storming = st > (STORM_OUT if _storming else STORM_IN)
	var away := now - _sea_seen > RESUME_WITHIN
	_sea_seen = now
	if _storming:
		return SEA_STORM
	var pool: Array = SEA_NIGHT if is_night() else SEA_DAY
	var done := sea_pick != "" and _sea_played >= _stream(sea_pick).get_length()
	if sea_pick not in pool or done or away:
		next_sea(pool)
	return sea_pick


## Pick the rotation's next track from `pool`, never the one just played.
func next_sea(pool: Array = SEA_DAY) -> String:
	var choices := pool.filter(func(t): return t != sea_pick)
	sea_pick = choices[_rng.randi() % choices.size()]
	_sea_played = 0.0
	return sea_pick


## A boss's track: the duel for a captain (a PirateGrunt kind, the ape aside), the titan for a beast.
## (By script name, so Music holds no class reference to the enemies.)
static func boss_track(b: Node) -> String:
	var s: Script = b.get_script()
	while s != null:
		match s.get_global_name():
			"JungleApe":
				return "boss_titan"
			"PirateGrunt":
				return "boss_duel"
		s = s.get_base_script()
	return "boss_titan"


static func is_sea(track: String) -> bool:
	return track.begins_with("sea_")


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
			# the boss fight keeps the track it started on
			return current if current in BOSSES else boss_track(b)
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
				if current not in COMBATS:
					_combat_hold = COMBAT_HOLD
					return "combat_sea"
				break
	if fighting:
		_combat_hold = COMBAT_HOLD
		# a fight keeps the track it started on, wherever it goes
		return current if current in COMBATS else fight_track(tree, me, pos)
	_combat_hold -= dt
	if _combat_hold > 0.0 and current in COMBATS:
		return current
	var ctx = me.get("context")
	if ctx != null and int(ctx) != 0:
		return "sea"
	var ship := tree.get_first_node_in_group("ship") as Node3D
	if ship and pos.distance_to(ship.global_position) < 9.0 and absf(float(ship.get("speed"))) > 1.5:
		return "sea"
	# swimming: whatever was on (the sea stays the sea)
	if me.has_method("is_swimming") and me.is_swimming():
		var was := context_of(current)
		if is_sea(was):
			return "sea"
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


## Which fight fits where you are: aboard, on deck, swimming or at the helm the sea's; in a town's
## streets the reel; anywhere else ashore the wilds'.
static func fight_track(tree: SceneTree, me: Node3D, pos: Vector3) -> String:
	var ctx = me.get("context")
	if ctx != null and int(ctx) != 0:
		return "combat_sea"
	var ship := tree.get_first_node_in_group("ship") as Node3D
	if ship and pos.distance_to(ship.global_position) < 9.0:
		return "combat_sea"
	if me.has_method("is_swimming") and me.is_swimming():
		return "combat_sea"
	return "combat_town" if in_village(tree, pos) else "combat_wild"


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
