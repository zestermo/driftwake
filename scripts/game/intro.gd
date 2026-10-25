class_name Intro
extends Node3D
## A new game's opening (docs/v1_19_plan.md: the legend and a personal spark): a narrated cutscene over a night sea
## in a storm sets up the world (the storm wall at the First Sea's end, the Last Lantern past it, the Admiralty, the
## rival crews, the Tide Lords), then the spark, played: the captain is a deckhand on Captain Maren Holt's ship when
## an Admiralty cutter runs her down; two marines come over the rail; Holt's last order; a broadside, black, and the
## captain wakes on Brinehollow's beach (Player.wake_on_beach, the story as before). Staged far out on open sea and
## gone after (weather and time put back). Names are Driftwake's own, for Zach's review.

## Off for now (Zach, 2026-10-25: "too unpolished"): a new game wakes on the beach as before 1.19. The intro's own
## test and render still play it (Intro.play); set true once it's polished.
const ENABLED := false
const HOLT := "Captain Maren Holt"
const NARRATION := [
	"They say the First Sea ends in a wall of storm. No ship has sailed through it and come back.",
	"Past it burns the Last Lantern: a light that shows the way to whatever a heart wants most. Every power on the water wants it.",
	"The Admiralty wants it locked away. Their grey ships hold the lanes, and they hang any captain who sails without their leave.",
	"The pirate crews want it for themselves, and fight each other for every island on the way.",
	"And beyond the storm wait the Tide Lords: four captains so strong that kingdoms pay them to stay away.",
	"Captain Maren Holt meant to find it first. She had an old ship, a short crew, and one deckhand with nothing left to lose.",
]
const HOLT_START := "Grey sails off the bow! The Admiralty's found us. Blades out, deckhand!"
const HOLT_LAST := [
	"Listen to me. Whatever happens tonight, you find the Lantern.",
	"Get strong enough to sail through that storm. And make them answer for this.",
]
const FIGHT_MAX_S := 50.0
const DECK_Y := 1.6   # (the main deck, in HullBuilder's model; the stern's raised deck is higher)

var p: Player
var on_done: Callable
var spot := Vector3.ZERO
var phase := "narrate"
var _deck: AnimatableBody3D
var _cutter: Node3D
var _holt: Humanoid
var marines: Array = []
var _t := 0.0
var _fade: ColorRect
var _forced := -1
var _forced_at := 0.0
var _world_t := 0.0


static func play(captain: Player, done: Callable) -> Intro:
	var i := Intro.new()
	i.name = "Intro"
	i.p = captain
	i.on_done = done
	captain.get_tree().current_scene.add_child(i)
	return i


func _ready() -> void:
	spot = _open_sea()
	global_position = spot
	var w := get_node("/root/Weather")
	_forced = int(w.forced)
	_forced_at = float(w.forced_at)
	_world_t = float(w.world_time())
	w.forced = 3   # (Weather.W.STORM)
	w.forced_at = w.world_time()
	w.set_world_time(DayClock.secs_of(21.0) - DayClock.secs_of(w.START_HOUR))
	_build()
	p.state_machine.force_state("Idle", {})
	p.global_position = _deck.global_position + Vector3(0.5, DECK_Y + 0.3, 2.0)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	var shots := []
	var cams := [
		[_cutter, Vector3(30, 9, 40), Vector3(0, 4, 0)],
		[_cutter, Vector3(-12, 4, 18), Vector3(0, 6, 0)],
		[_cutter, Vector3(14, 3, 6), Vector3(0, 3, 0)],
		[_deck, Vector3(-18, 6, -10), Vector3(0, 3, 0)],
		[_deck, Vector3(10, 12, 30), Vector3(0, 2, 0)],
		[_holt, Vector3(1.5, 1.8, 3.0), Vector3(0, 1.6, 0)],
	]
	for i in range(NARRATION.size()):
		var c: Array = cams[i]
		var line := {"who": null, "name": "", "text": NARRATION[i], "pitch": 0.8}
		if c[0] == _holt:
			# (Holt in her own frame: the camera in front of her)
			shots.append({"cam": [_holt, _holt], "off": Vector3(-0.6, 1.6, 2.6), "fov": 50.0, "say": line})
			continue
		var at: Vector3 = (c[0] as Node3D).global_position
		shots.append({"cam": [at + c[1], at + c[2]], "to": [at + c[1] * 0.85, at + c[2]], "fov": 55.0, "say": line})
	var cs := Cutscene.play(get_tree(), shots, "intro")
	cs.finished.connect(func(_skipped): _start_fight())


## Deep open water far from every island (the first that fits on a widening ring).
func _open_sea() -> Vector3:
	var ocean := get_node_or_null("/root/Ocean")
	for r in [1400.0, 1800.0, 2400.0, 3000.0]:
		for k in range(16):
			var a := TAU * k / 16.0
			var c := Vector3(cos(a) * r, 0.0, sin(a) * r)
			if EnemyShip.huntable_at(c) and (ocean == null or float(ocean.call("depth_at", c + Vector3.UP * 80.0, [], true)) > 20.0):
				return c
	return Vector3(1400.0, 0.0, 0.0)


func _build() -> void:
	_deck = AnimatableBody3D.new()
	_deck.name = "HoltShip"
	add_child(_deck)
	HullBuilder.build(_deck, {"hull": Color(0.6, 0.5, 0.42), "deck": Color(0.8, 0.72, 0.62), "sail": Color(0.85, 0.82, 0.74), "trim": Color(0.6, 0.3, 0.2)})
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(5.4, 0.4, 20.0)
	cs.shape = sh
	cs.position = Vector3(0, DECK_Y - 0.2, 0)
	_deck.add_child(cs)
	for side in [-1.0, 1.0]:
		var rail := CollisionShape3D.new()
		var rs := BoxShape3D.new()
		rs.size = Vector3(0.3, 1.4, 20.0)
		rail.shape = rs
		rail.position = Vector3(side * 2.85, DECK_Y + 0.7, 0)
		_deck.add_child(rail)
	_cutter = Node3D.new()
	_cutter.name = "Cutter"
	add_child(_cutter)
	HullBuilder.build(_cutter, EnemyShip.KINDS["marine"]["look"])
	_cutter.position = Vector3(-14.0, 0.0, -6.0)
	_cutter.rotation.y = 0.35
	_holt = Humanoid.new()
	_holt.name = "Holt"
	var lk := CharacterLook.default_look()
	lk["name"] = HOLT
	lk["body"] = "fem"
	lk["hair"] = "long"
	lk["hair_color"] = Color(0.55, 0.52, 0.5)
	lk["hat"] = "tricorn"
	lk["coat"] = "captain"
	lk["coat_color"] = Color(0.45, 0.12, 0.1)
	_holt.setup(lk)
	_holt.position = Vector3(1.3, DECK_Y, 1.0)
	_holt.rotation.y = PI
	_deck.add_child(_holt)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.add_child(_fade)
	add_child(layer)


## She rides the swell (the real waves under her).
func _physics_process(delta: float) -> void:
	_t += delta
	var ocean := get_node_or_null("/root/Ocean")
	if ocean and _deck:
		var h := float(ocean.call("get_wave_height", spot))
		_deck.global_position = spot + Vector3(0, h - 0.2, 0)
		_deck.rotation.z = 0.05 * sin(_t * 0.9)
		_deck.rotation.x = 0.03 * sin(_t * 0.7 + 1.0)
	if phase == "fight":
		var down := marines.all(func(m): return not is_instance_valid(m) or m.health_component.current_health <= 0.0)
		var out: bool = p.current_state_name() == "Downed" or p.health_component.current_health <= 0.0
		if down or out or _t > FIGHT_MAX_S:
			_ending()
	elif phase == "fade":
		_fade.color.a = minf(_fade.color.a + delta / 1.2, 1.0)
		if _fade.color.a >= 1.0:
			_finish()


## The spark, played: Holt's order, and two marines over the rail.
func _start_fight() -> void:
	if phase != "narrate":
		return
	phase = "fight"
	_t = 0.0
	SpeechBubble.say(_holt, HOLT_START, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in range(2):
		var lk: Dictionary = CharacterLook.random_look(rng)
		EnemyShip.marine_look(lk, rng, false)
		lk["name"] = "Admiralty marine"
		var brain := CaptainBrain.new()
		brain.skill = 0.25
		var m := Player.spawn_ai(self, lk, _deck.global_position + Vector3(-1.5 + i * 3.0, DECK_Y + 0.5, -4.0), 0.0, brain, "IntroMarine_%d" % i)
		var cut := ItemDB.get_item("cutlass")
		if cut:
			m.equip_weapon(cut, false)
		m.hp_k = 0.6
		m._recalc_stats()
		marines.append(m)


## Holt's last order, a broadside, black.
func _ending() -> void:
	phase = "ending"
	for m in marines:
		if is_instance_valid(m):
			m.get_node("Brain").order = "hold"
	var shots := []
	for l in HOLT_LAST:
		shots.append({"cam": [_holt, _holt], "off": Vector3(-0.6, 1.6, 2.4), "fov": 50.0, "say": {"who": _holt, "name": HOLT, "text": l, "pitch": 1.0}})
	var cs := Cutscene.play(get_tree(), shots, "intro_end")
	cs.finished.connect(func(_skipped):
		var fx := get_node_or_null("/root/FX")
		if fx:
			fx.call("sfx", "cannon", _deck.global_position, 8.0, 0.02, 0.8)
			fx.call("screen_flash", _deck.global_position, Color(1.0, 0.85, 0.6, 0.8), 0.4)
		phase = "fade")


func _finish() -> void:
	phase = "done"
	var w := get_node("/root/Weather")
	w.forced = _forced
	w.forced_at = _forced_at
	w.set_world_time(_world_t)
	if p.current_state_name() == "Downed":
		Duel.stand_up(p, p.health_component.max_health, p.power.energy)
	p.health_component.current_health = p.health_component.max_health
	if on_done.is_valid():
		on_done.call()
	queue_free()
