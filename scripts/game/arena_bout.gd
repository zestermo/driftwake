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
## A master's test (1.23, "masters teach trees"; kind "master:<tree>"): their pupil steps up wherever you stand;
## beat them and the master teaches you the tree. [name, weapon ("": bare hands), skill, look, the style they fight in].
const MASTERS := {
	"black_leg": ["Tomo, Bao's pupil", "", 0.45, {"coat": "none", "hat": "headband", "top": "kimono", "sleeves": "long"}, "black_leg"],
}
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
var _leave_t := 0.0
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
	brain.order = "fight"
	brain.target = captain


func _beaten(p: Player) -> bool:
	return not is_instance_valid(p) or not p.is_standing() or p.health_component.current_health <= p.health_component.max_health * END_AT


func _physics_process(delta: float) -> void:
	match phase:
		"fight":
			if not is_instance_valid(captain):
				_finish(false)
			elif _beaten(rival):
				_finish(true)
			elif _beaten(captain):
				_finish(false)
		"leave":
			_leave_t -= delta
			if _leave_t <= 0.0:
				phase = "done"
				if is_instance_valid(rival):
					_net().everyone("_all_rival_gone", [_net().key_of(rival)])
				queue_free()


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
	if bout_kind.begins_with("master:"):
		_master_result(me, bout_kind.substr(7), won)
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
