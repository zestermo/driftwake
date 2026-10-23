class_name Duel
extends Node
## Captain against captain (the player menu's Duel), and a captain's kit for Inspect. One node on every
## machine at /root/Net/Duel (made with the local captain: ensure()), so its RPCs find it everywhere.
## The host keeps `state` (open challenges and duels) and sends all of it to everyone on every change; each
## machine plays its own part from it: the challenge prompt, the countdown, the opponent's bar, letting the
## pair's hits through (the opponent's hurtbox joins the enemies' layer here), going down instead of dying,
## the result, the XP and getting back up. spare() and stand_up() are the "downed, not dead" rules an arena
## can reuse. Names no game class (it's made at boot by nothing, but hitbox.gd and player.gd name it).

const ANSWER_TIME := 15.0
const COUNTDOWN := 3.0
const FIGHT_TIME := 180.0
const RING := 35.0
const REVIVE_AFTER := 3.0
const DAMAGE_K := 0.6
## A captain beaten with a rival crew this close is spared (downed, not dead): the crew plunders instead.
const RIVAL_SPARE_R := 40.0
## Of the level the winner is on (at least MIN_XP).
const XP_SHARE := 0.02
const MIN_XP := 10
const WATCH_RANGE := 45.0
const ENEMY_LAYER := 32
const HUD := "res://scripts/ui/duel_hud.gd"
const SAVE := "res://scripts/game/save_game.gd"

signal kit_received(id: int, kit: Dictionary)

static var inst: Duel

## {"asks": {challenger id: {"to": id, "until": t}}, "duels": {duel id: {"a", "b", "centre", "start", "end", "winner"}}}
## winner: -1 still on, 0 a draw, else the winner's id.
var state := {"asks": {}, "duels": {}}
var hud: Node
## Net (by node: a --script test names this class before the autoloads exist).
var net: Node
var _seq := 0
var _clock := 0.0
## What this machine has done for each duel it's in or watching (duel id -> its notes).
var _mine := {}
## The challenger we've just answered (their challenge stays in our state until the host's word comes back).
var _answered := -1
var _was_active := false


static func ensure(tree: SceneTree) -> Duel:
	if inst == null or not is_instance_valid(inst):
		inst = Duel.new()
		inst.name = "Duel"
		inst.net = tree.root.get_node("Net")
		inst.net.add_child(inst)
	return inst


func _exit_tree() -> void:
	if inst == self:
		inst = null


## The duel's clock: the shared session clock in co-op, game time alone.
func now() -> float:
	return float(net.time()) if net.active else _clock


func me() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func id_of(p: Node) -> int:
	return net.my_id() if p.is_local else int(p.net_id)


func captain(id: int) -> Node3D:
	for p in get_tree().get_nodes_in_group("players"):
		if id_of(p) == id and (p as Node).is_inside_tree():
			return p
	return null


func name_of(id: int) -> String:
	var p := captain(id)
	return str(p.display_name()) if p else "A captain"


## The duel `id` is in ({} none), with its own id under "id".
func duel_of(id: int) -> Dictionary:
	for k in state["duels"].keys():
		var d: Dictionary = state["duels"][k]
		if int(d["a"]) == id or int(d["b"]) == id:
			var out := d.duplicate()
			out["id"] = int(k)
			return out
	return {}


## Who challenged `id` and is waiting for an answer (-1 nobody).
func asker_of(id: int) -> int:
	for a in state["asks"].keys():
		if int(state["asks"][a]["to"]) == id:
			return int(a)
	return -1


func asking(a: int) -> int:
	return int(state["asks"][a]["to"]) if state["asks"].has(a) else -1


## In a duel, or a challenge to answer.
func busy(id: int) -> bool:
	return not duel_of(id).is_empty() or asker_of(id) >= 0


func fighting(d: Dictionary) -> bool:
	return not d.is_empty() and int(d["winner"]) == -1 and now() >= float(d["start"])


func opponent(d: Dictionary, id: int) -> int:
	return int(d["b"]) if int(d["a"]) == id else int(d["a"])


## Two captains fighting each other right now (their hits land on each other; nobody else's do).
static func foes(a: Node, b: Node) -> bool:
	if inst == null or a == null or b == null or a == b or not a.is_in_group("players") or not b.is_in_group("players"):
		return false
	var d := inst.duel_of(inst.id_of(a))
	return inst.fighting(d) and inst.opponent(d, inst.id_of(a)) == inst.id_of(b)


## Our skills strike "from" a stand-in node (PowerComponent's BlastOrigin: the push's direction); on a duel
## opponent the blow is ours, or their machine wouldn't know whose it was.
static func blame(target: Node, attacker: Node) -> Node:
	if inst == null or attacker == null or target == null or not target.is_in_group("players") or target.is_local \
			or attacker.is_in_group("players"):
		return attacker
	var p := inst.me()
	return p if p and attacker == p.power.get("_proxy_node") else attacker


## A blow from the duel opponent, lightened.
static func soften(hit: HitData) -> HitData:
	var h := hit.duplicate() as HitData
	h.damage *= DAMAGE_K
	return h


## Damage that would finish off a captain mid-duel, whatever its source (a bleed or burn names none): down, not dead (true: it's taken care of).
static func beaten(p: Node, dmg: float) -> bool:
	if p == null or not p.is_in_group("players") or dmg < p.health_component.current_health:
		return false
	# beaten with a rival crew about: down, not dead (they plunder you instead: RivalEncounter). Every machine has the
	# rivals (the host's AI, the guests' puppets), so a guest's captain is spared on its own machine too.
	if p.is_inside_tree():
		for r in p.get_tree().get_nodes_in_group("rivals"):
			if (r as Node3D).global_position.distance_to(p.global_position) < RIVAL_SPARE_R:
				spare(p)
				return true
	if inst == null:
		return false
	if not inst.fighting(inst.duel_of(inst.id_of(p))):
		return false
	spare(p)
	return true


## Downed, not dead: no death, no grave, nothing lost; down until stand_up().
static func spare(p: Node) -> void:
	var hc = p.health_component
	hc.current_health = 0.0
	hc.health_changed.emit(0.0, hc.max_health)
	p.state_machine.force_state("Downed", {"dead": true, "velocity": p.get("_last_hit_velocity")})


## Back on your feet with `hp` and `energy` (a spared captain gets up from where they lie).
static func stand_up(p: Node, hp: float, energy: float) -> void:
	if p.current_state_name() == "Downed":
		var ds = p.state_machine.current_state
		ds.set("dead", false)
		ds.set("timer", maxf(float(ds.get("timer")), 1.0))
	var hc = p.health_component
	hc.current_health = clampf(hp, 1.0, hc.max_health)
	hc.health_changed.emit(hc.current_health, hc.max_health)
	p.power.energy = minf(energy, p.power.max_energy())


func xp_for(p: Node) -> int:
	var lv: int = p.progression.level
	return maxi(MIN_XP, roundi(float(p.progression.get_script().xp_to_next(lv)) * XP_SHARE))


# ==========================================================================
# Asking the host
# ==========================================================================
func _sfx(sound: String, at: Vector3, db: float, jitter: float, pitch: float) -> void:
	get_node("/root/FX").sfx(sound, at, db, jitter, pitch)


## Our captain challenges captain `to`.
func challenge(to: int) -> void:
	if net.is_host():
		_challenge(net.my_id(), to)
	else:
		_want_challenge.rpc_id(1, to)


## Our answer to the challenge we were sent.
func answer(accept: bool) -> void:
	_answered = asker_of(net.my_id())
	var p := me()
	var at := p.global_position if p else Vector3.ZERO
	if net.is_host():
		_answer(net.my_id(), accept, at)
	else:
		_want_answer.rpc_id(1, accept, at)


## A guest's requests: they speak for themselves only.
@rpc("any_peer", "call_remote", "reliable")
func _want_challenge(to: int) -> void:
	if net.is_host():
		_challenge(multiplayer.get_remote_sender_id(), to)


@rpc("any_peer", "call_remote", "reliable")
func _want_answer(accept: bool, at: Vector3) -> void:
	if net.is_host():
		_answer(multiplayer.get_remote_sender_id(), accept, at)


## (host) `a` challenges `b`.
func _challenge(a: int, b: int) -> void:
	if a == b or captain(b) == null:
		return
	if not duel_of(a).is_empty() or not duel_of(b).is_empty():
		_tell(a, "%s is already in a duel" % name_of(b) if duel_of(a).is_empty() else "You're already in a duel")
		return
	var other := asker_of(b)
	if other >= 0 and other != a:
		_tell(a, "%s has a challenge to answer" % name_of(b))
		return
	if asker_of(a) >= 0:
		_tell(a, "Answer %s's challenge first" % name_of(asker_of(a)))
		return
	state["asks"][a] = {"to": b, "until": now() + ANSWER_TIME}
	_send()
	_tell(a, "You challenged %s to a duel" % name_of(b))


## (host) `b` answers whoever challenged them, standing at `at` (the ring's centre).
func _answer(b: int, accept: bool, at: Vector3) -> void:
	var a := asker_of(b)
	if a < 0:
		return
	state["asks"].erase(a)
	if not accept:
		_send()
		_tell(a, "%s declined the duel" % name_of(b))
		return
	if not duel_of(a).is_empty() or not duel_of(b).is_empty() or captain(a) == null:
		_send()
		_tell(b, "The duel's off")
		return
	_seq += 1
	state["asks"].erase(b)
	state["duels"][_seq] = {"a": a, "b": b, "centre": at, "start": now() + COUNTDOWN, "end": -1.0, "winner": -1}
	_send()


func _tell(id: int, text: String) -> void:
	if id == net.my_id():
		_told(text)
	elif net.active:
		_told.rpc_id(id, text)


@rpc("authority", "call_remote", "reliable")
func _told(text: String) -> void:
	get_tree().call_group("hud", "show_toast", text)


## The whole state to everyone in the world (a captain still loading has no Duel yet: they get the next one).
func _send() -> void:
	if not net.active:
		return
	for id in net.players.keys():
		if int(id) != net.my_id():
			_state.rpc_id(int(id), state)


@rpc("authority", "call_remote", "reliable")
func _state(s: Dictionary) -> void:
	state = s


# ==========================================================================
# The host's referee
# ==========================================================================
func _process(delta: float) -> void:
	_clock += delta
	# a session started or ended: nothing from before carries over
	if net.active != _was_active:
		_was_active = net.active
		state = {"asks": {}, "duels": {}}
		_mine.clear()
	if net.is_host():
		_referee()
	_play_all()


func _referee() -> void:
	var t := now()
	var changed := false
	for a in state["asks"].keys():
		var ask: Dictionary = state["asks"][a]
		if t > float(ask["until"]) or captain(int(a)) == null or captain(int(ask["to"])) == null:
			state["asks"].erase(a)
			changed = true
			_tell(int(a), "%s didn't answer" % name_of(int(ask["to"])))
	for k in state["duels"].keys():
		var d: Dictionary = state["duels"][k]
		if int(d["winner"]) == -1:
			var res := _judge(d, t)
			if res != -1:
				d["winner"] = res
				d["end"] = t
				changed = true
		elif t >= float(d["end"]) + REVIVE_AFTER + 0.5:
			state["duels"].erase(k)
			changed = true
	if changed:
		_send()


## -1 still on, 0 a draw, else the winner: the other one went down; walked off, left or ran out of time: a draw.
func _judge(d: Dictionary, t: float) -> int:
	var c: Vector3 = d["centre"]
	for id in [int(d["a"]), int(d["b"])]:
		var p := captain(id)
		if p == null:
			return 0
		if t < float(d["start"]):
			continue
		if not p.is_standing():
			return opponent(d, id)
		if Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length() > RING:
			return 0
	if t >= float(d["start"]) + FIGHT_TIME:
		return 0
	return -1


# ==========================================================================
# Every machine: its own part
# ==========================================================================
func _play_all() -> void:
	var p := me()
	if p == null:
		return
	var my: int = net.my_id()
	var asker := asker_of(my)
	if asker != _answered:
		_answered = -1
	if asker >= 0 and asker != _answered:
		_hud().ask(name_of(asker), clampf((float(state["asks"][asker]["until"]) - now()) / ANSWER_TIME, 0.0, 1.0))
	elif hud != null:
		hud.ask("", 0.0)
	for k in state["duels"].keys():
		_play(int(k), state["duels"][k], p, my)
	for k in _mine.keys():
		if not state["duels"].has(k):
			_finish(int(k), p)


func _hud() -> Node:
	if hud == null or not is_instance_valid(hud):
		hud = load(HUD).new()
		hud.name = "DuelHUD"
		hud.duel = self
		add_child(hud)
	return hud


func _play(id: int, d: Dictionary, p: Node3D, my: int) -> void:
	var duelist := my == int(d["a"]) or my == int(d["b"])
	var c: Vector3 = d["centre"]
	if not duelist and not _mine.has(id) and p.global_position.distance_to(c) > WATCH_RANGE:
		return
	if not _mine.has(id):
		_mine[id] = {"duelist": duelist, "hp": p.health_component.current_health, "energy": p.power.energy,
			"beat": -1, "over": false, "done": false}
	var m: Dictionary = _mine[id]
	if m["done"]:
		return
	var t := now()
	var opp := captain(opponent(d, my)) if duelist else null
	var h := _hud()
	if int(d["winner"]) == -1:
		var n := ceili(float(d["start"]) - t) if t < float(d["start"]) else 0
		if n != int(m["beat"]):
			m["beat"] = n
			if n > 0:
				h.big(str(n), "" if duelist else "%s  vs  %s" % [name_of(int(d["a"])), name_of(int(d["b"]))])
				_sfx("blip_high", p.global_position + Vector3(0, 1.6, 0), -8.0, 0.0, 1.0 + 0.1 * (3 - n))
			else:
				h.big("Fight!", "")
				_sfx("parry", p.global_position + Vector3(0, 1.6, 0), -4.0, 0.0, 0.9)
		if duelist and opp:
			_arm(opp, n == 0)
		_bar(d, opp, duelist)
		return
	if not m["over"]:
		m["over"] = true
		if opp:
			_arm(opp, false)
		_result(d, p, my, duelist)
	_bar(d, opp, duelist)
	if t >= float(d["end"]) + REVIVE_AFTER:
		_finish(id, p)


## Across the top: the opponent's health (a watcher: the pair's balance, the bar the first one's share).
func _bar(d: Dictionary, opp: Node3D, duelist: bool) -> void:
	if duelist:
		if opp:
			var hc = opp.health_component
			get_tree().call_group("hud", "show_boss", opp.display_name(), hc.current_health / maxf(hc.max_health, 1.0), 99)
		return
	var a := captain(int(d["a"]))
	var b := captain(int(d["b"]))
	if a == null or b == null:
		return
	var fa: float = a.health_component.current_health / maxf(a.health_component.max_health, 1.0)
	var fb: float = b.health_component.current_health / maxf(b.health_component.max_health, 1.0)
	get_tree().call_group("hud", "show_boss", "%s  vs  %s" % [a.display_name(), b.display_name()], fa / maxf(fa + fb, 0.001) if fa + fb > 0.0 else 0.5, 99)


func _result(d: Dictionary, p: Node3D, my: int, duelist: bool) -> void:
	var w := int(d["winner"])
	var at := p.global_position + Vector3(0, 1.6, 0)
	if w == 0:
		_hud().big("Draw", "Nobody won the duel")
		_sfx("blip_low", at, -6.0, 0.0, 0.8)
	elif w == my:
		var xp := xp_for(p)
		_hud().big("Victory", "+%d XP" % xp, true)
		get_node("/root/GameManager").award_xp(xp, p.global_position + Vector3(0, 2.0, 0))
	elif duelist:
		_hud().big("Defeated", "%s wins the duel" % name_of(w))
		_sfx("blip_low", at, -6.0, 0.0, 0.7)
	else:
		_hud().big("%s wins" % name_of(w), "")


## Both duelists up again with what they had before it (unless something else killed them meanwhile).
func _finish(id: int, p: Node3D) -> void:
	var m: Dictionary = _mine.get(id, {})
	if m.is_empty():
		return
	if not m["done"]:
		m["done"] = true
		get_tree().call_group("hud", "hide_boss")
		for c in get_tree().get_nodes_in_group("players"):
			if not c.is_local:
				_arm(c, false)
		if m["duelist"] and not p.is_bleeding() and (p.health_component.current_health > 0.0 or p.current_state_name() == "Downed"):
			stand_up(p, float(m["hp"]), float(m["energy"]))
	if not state["duels"].has(id):
		_mine.erase(id)


## The opponent's hurtbox on the enemies' layer here: our blades, shots and skills find it.
func _arm(opp: Node, on: bool) -> void:
	var hb := opp.get_node("Hurtbox") as Area3D
	hb.collision_layer = (hb.collision_layer | ENEMY_LAYER) if on else (hb.collision_layer & ~ENEMY_LAYER)


# ==========================================================================
# Inspect: a captain's kit, asked of their own machine
# ==========================================================================
func ask_kit(id: int) -> void:
	var p := captain(id)
	if p == null:
		return
	if p.is_local or not net.active:
		kit_received.emit.call_deferred(id, kit_of(p))
	else:
		_want_kit.rpc_id(id)


@rpc("any_peer", "call_remote", "reliable")
func _want_kit() -> void:
	_kit.rpc_id(multiplayer.get_remote_sender_id(), net.my_id(), kit_of(me()))


@rpc("any_peer", "call_remote", "reliable")
func _kit(id: int, k: Dictionary) -> void:
	kit_received.emit(id, k)


## Name, level, fighting style, fruit, weapons, worn gear and the quick item (item refs, SaveGame's).
func kit_of(p: Node) -> Dictionary:
	var sg = load(SAVE)
	var gear := {}
	for slot in p.equipment.slots.keys():
		if p.equipment.slots[slot]:
			gear[slot] = sg.item_ref(p.equipment.slots[slot])
	var inv = p.inventory_component
	var it = inv.quick_item()
	var quick: Array = [[sg.item_ref(it), inv.count(it.id) if it else 0]]
	return {"name": p.display_name(), "level": int(p.progression.level), "style": p.style(), "fruit": p.power.fruit,
		"weapon": sg.item_ref(p.equipped_weapon), "offhand": sg.item_ref(p.offhand_weapon), "gear": gear, "quick": quick}
