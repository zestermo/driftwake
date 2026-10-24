extends Node3D
## The fog isle's boss (1.20, docs/v1_20_plan.md): the drowned captain of the wreck in the fog, who never left her.
## He's a captain like you (Player with a CaptainBrain: your moves, a blade and its skills, an ultimate), a ghost
## (his look's "spirit": he glows the cold blue-white of the dead and shot passes through him) and much harder to put
## down. Asleep at his wreck till a standing captain comes close (BeastArena), then three acts: the duel; below
## 60% his drowned crew climb out of the ground to fight beside him (a GruntCamp of the drowned); below 30% the fog
## takes him and he steps out of it behind whoever he's fighting every few seconds. Beaten, he's gone into the fog.
##
## The arena's boss interface (JungleBeast's: asleep, alert, in_combat, reset_fight, is_dead, health_frac, boss_name,
## phase, trophy). Co-op: every machine makes its own captain under this node (the same name, so the host's snapshot
## finds the guests' puppets); the host's has the brain and decides everything; the guests read the state, the act and
## his health from this node's snapshot.

## His health over a rival captain's (x Levels on the island's level), the brain's skill, the acts' thresholds.
const HP_K := 6.0
const SKILL := 0.9
const ACT2 := 0.6
const ACT3 := 0.3
## In the last act he steps out of the fog behind his foe every BLINK_EVERY s (game time).
const BLINK_EVERY := 6.5
## His drowned crew in the second act.
const CREW := 3
## Past this from every captain he stands still (the AI sleeps); asleep he wakes within the arena's WAKE_R.
const SLEEP_R := 90.0
const GHOST := Color(0.55, 0.95, 1.0)
const WEAPONS := ["cutlass", "greatsword", "katana"]
const LINES := {
	"wake": ["Who walks my deck?", "Another one for the crew...", "The sea sent you. The sea sends me all of them."],
	"act2": ["All hands! Up from the deep!", "Crew! Rise!", "Come up, lads. We've a guest."],
	"act3": ["The fog is mine.", "You can't cut what you can't find.", "I've been dead a long time, sailor. I'm patient."],
	"down": ["...the tide... turns...", "At last... the bell...", "Tell them... I came home..."],
}

var arena: Node
var level: int = 0
var post := Vector3.ZERO
var post_yaw: float = 0.0
var variant: int = 0
var boss_name: String = "The Drowned Captain"
var phase: int = 1
## sleep, fight, dead
var state: String = "sleep"
var captain: Player
var crew: Node
var net_puppet: bool = false
var _hp := 1.0
var _blink_t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(cfg: Dictionary) -> Node3D:
	post = cfg.get("post", Vector3.ZERO)
	post_yaw = float(cfg.get("yaw", 0.0))
	level = int(cfg.get("level", 0))
	variant = int(cfg.get("variant", 0))
	boss_name = str(cfg.get("name", boss_name))
	return self


## His look: a drowned captain's longcoat and hat, grey-green skin, all of him glowing (the look's "spirit").
static func captain_look(v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + v
	var lk := PirateGrunt.crew_look(rng)
	lk.merge({"name": "Drowned Captain", "body": "masc", "build": "broad", "height": 1.12,
		"skin": Color(0.5, 0.58, 0.54), "hair": "long", "hair_color": Color(0.3, 0.34, 0.3), "facial_hair": ["long_beard", "beard", "stubble"][v % 3],
		"hat": ["tricorn", "bicorne", "tricorn"][v % 3], "hat_color": Color(0.16, 0.18, 0.18), "coat": "longcoat", "coat_color": Color(0.2, 0.24, 0.24),
		"trim_color": Color(0.62, 0.56, 0.38), "top": "shirt", "top_color": Color(0.6, 0.6, 0.56), "vest": "vest", "vest_color": Color(0.24, 0.26, 0.26),
		"legs": "breeches", "legs_color": Color(0.2, 0.2, 0.2), "feet": "tall_boots", "marks": "scar", "eyepatch": v % 3 == 1, "spirit": true}, true)
	return lk


func _ready() -> void:
	_rng.seed = hash(["ghost_captain", variant, level])
	net_puppet = Net.is_client()
	add_to_group("net_sync")
	add_to_group("enemies")
	# (the arena sets where he stands once he's in the tree)
	_raise.call_deferred()


## His captain under this node, on every machine: the host's with the brain, a puppet on a guest's.
func _raise() -> void:
	var at := global_position + Vector3.UP * 0.5
	var lk := captain_look(variant)
	if net_puppet:
		var p: Player = load("res://scenes/player/player.tscn").instantiate()
		p.name = "Captain"
		p.is_local = false
		p.is_ai = true
		p.net_profile = {"look": lk, "name": boss_name}
		add_child(p)
		p.global_position = at
		captain = p
		return
	captain = RivalDuel.build(self, "Captain", lk, str(WEAPONS[variant % WEAPONS.size()]), at, post_yaw, SKILL)
	captain.player_model.rotation.y = post_yaw
	captain.get_node("Brain").order = "hold"
	captain.hp_k = HP_K * Levels.hp_k(level, 10)
	captain._recalc_stats()
	captain.health_component.current_health = captain.health_component.max_health
	captain.defeated.connect(_on_defeated)


func _alive() -> bool:
	return captain != null and is_instance_valid(captain)


func is_dead() -> bool:
	return state == "dead"


func asleep() -> bool:
	return state == "sleep"


func in_combat() -> bool:
	return state == "fight"


func is_fighting() -> bool:
	return in_combat()


func health_frac() -> float:
	if net_puppet or not _alive():
		return _hp
	return captain.health_component.current_health / maxf(captain.health_component.max_health, 1.0)


func trophy(t: int) -> ItemData:
	return Gear.make("head", "tricorn", {"hat": "tricorn", "hat_color": Color(0.16, 0.18, 0.18)}, "Drowned Captain's Tricorn", t)


## Woken (the arena: a standing captain near): he draws and comes for them.
func alert(_delay: float = 0.0) -> void:
	if Net.forward(self, "alert", [_delay]):
		return
	if state != "sleep" or not _alive():
		return
	state = "fight"
	phase = 1
	_wake(captain)
	captain.get_node("Brain").order = "fight"
	_say("wake")


## Everyone gone: healed, his crew back under the ground, back to his post asleep.
func reset_fight() -> void:
	if state != "fight" or not _alive():
		return
	state = "sleep"
	phase = 1
	_free_crew()
	if captain.current_state_name() == "Downed":
		Duel.stand_up(captain, captain.health_component.max_health, 0.0)
	captain.health_component.current_health = captain.health_component.max_health
	captain.get_node("Brain").order = "hold"
	captain.global_position = global_position + Vector3.UP * 0.5
	captain.reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if not _alive():
		return
	_sleep_far()
	if net_puppet or state != "fight":
		return
	var f := health_frac()
	if phase == 1 and f < ACT2:
		phase = 2
		_say("act2")
		_raise_crew()
	elif phase == 2 and f < ACT3:
		phase = 3
		_say("act3")
		_blink_t = BLINK_EVERY * 0.5
	if phase == 3:
		_blink_t -= delta
		if _blink_t <= 0.0 and captain.current_state_name() != "Downed":
			_blink_t = BLINK_EVERY
			_blink()


## Far from every captain he doesn't think (his body stands where it is).
func _sleep_far() -> void:
	var near := false
	for p in Net.all_players():
		if (p as Node3D).global_position.distance_to(captain.global_position) < SLEEP_R:
			near = true
			break
	var want := Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED
	if captain.process_mode != want:
		captain.process_mode = want


## The fog takes him and he steps out of it behind his foe (a puff of cold light where he went and where he came).
func _blink() -> void:
	var foe: Node3D = null
	var best := INF
	for p in Net.all_players():
		var d := (p as Node3D).global_position.distance_to(captain.global_position)
		if d < best and p.has_method("is_standing") and p.is_standing():
			best = d
			foe = p
	if foe == null or best > 30.0:
		return
	var back: Vector3 = (foe as Player).player_model.global_basis.z if foe is Player else Vector3.BACK
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var to := foe.global_position + back * 2.6 + Vector3.UP * 0.3
	Net.fx("sparkle", [captain.global_position + Vector3.UP * 1.2, 24, GHOST])
	Net.fx("puff", [captain.global_position + Vector3.UP * 0.8, "mist", 4, 1.6, 0.9, Color(0.75, 0.85, 0.88), 0.4, Vector3.UP])
	captain.global_position = to
	captain.reset_physics_interpolation()
	var face := foe.global_position - to
	captain.player_model.rotation.y = atan2(-face.x, -face.z)
	Net.fx("sparkle", [to + Vector3.UP * 1.2, 24, GHOST])
	Net.fx("sfx", ["whoosh", to, -4.0, 0.1, 0.7])


## His drowned crew climb out of the ground round the floor's edge and join him.
func _raise_crew() -> void:
	_free_crew()
	var c := GruntCamp.new()
	c.name = "Crew"
	c.respawn_time = 1e9
	c.level = level
	for i in range(CREW):
		var a := TAU * i / CREW + _rng.randf_range(-0.4, 0.4)
		var at := global_position + Vector3(cos(a), 0, sin(a)) * 9.0
		c.add_grunt({"post": at, "yaw": a + PI, "mode": "stand", "seed": 4100 + variant * 10 + i, "script": "res://scripts/enemies/drowned.gd"})
	add_child(c)
	crew = c
	for i in range(CREW):
		var a := TAU * i / CREW
		Net.fx("puff", [global_position + Vector3(cos(a), 0.2, sin(a)) * 9.0, "dust", 4, 1.2, 0.8, Color(0.4, 0.42, 0.4), 0.5, Vector3.UP])
	for g in get_tree().get_nodes_in_group("enemies"):
		if g is PirateGrunt and c.is_ancestor_of(g):
			(g as PirateGrunt).alert(0.3)


func _free_crew() -> void:
	if crew and is_instance_valid(crew):
		crew.queue_free()
	crew = null


## Beaten: his last words, the fog takes him, and his crew sink back under.
func _on_defeated() -> void:
	if state == "dead":
		return
	state = "dead"
	phase = 3
	_say("down")
	_free_crew()
	Net.event(self, "gone", [])
	_gone()


func _gone() -> void:
	if not _alive():
		return
	var at := captain.global_position + Vector3.UP * 1.2
	FX.sparkle(at, 40, GHOST)
	FX.puff(at - Vector3.UP * 0.4, "mist", 6, 2.0, 1.6, Color(0.75, 0.85, 0.88), 0.5, Vector3.UP)
	var c := captain
	captain = null
	c.get_tree().create_timer(1.2, false).timeout.connect(func(): if is_instance_valid(c): c.queue_free())


func _say(kind: String) -> void:
	if not _alive():
		return
	var lines: Array = LINES[kind]
	Net.fx("speech", [captain, str(lines[_rng.randi() % lines.size()]), 0.78])


func _wake(p: Player) -> void:
	Net.fx("sparkle", [p.global_position + Vector3.UP * 1.4, 30, GHOST])
	Net.fx("sfx", ["bell", p.global_position, -2.0, 0.0, 0.6])


# co-op: the guests read his state, his act and his health from here
func net_pack() -> Array:
	return [["sleep", "fight", "dead"].find(state), phase, health_frac()]


func _process(_d: float) -> void:
	if not net_puppet:
		return
	var s = Net.latest(self)
	if s == null or (s as Array).size() < 3:
		return
	state = ["sleep", "fight", "dead"][clampi(int(s[0]), 0, 2)]
	phase = int(s[1])
	_hp = float(s[2])


func net_event(what: String, _args: Array) -> void:
	if what == "gone":
		state = "dead"
		_gone()
