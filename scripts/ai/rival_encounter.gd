class_name RivalEncounter
extends Node
## A rival crew's visit (docs/rival_crews_plan.md, docs/v1_19_plan.md), run by the host: the crew turns up in a line
## facing the captains, the meeting plays as a cutscene (their lines by how you've met before), then duels in turn:
## one rival per captain at a time (solo: the best match for your weapon first, the captain last), the rest ringing
## the fight and taunting. Their captain hurt badly enough calls a retreat (they run off; gold and maybe a trait
## weapon for the captains); every captain down and they plunder (a share of each one's gold), gloat and go. The
## crew's record (met, won, lost) is saved in GameManager.rivals; they come back stronger.

signal ended(result: String)   # "won" (the captains), "lost", "gone"

## Their captain under this share of health calls the retreat.
const RETREAT_AT := 0.3
## What they take from each beaten captain's gold.
const PLUNDER := 0.25
## How far in front of the captain they turn up.
const ARRIVE_AT := 14.0
## A watching rival barks a taunt every so often (seconds).
const TAUNT_EVERY := Vector2(4.0, 8.0)
## Gold for a won fight per crew member, and the chance of a trait weapon.
const GOLD_EACH := 18
const WEAPON_CHANCE := 0.35

var crew_id := ""
var rivals: Array = []          # Player (AI), the captain last
var info: Array = []            # RivalCrews.members() entries, the same order
var phase := "meet"             # meet, fight, retreat, plunder, done
## The meeting's lines: meet, again, grudge_won (they won last), grudge_lost (you did).
var moment := ""
var result := ""
var rng := RandomNumberGenerator.new()
var _active := {}               # captain -> rival fighting them
var _queue: Array = []
var _taunt_at := 0.0
var _t := 0.0
var _hp_seen := {}
var _casts_seen := {}
var _leave_t := 0.0


## The host's start of a crew's visit near `near` (null if the crew's unknown or one's already here).
static func start(near: Player, crew: String) -> RivalEncounter:
	if not RivalCrews.CREWS.has(crew) or near.get_tree().get_first_node_in_group("rival_encounter"):
		return null
	var e := RivalEncounter.new()
	e.name = "RivalEncounter_" + crew
	e.crew_id = crew
	near.get_tree().current_scene.add_child(e)
	e._arrive(near)
	return e


func _gm() -> Node:
	return get_node("/root/GameManager")


func _ready() -> void:
	add_to_group("rival_encounter")
	rng.seed = hash([crew_id, randi()])


func record() -> Dictionary:
	var r: Dictionary = _gm().rivals.get(crew_id, {"met": 0, "won": 0, "lost": 0})
	_gm().rivals[crew_id] = r
	return r


func _arrive(near: Player) -> void:
	var rec := record()
	var tier := int(rec["met"])
	info = RivalCrews.members(crew_id, int(_gm().chain_seed), tier)
	var fwd := -near.player_model.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var side := fwd.cross(Vector3.UP).normalized()
	var centre := near.global_position + fwd * ARRIVE_AT
	var parent := near.get_parent()
	var net := get_node("/root/Net")
	var yaw := atan2(fwd.x, fwd.z) + PI
	for i in range(info.size()):
		var m: Dictionary = info[i]
		# the captain in the middle, a step ahead; the mates spread either side
		var slot := 0.0 if m["captain"] else (float(i / 2 + 1) * 2.2 * (1.0 if i % 2 == 0 else -1.0))
		var at := centre + side * slot - (fwd * 1.0 if m["captain"] else Vector3.ZERO) + Vector3.UP * 0.5
		var rname := "Rival_%s_%d" % [crew_id, i]
		net.everyone("_all_spawn_rival", [net.key_of(parent), rname, m["look"], m["weapon"], at, yaw, float(m["skill"])])
		var r := parent.get_node_or_null(rname) as Player
		if r == null:
			continue
		var brain = r.get_node("Brain")
		brain.order = "hold"
		var k := (1.0 + 0.15 * tier) * (1.8 if m["captain"] else 1.0)
		r.hp_k = k
		r._recalc_stats()
		r.health_component.current_health = r.health_component.max_health
		r.defeated.connect(_on_defeated.bind(r))
		rivals.append(r)
	rec["met"] = tier + 1
	moment = "meet"
	if tier > 0:
		moment = "grudge_won" if str(rec.get("last", "")) == "lost" else ("grudge_lost" if str(rec.get("last", "")) == "won" else "again")
	var mates := []
	for r in rivals.slice(0, rivals.size() - 1):
		mates.append(net.key_of(r))
	var you = get_tree().get_first_node_in_group("player")
	net.everyone("_all_cutscene", ["rival_meet", [crew_id, moment, net.key_of(rivals[-1]), mates, net.key_of(you)]])
	var c := Cutscene.active
	if c:
		c.finished.connect(func(_skipped): _fight())
	else:
		_fight()


## The meeting's shots: a wide look from behind the captain at the crew, then each line on its speaker.
## args: [crew id, moment, captain key, [mate keys], your key]
static func meet_shots(tree: SceneTree, args: Array) -> Array:
	var net := tree.root.get_node("Net")
	var crew := str(args[0])
	var c: Dictionary = RivalCrews.CREWS.get(crew, {})
	if c.is_empty():
		return []
	var cap := net.node_of(str(args[2])) as Player
	var mates := []
	for k in args[3]:
		var m := net.node_of(str(k)) as Player
		if m:
			mates.append(m)
	var you := net.node_of(str(args[4])) as Player
	if cap == null or you == null:
		return []
	var lines: Array = (c["lines"] as Dictionary).get(str(args[1]), c["lines"]["meet"])
	var shots := [{"secs": 2.2, "cam": [you.player_model, cap], "off": Vector3(0.9, 2.0, -3.2), "fov": 55.0,
		"to": [you.player_model, cap]}]
	var mi := 0
	for l in lines:
		var who: Player = cap
		var nm := str(c["captain"])
		var pitch := float(c["pitch"])
		match str(l[0]):
			"mate":
				if mates.is_empty():
					continue
				who = mates[mi % mates.size()]
				mi += 1
				nm = str(who.net_profile.get("name", "Mate"))
				pitch = 1.05
			"you":
				who = you
				nm = you.display_name()
				pitch = 1.25
		shots.append({"cam": [who.player_model, who], "off": Vector3(0.9, 1.6, 3.2), "fov": 50.0,
			"say": {"who": who, "name": nm, "text": str(l[1]), "pitch": pitch}})
	return shots


func _captains() -> Array:
	return get_tree().get_nodes_in_group("players").filter(func(c): return c is Player and is_instance_valid(c))


func _standing(c: Player) -> bool:
	return c.health_component.current_health > 0.0 and c.current_state_name() != "Downed" and not c.bleeding


## The duels begin: the queue (the best match for the strongest captain's weapon first, the captain last).
func _fight() -> void:
	if phase != "meet":
		return
	phase = "fight"
	var lead: Player = get_tree().get_first_node_in_group("player")
	var wc := lead.weapon_class() if lead else ""
	_queue = rivals.slice(0, rivals.size() - 1)
	_queue.sort_custom(func(a, b): return int(a.weapon_class() == wc) > int(b.weapon_class() == wc))
	_queue.append(rivals[-1])
	for r in rivals:
		var b = r.get_node("Brain")
		b.order = "watch"
		b.watch_r = rng.randf_range(8.0, 11.0)
	_taunt_at = rng.randf_range(TAUNT_EVERY.x, TAUNT_EVERY.y)


func _physics_process(delta: float) -> void:
	_t += delta
	match phase:
		"fight":
			_fight_tick(delta)
		"retreat", "plunder":
			_leave_t -= delta
			if _leave_t <= 0.0:
				_gone()


func _fight_tick(delta: float) -> void:
	var caps := _captains()
	var up := caps.filter(func(c): return _standing(c))
	if up.is_empty():
		_lose()
		return
	# one rival on each captain still up, from the queue
	for c in caps:
		var r = _active.get(c)
		if r != null and (not is_instance_valid(r) or not _standing(r) or not _standing(c)):
			_active.erase(c)
	for c in up:
		if _active.has(c):
			continue
		var next = _next_up()
		if next == null:
			break
		_active[c] = next
		var b = next.get_node("Brain")
		b.order = "fight"
		b.target = c
		if rivals.find(next) == rivals.size() - 1:
			_say(next, RivalCrews.line(crew_id, "taunt", rng))
	for r in rivals:
		if not is_instance_valid(r) or not _standing(r):
			continue
		var b = r.get_node("Brain")
		if b.order == "watch":
			var fighting = _active.values()
			b.watch_center = fighting[0] if not fighting.is_empty() else up[0]
		_react(r, b)
	# the captain hurt badly enough: retreat
	var cap = rivals[-1]
	if is_instance_valid(cap) and cap.health_component.current_health <= cap.health_component.max_health * RETREAT_AT:
		_retreat()
		return
	_taunt_at -= delta
	if _taunt_at <= 0.0:
		_taunt_at = rng.randf_range(TAUNT_EVERY.x, TAUNT_EVERY.y)
		var watching := rivals.filter(func(r): return is_instance_valid(r) and _standing(r) and r.get_node("Brain").order == "watch")
		if not watching.is_empty():
			var w = watching[rng.randi() % watching.size()]
			_say(w, RivalCrews.line(crew_id, "taunt", rng, w == rivals[-1]))


func _next_up() -> Player:
	while not _queue.is_empty():
		var r = _queue[0]
		if is_instance_valid(r) and _standing(r) and not r in _active.values():
			_queue.pop_front()
			return r
		_queue.pop_front()
	return null


## Lines as things happen to a rival: hurt, its ultimate.
func _react(r: Player, b) -> void:
	var hp := r.health_component.current_health
	var was := float(_hp_seen.get(r, hp))
	_hp_seen[r] = hp
	var is_cap: bool = r == rivals[-1]
	if hp < was - 1.0 and rng.randf() < 0.3:
		_say(r, RivalCrews.line(crew_id, "hurt", rng, is_cap))
	var casts := int(b.casts)
	if casts > int(_casts_seen.get(r, 0)) and is_cap and r.power.ult < PowerComponent.ULT_MAX * 0.05:
		_say(r, RivalCrews.line(crew_id, "ult", rng))
	_casts_seen[r] = casts


func _say(r: Player, text: String) -> void:
	if text == "" or not is_instance_valid(r):
		return
	var pitch := float(info[rivals.find(r)]["pitch"]) if rivals.has(r) else 1.0
	get_node("/root/Net").fx("speech", [r, text, pitch])


func _on_defeated(r: Player) -> void:
	if phase != "fight":
		return
	if r == rivals[-1]:
		# (their captain doesn't die: the retreat)
		Duel.stand_up(r, r.health_component.max_health * 0.1, 0.0)
		_retreat()
		return
	r.get_node("Brain").order = "hold"
	_say(r, RivalCrews.line(crew_id, "down", rng, false))
	if is_instance_valid(rivals[-1]):
		_say(rivals[-1], RivalCrews.line(crew_id, "mate_down", rng))


## Their captain calls it: everyone runs for the shore and the captains are paid.
func _retreat() -> void:
	if phase != "fight":
		return
	phase = "retreat"
	result = "won"
	_say(rivals[-1], RivalCrews.line(crew_id, "retreat", rng))
	_scatter()
	var at: Vector3 = rivals[-1].global_position if is_instance_valid(rivals[-1]) else Vector3.ZERO
	var net := get_node("/root/Net")
	net.coins(at, GOLD_EACH * rivals.size())
	if rng.randf() < WEAPON_CHANCE:
		var w := str(info[-1]["weapon"])
		var traits: Array = WeaponTraits.TRAITS.keys()
		var item := ItemDB.with_trait(w, str(traits[rng.randi() % traits.size()]))
		if item:
			net.drop_items([[SaveGame.item_ref(item), 1]], at + Vector3(0, 0.5, 0))
	var rec := record()
	rec["won"] = int(rec["won"]) + 1
	rec["last"] = "won"
	_leave_t = 6.0


## Every captain down: they take a share of each one's gold, gloat, and go; the captains get back up.
func _lose() -> void:
	phase = "plunder"
	result = "lost"
	_say(rivals[-1], RivalCrews.line(crew_id, "gloat", rng))
	get_node("/root/Net").everyone("_all_rival_plunder", [PLUNDER, str(RivalCrews.CREWS[crew_id]["name"])])
	_scatter()
	var rec := record()
	rec["lost"] = int(rec["lost"]) + 1
	rec["last"] = "lost"
	_leave_t = 6.0


## Off they go, away from the captains (the downed get up and go too).
func _scatter() -> void:
	var lead: Node3D = get_tree().get_first_node_in_group("player")
	for r in rivals:
		if not is_instance_valid(r):
			continue
		if not _standing(r):
			Duel.stand_up(r, r.health_component.max_health * 0.2, 0.0)
		var b = r.get_node("Brain")
		var away: Vector3 = r.global_position - (lead.global_position if lead else r.global_position + Vector3.FORWARD)
		away.y = 0.0
		b.flee_to = r.global_position + away.normalized() * 45.0
		b.order = "flee"


func _gone() -> void:
	if phase == "done":
		return
	phase = "done"
	var net := get_node("/root/Net")
	for r in rivals:
		if is_instance_valid(r):
			net.everyone("_all_rival_gone", [net.key_of(r)])
	if result == "lost":
		net.everyone("_all_rival_stand", [])
	ended.emit(result)
	queue_free()
