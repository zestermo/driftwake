class_name ArenaBout
extends Node
## A bout in the capital's arena (docs/v1_21_plan.md: the one-on-one ladder), run by the host: a captain-style AI
## (RivalDuel's, on every screen) steps out onto the sand against the captain who asked. Nonlethal: the first under a
## tenth of their health (or down) loses, both stand again, and the rival leaves. The ladder is each captain's own
## (Player.arena_rank, saved with the captain): its six named fighters in turn, the purse by rank, the champion's
## prize (the Champion's Sabre, the title and, once Driftfruits are back in the world, a chance at one); after that,
## a challenger a day for a smaller purse. The result goes to every screen (Net._all_arena_result); the captain's
## own machine pays them and moves them up.

signal ended(won: bool)

## The ladder: [name, weapon, skill, look over a random one]. Purses by rank (Zach's table, 2026-10-24).
const FIGHTERS := [
	["Pip Tanner, the rookie", "cutlass", 0.25, {"coat": "none", "hat": "none"}],
	["Big Garran, the brawler", "warhammer", 0.4, {"vest": "jerkin", "hat": "none"}],
	["Selene Vasquez, the duellist", "katana", 0.55, {"coat": "frock", "hat": "none"}],
	["Old Corran, the veteran", "spear", 0.7, {"hat": "tricorn"}],
	["Ines Ravel, the champion's second", "greatsword", 0.82, {"coat": "longcoat", "hat": "none"}],
	["Aurelio Quint, Champion of the Arena", "katana", 0.95, {"coat": "frock", "coat_color": Color(0.7, 0.55, 0.2), "hat": "none"}],
]
const PURSES := [40, 60, 90, 130, 180, 300]
## A master's test (1.23, "masters teach trees"; kind "master:<tree>"): their pupil goes out to the sparring spot and
## drills there, waiting ("wait"); walk up and they ask if you're ready; ready, you both bow and a 3-2-1 counts you in
## ("bow", "count"), then the fight. Beat them and the master teaches you the tree. [name, weapon ("": bare hands), skill, look, the style they fight in].
const MASTERS := {
	"black_leg": ["Tomo, Bao's pupil", "", 0.45, {"coat": "none", "hat": "headband", "top": "kimono", "sleeves": "long"}, "black_leg"],
}
## The story's quay brawl (1.25.4, Story step "brawl"): a dock tough, bare-handed, who fights as soon as he's out.
const BRAWLER := ["Harl", {"coat": "none", "hat": "bandana", "top": "shirt", "sleeves": "none", "build": "broad"}, 0.2]
const DEFEND_PURSE := 80
const DEFEND_SKILL := 0.85
const DEFEND_WEAPONS := ["cutlass", "katana", "spear", "greatsword", "boarding_axe", "dagger", "warhammer"]
## A bout ends when a fighter falls under this share of their health.
const END_AT := 0.1
## The champion's prize: the trophy weapon, and (only once DevilFruits.IN_WORLD) this chance at a Driftfruit too.
const TROPHY := "champion_sabre"
const FRUIT_CHANCE := 0.25
## Where the fighters start on the sand, from its middle (m) and how long the rival stays after.
const APART := 6.0
const LEAVE_AFTER := 3.0

var captain: Player
var captain_key := ""
var rival: Player
var kind := "ladder"            # "ladder" or "defend"
var rank := 0                   # the ladder rank being fought for (0-5)
var phase := "fight"
## A master's test: the pupil's spot, whether they've asked since the captain came close, and the beat's clock.
var spot := Vector3.ZERO
var _asked := false
var _beat_t := 0.0
var _beat := 4
## Close enough for the pupil to ask; far enough to ask again after "not yet".
const ASK_R := 3.2
const ASK_AGAIN_R := 6.0
## The bow, then a beat a second.
const BOW_SECS := 1.4
var _leave_t := 0.0
var _off_t := 0.0
## A held bout's ground (_leash): the rival further than LEASH_R off it for LEASH_SECS is put back, the captain
## further than FORFEIT_R loses.
const LEASH_R := 7.0
const LEASH_SECS := 1.5
const FORFEIT_R := 30.0
const APART_STUCK := 4.0
static var _n := 0


## The host's: a bout for `c` (a ladder rank, or "defend"), on the sand at frame point `sand` of the capital `isl`.
## Null when one's running for them already.
static func start(c: Player, bout_kind: String, at_rank: int, isl: Node3D, sand: Vector3) -> ArenaBout:
	for b in c.get_tree().get_nodes_in_group("arena_bouts"):
		if (b as ArenaBout).captain == c:
			return null
	var b := ArenaBout.new()
	b.name = "ArenaBout_%d" % _n
	b.captain = c
	b.kind = bout_kind
	b.rank = clampi(at_rank, 0, FIGHTERS.size() - 1)
	b.add_to_group("arena_bouts")
	isl.add_child(b)
	b._spawn(isl, sand)
	return b


static func purse(bout_kind: String, at_rank: int) -> int:
	if bout_kind.begins_with("master:"):
		return 0
	return DEFEND_PURSE if bout_kind == "defend" else int(PURSES[clampi(at_rank, 0, PURSES.size() - 1)])


static func fighter_name(bout_kind: String, at_rank: int) -> String:
	return "a challenger" if bout_kind == "defend" else str(FIGHTERS[clampi(at_rank, 0, FIGHTERS.size() - 1)][0])


func _net() -> Node:
	return get_node("/root/Net")


func _spawn(isl: Node3D, sand: Vector3) -> void:
	var net := _net()
	captain_key = net.key_of(captain)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["arena", captain_key, rank, kind, _n])
	_n += 1
	var lk: Dictionary = CharacterLook.random_look(rng)
	var weapon: String
	var skill: float
	var kicks := false
	if kind.begins_with("master:"):
		var m: Array = MASTERS[kind.substr(7)]
		lk.merge(m[3], true)
		lk["name"] = str(m[0]).get_slice(",", 0)
		weapon = m[1]
		skill = m[2]
		kicks = str(m[4]) == "black_leg"
	elif kind == "brawl":
		lk.merge(BRAWLER[1], true)
		lk["name"] = str(BRAWLER[0])
		weapon = ""
		skill = BRAWLER[2]
	elif kind == "defend":
		lk["name"] = "Challenger"
		weapon = str(DEFEND_WEAPONS[rng.randi() % DEFEND_WEAPONS.size()])
		skill = DEFEND_SKILL
	else:
		var f: Array = FIGHTERS[rank]
		lk.merge(f[3], true)
		lk["name"] = str(f[0]).get_slice(",", 0)
		weapon = f[1]
		skill = f[2]
	# the rival opposite the captain across the sand's middle
	var away := captain.global_position - sand
	away.y = 0.0
	away = away.normalized() if away.length() > 0.5 else Vector3.LEFT
	var at := sand - away * APART + Vector3.UP * 0.5
	spot = sand
	if kind.begins_with("master:") or kind == "brawl":
		at = sand + Vector3.UP * 0.5
	var rname := "ArenaRival_%d" % _n
	net.everyone("_all_spawn_rival", [net.key_of(isl), rname, lk, weapon, at, atan2(away.x, away.z), skill])
	rival = isl.get_node_or_null(rname) as Player
	if rival == null:
		phase = "done"
		queue_free()
		return
	if kicks:
		rival.learn_black_leg()
		rival.set_kicks(true)
	net.everyone("_all_practice", [[captain_key, net.key_of(rival)], true])
	var brain = rival.get_node("Brain")
	if kind.begins_with("master:"):
		# the pupil drills on the spot until the captain comes to them
		phase = "wait"
		brain.order = "rest"
		brain.rest_at = spot
		brain.activity = "train"
		brain.look_node = captain
		brain.target = captain
		return
	brain.order = "fight"
	brain.target = captain


## The captain's ready (Net "go"): both face each other and bow, then the count.
func begin() -> void:
	if phase != "wait" or not is_instance_valid(rival):
		return
	phase = "bow"
	_beat = 4
	_beat_t = BOW_SECS
	var brain = rival.get_node("Brain")
	brain.order = "hold"
	var to := captain.global_position - rival.global_position
	to.y = 0.0
	if to.length() > 0.05:
		rival.player_model.rotation.y = atan2(to.x, to.z)
	_net().everyone("_all_spar_beat", [captain_key, _net().key_of(rival), "bow"])


## Where a pupil spars (the flagged ground on Brinehollow's shrine terrace, 1.25.4) or the quay brawl is fought (INF
## off Brinehollow).
static func spar_spot(tree: SceneTree, bout_kind: String) -> Vector3:
	var isl: StarterIsland = tree.root.get_node("Story").island()
	if isl == null:
		return Vector3.INF
	return isl.ground_of("brawl" if bout_kind == "brawl" else "spar")


## On the captain's own machine: the pupil asks if they're ready (a talk, "spar:go" or not yet).
static func spar_ask(me: Player, key: String, rival: Node, who: String) -> void:
	if me == null or me.get_node("/root/Net").key_of(me) != key:
		return
	var dlg := me.get_node("/root/Dialogue")
	if not dlg.dialogue_event.is_connected(_on_spar_event):
		dlg.dialogue_event.connect(_on_spar_event)
	dlg.define("spar", {"speaker": who.get_slice(",", 0), "voice": 1.15, "start": "ask", "nodes": {
		"ask": {"text": ["You came. Bare hands, no blades. Bow first, then we fight. Ready?"], "choices": [
			{"text": "Ready.", "next": "go"}, {"text": "Not yet.", "next": "later"}]},
		"go": {"text": ["Then bow."], "event": "spar:go", "next": "end"},
		"later": {"text": ["I'll be here. Drilling."], "next": "end"}}})
	dlg.start("spar", rival)


static func _on_spar_event(ev: String) -> void:
	if ev == "spar:go":
		var net := (Engine.get_main_loop() as SceneTree).root.get_node("Net")
		net.request_arena("go", 0)


## A spar's beat on every screen: both bow ("bow"), then the count on the captain's own screen (3, 2, 1, then Fight!).
static func spar_beat(me: Player, key: String, rival: Node, beat: String) -> void:
	var tree := (Engine.get_main_loop() as SceneTree)
	var net := tree.root.get_node("Net")
	var cap := net.node_of(key) as Player
	if beat == "bow":
		for p in [cap, rival]:
			if p is Player and (p == me or not (p as Player).is_local or p == rival):
				(p as Player).body_model.play("emote_bow", ActionSpecs.length("emote_bow"))
		return
	if me == null or net.key_of(me) != key:
		return
	var hud = Duel.ensure(tree)._hud()
	var n := int(beat)
	var at := me.global_position + Vector3(0, 1.6, 0)
	if n > 0:
		hud.big(str(n), "")
		tree.root.get_node("FX").sfx("blip_high", at, -8.0, 0.0, 1.0 + 0.1 * (3 - n))
	else:
		hud.big("Fight!", "")
		tree.root.get_node("FX").sfx("parry", at, -4.0, 0.0, 0.9)


func _beaten(p: Player) -> bool:
	return not is_instance_valid(p) or not p.is_standing() or p.health_component.current_health <= p.health_component.max_health * END_AT


func _physics_process(delta: float) -> void:
	match phase:
		"wait":
			if not is_instance_valid(captain) or not is_instance_valid(rival):
				_finish(false)
				return
			var d := captain.global_position.distance_to(rival.global_position)
			var brain = rival.get_node("Brain")
			brain.activity = "watch" if d < ASK_AGAIN_R else "train"
			if d < ASK_R and not _asked:
				_asked = true
				_net().everyone("_all_spar_ask", [captain_key, _net().key_of(rival), str(MASTERS[kind.substr(7)][0])])
			elif d > ASK_AGAIN_R:
				_asked = false
		"bow", "count":
			if not is_instance_valid(captain) or not is_instance_valid(rival):
				_finish(false)
				return
			_beat_t -= delta
			if _beat_t <= 0.0:
				_beat -= 1
				_beat_t = 1.0
				_net().everyone("_all_spar_beat", [captain_key, _net().key_of(rival), str(_beat)])
				if _beat <= 0:
					phase = "fight"
					var brain = rival.get_node("Brain")
					brain.order = "fight"
					brain.target = captain
		"fight":
			if not is_instance_valid(captain):
				_finish(false)
			elif _beaten(rival):
				_finish(true)
			elif _beaten(captain):
				_finish(false)
			elif _held():
				_leash(delta)
		"leave":
			_leave_t -= delta
			if _leave_t <= 0.0:
				phase = "done"
				if is_instance_valid(rival):
					_net().everyone("_all_rival_gone", [_net().key_of(rival)])
				queue_free()


## A spar or the quay brawl: fought on its ground, not wherever a blow carries them.
func _held() -> bool:
	return kind.begins_with("master:") or kind == "brawl"


## The 1.25.4 spar fix: a rival knocked off the ground (into a wall, between buildings, down the flank) for LEASH_SECS
## steps back onto it; a captain who walks off forfeits.
func _leash(delta: float) -> void:
	if spot.distance_to(captain.global_position) > FORFEIT_R:
		_finish(false)
		return
	var off := spot.distance_to(rival.global_position) > LEASH_R and rival.global_position.distance_to(captain.global_position) > APART_STUCK
	_off_t = _off_t + delta if off else 0.0
	if _off_t < LEASH_SECS or rival.body_model.ragdoll != null:
		return
	_off_t = 0.0
	var back := captain.global_position - spot
	back.y = 0.0
	back = back.normalized() * 2.5 if back.length() > 0.5 else Vector3.ZERO
	rival.global_position = spot + back + Vector3.UP * 0.3
	rival.velocity = Vector3.ZERO
	rival.reset_physics_interpolation()
	_net().fx("puff", [rival.global_position, "dust_low", 6, 0.5, 0.6, Color(1, 1, 1, 0.8), 0.6])


func _finish(won: bool) -> void:
	phase = "leave"
	_leave_t = LEAVE_AFTER
	if is_instance_valid(rival):
		if not rival.is_standing():
			Duel.stand_up(rival, rival.health_component.max_health * 0.3, 0.0)
		rival.get_node("Brain").order = "hold"
	var net := _net()
	if not won:
		net.everyone("_all_rival_stand", [])
	net.everyone("_all_practice", [[captain_key], false])
	net.everyone("_all_arena_result", [captain_key, kind, rank, won, randi()])
	ended.emit(won)


## On every screen (Net._all_arena_result): the captain the bout was for, if it's this machine's, is paid and moves
## up; everyone hears the crowd. `roll` is the host's (the same prize on every screen).
static func result(me: Player, key: String, bout_kind: String, at_rank: int, won: bool, roll: int) -> void:
	if me == null or me.get_node("/root/Net").key_of(me) != key:
		return
	if bout_kind == "brawl":
		me.get_tree().call_group("hud", "show_toast", "Harl stays down. Word gets round the quay fast." if won else "Flat on the stones. Harl laughs. Get up and try him again.")
	elif bout_kind.begins_with("master:"):
		_master_result(me, bout_kind.substr(7), won)
	if bout_kind == "brawl" or bout_kind.begins_with("master:"):
		me.get_node("/root/Story").bout_done(bout_kind, won)
		return
	if not won:
		me.get_tree().call_group("hud", "show_toast", "Beaten on the sand. The crowd groans. Try again when you're ready.")
		return
	var gold := ItemDB.get_item("gold")
	me.inventory_component.add_item(gold, purse(bout_kind, at_rank))
	if bout_kind == "defend":
		me.arena_defended_day = _day(me)
		me.get_tree().call_group("hud", "show_banner", "The title holds!", "%d gold from the purse. Champion still." % DEFEND_PURSE, true)
		return
	me.arena_rank = maxi(me.arena_rank, at_rank + 1)
	if at_rank + 1 >= FIGHTERS.size():
		me.inventory_component.add_item(ItemDB.get_item(TROPHY), 1)
		me.get_tree().call_group("hud", "show_banner", "Champion of the Arena!", "%d gold, the Champion's Sabre, and the crowd on its feet." % purse(bout_kind, at_rank), true)
		var rng := RandomNumberGenerator.new()
		rng.seed = roll
		if DevilFruits.IN_WORLD and rng.randf() < FRUIT_CHANCE:
			var ids: Array = DevilFruits.FRUITS.keys()
			var fruit := ItemDB.get_item(str(DevilFruits.FRUITS[ids[rng.randi() % ids.size()]]["item"]))
			if fruit:
				me.inventory_component.add_item(fruit, 1)
	else:
		me.get_tree().call_group("hud", "show_banner", "Victory on the sand!", "%d gold. Next: %s." % [purse(bout_kind, at_rank), fighter_name("ladder", at_rank + 1)], true)


## A master's test passed or failed: passed, they teach the tree (black leg: the kicks, Player.learn_black_leg).
static func _master_result(me: Player, tree: String, won: bool) -> void:
	if not won:
		me.get_tree().call_group("hud", "show_toast", "Not yet. Come back when your legs remember.")
		return
	match tree:
		"black_leg":
			me.learn_black_leg()
	me.get_node("/root/Dialogue").set_flag("master_" + tree)
	me.get_tree().call_group("hud", "show_banner", "Black Leg learned!", "Empty your hands to kick: click the empty hand in your bag (I) for feet or fists.", true)


static func _day(n: Node) -> int:
	return int(n.get_node("/root/Weather").day())
