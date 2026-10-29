class_name TavernGames
extends Node
## (1.25.5, docs/v1_26_plan.md "Talking to NPCs"; the two games and their stakes are assumed, not previewed) Games at a
## village's inn, each with its own regular by the door: dice with the dicer (best of three throws of two dice
## against theirs, ties thrown again, a stake of 10, 25 or 50 gold) and arm wrestling with the island's strongest arm
## (a timed press: hit Attack while the marker's in the band to push, they push back steadily, ARM_STAKE gold). Each
## captain plays on their own machine with their own gold. STREAK wins running is told to the host, and the island's
## traders take DISCOUNT off for the whole crew (Journal.perks on every machine, like a quest's discount).

const STAKES := [10, 25, 50]
const ARM_STAKE := 25
const STREAK := 3
const DISCOUNT := 0.1
const DICERS := ["Lucky", "Bones", "Fat", "Quick", "Old", "Sly"]
const ARMS := ["Iron-Arm", "Big", "Ox", "Anchor", "Bull", "Stone-Hand"]

var isl
var trade_id := ""
var key := ""
var dicer := ""
var wrestler := ""
var _streak := 0
var _throws := ""
var _outcome := ""
var _wrestle_due := false
var _npcs: Array = []


## Its two regulars by the inn's door (`door`, `face`, floor `y`), their talk, and the node (named "Tavern" under
## the village: co-op finds it by its path).
static func make(v, door: Vector2, face: Vector2, y: float) -> TavernGames:
	var t := TavernGames.new()
	t.name = "Tavern"
	t.isl = v.isl
	t.key = v.isl.save_key("tavern")
	t.trade_id = v.isl.save_key("trader")
	v.add_child(t)
	var lks := looks(v.isl)
	t.dicer = str(lks[0]["name"])
	t.wrestler = str(lks[1]["name"])
	var side := Vector2(-face.y, face.x)
	for k in range(2):
		var at: Vector2 = door + face * 2.2 + side * (2.8 if k == 0 else -2.8)
		t._npcs.append(v._npc({"name": lks[k]["name"], "dialogue": "%s_%d" % [t.key, k], "voice": 0.9 + 0.15 * k, "look": lks[k]}, at, -side if k == 0 else side, y))
	t._define()
	return t


## The dicer's and the wrestler's looks (named), from the island's seed: GenIsland.prepare builds their bodies ahead.
static func looks(gi) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(gi.node["seed"]), 5150])
	var firsts: Array = LifePools.of(gi.theme)["first"]
	var names := ["%s %s" % [DICERS[rng.randi() % DICERS.size()], firsts[rng.randi() % firsts.size()]],
		"%s %s" % [ARMS[rng.randi() % ARMS.size()], firsts[rng.randi() % firsts.size()]]]
	var st := KitStyle.of(gi.theme)
	var out: Array = []
	for k in range(2):
		var lk := KitStyle.folk_look(st, rng)
		if k == 1:
			lk.merge({"build": "broad", "height": 1.08}, true)
		lk["name"] = names[k]
		out.append(lk)
	return out


func _ready() -> void:
	Dialogue.dialogue_event.connect(_on_event)
	Dialogue.dialogue_ended.connect(_on_ended)


func _define() -> void:
	Dialogue.register_token(key + "_throws", func(): return _throws)
	Dialogue.register_token(key + "_outcome", func(): return _outcome)
	var dmenu: Array = []
	for s in STAKES:
		dmenu.append({"text": "Throw for %d gold." % s, "next": "throw%d" % s})
	dmenu.append({"text": "Not tonight.", "next": "end"})
	var dnodes := {"intro": {"text": ["Two dice each, best of three throws. Ties throw again.", "Fancy your luck, Captain?"], "next": "menu"},
		"menu": {"text": "Another throw?", "choices": dmenu}}
	for s in STAKES:
		dnodes["throw%d" % s] = {"text": ["{%s_throws}" % key, "{%s_outcome}" % key], "event": "tavern:%s:dice:%d" % [key, s], "next": "menu"}
	Dialogue.define(key + "_0", {"speaker": dicer, "voice": 0.9, "start": "intro", "return": "menu", "nodes": dnodes})
	var wnodes := {"intro": {"text": ["Nobody on %s has put my arm down. Nobody." % isl.island_name, "%d gold says you won't either." % ARM_STAKE], "next": "menu"},
		"menu": {"text": "Well? Elbow on the barrel.", "choices": [
			{"text": "You're on. (%d gold; Attack when the marker's in the band)" % ARM_STAKE, "next": "go"}, {"text": "Some other time.", "next": "end"}]},
		"go": {"text": ["Grip. Ready... go!"], "event": "tavern:%s:wrestle" % key, "next": "end"}}
	Dialogue.define(key + "_1", {"speaker": wrestler, "voice": 1.05, "start": "intro", "return": "menu", "nodes": wnodes})


func _me() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _on_event(ev: String) -> void:
	if not ev.begins_with("tavern:%s:" % key):
		return
	match ev.get_slice(":", 2):
		"dice":
			dice(int(ev.get_slice(":", 3)), RandomNumberGenerator.new())
		"wrestle":
			_wrestle_due = true


func _on_ended(_id: String) -> void:
	if _wrestle_due:
		_wrestle_due = false
		var me := _me()
		if me.inventory_component.count("gold") < ARM_STAKE:
			get_tree().call_group("hud", "show_toast", "You haven't %d gold to put down." % ARM_STAKE)
			return
		var w := Wrestle.new()
		w.tier = IslandContent.tier(isl)
		w.done.connect(_wrestled)
		add_child(w)


## A round of dice for `stake` with this captain's gold (the throws from `rng`); the result read by the talk's tokens.
func dice(stake: int, rng: RandomNumberGenerator) -> bool:
	var me := _me()
	if me.inventory_component.count("gold") < stake:
		_throws = "You pat your pockets. Not %d gold in them." % stake
		_outcome = "\"Come back when you're good for it.\""
		return false
	var mine := 0
	var theirs := 0
	var parts: Array = []
	while mine < 2 and theirs < 2:
		var a := rng.randi_range(1, 6) + rng.randi_range(1, 6)
		var b := rng.randi_range(1, 6) + rng.randi_range(1, 6)
		parts.append("%d to %d" % [a, b])
		if a > b:
			mine += 1
		elif b > a:
			theirs += 1
	_throws = "You throw: %s." % ", ".join(parts)
	var won := mine > theirs
	_settle(won, stake)
	_outcome = ("You take %d gold off %s." % [stake, dicer]) if won else ("%s sweeps up your %d gold. \"Again?\"" % [dicer, stake])
	if won and _streak == STREAK:
		_outcome += " %d in a row! Word gets round: the traders here knock some off for your crew." % STREAK
	return won


func _wrestled(won: bool) -> void:
	_settle(won, ARM_STAKE)
	var line := ("%s's arm hits the barrel. %d gold to you, and a grudging nod." % [wrestler, ARM_STAKE]) if won else ("Your knuckles hit the barrel. %s pockets %d gold." % [wrestler, ARM_STAKE])
	if won and _streak == STREAK:
		line += " %d in a row! The traders here knock some off for your crew." % STREAK
	get_tree().call_group("hud", "show_banner", "Arm wrestling", line, false)


func _settle(won: bool, stake: int) -> void:
	var me := _me()
	if won:
		me.inventory_component.add_item(ItemDB.get_item("gold"), stake)
		_streak += 1
		if _streak == STREAK:
			Net.arc_ask(Net.key_of(self), "streak", [])
	else:
		me.inventory_component.remove_item(ItemDB.get_item("gold"), stake)
		_streak = 0


## (host) A captain's streak: the crew's discount at the island's traders.
func decide(op: String, _args: Array, _by: int) -> void:
	if op == "streak" and Journal.discount(trade_id) < DISCOUNT:
		Net.everyone("_all_arc", [Net.key_of(self), "streak", []])


## (every machine)
func apply(op: String, _args: Array) -> void:
	if op == "streak":
		Journal.perks["discount:" + trade_id] = maxf(Journal.discount(trade_id), DISCOUNT)
		Journal.perks["discount:" + isl.save_key("cook")] = maxf(Journal.discount(isl.save_key("cook")), DISCOUNT)


## The arm-wrestling press: a marker sweeps a bar; Attack with it in the band pushes your arm over, the other arm
## pushes back all the while; all the way over wins, all the way back loses, a draw after TIME goes to whoever's ahead.
class Wrestle extends CanvasLayer:
	signal done(won: bool)
	const TIME := 14.0
	const BAND := 0.22
	const PUSH := 0.16
	const MISS := 0.06
	var tier := 0
	var arm := 0.0
	var sweep := 0.0
	var t := 0.0
	var flash := 0.0
	var _pc: PixelCanvas
	var _draw_c: Control

	func _ready() -> void:
		layer = 28
		_pc = PixelCanvas.new()
		add_child(_pc)
		_draw_c = Control.new()
		_draw_c.set_anchors_preset(Control.PRESET_FULL_RECT)
		_draw_c.draw.connect(_paint)
		_pc.ui.add_child(_draw_c)
		var me := get_tree().get_first_node_in_group("player")
		if me and me.has_node("StateMachine"):
			var sm = me.get_node("StateMachine")
			if sm.current_state and sm.states.has("talk"):
				sm.current_state.transitioned.emit(sm.current_state, "Talk", {})

	func _push_rate() -> float:
		return 0.05 + 0.012 * tier

	func _sweep_speed() -> float:
		return 2.2 + 0.25 * tier

	func _process(delta: float) -> void:
		t += delta
		sweep = sin(t * _sweep_speed())
		flash = maxf(flash - delta, 0.0)
		arm -= _push_rate() * delta
		if Input.is_action_just_pressed("light_attack"):
			if absf(sweep) < BAND:
				arm += PUSH
				flash = 0.15
			else:
				arm -= MISS
		_draw_c.queue_redraw()
		if arm >= 1.0 or arm <= -1.0 or t >= TIME:
			_finish(arm > 0.0)

	func _finish(won: bool) -> void:
		set_process(false)
		var me := get_tree().get_first_node_in_group("player")
		if me and me.has_node("StateMachine"):
			var sm = me.get_node("StateMachine")
			if sm.current_state and sm.current_state.name == "Talk":
				sm.current_state.transitioned.emit(sm.current_state, "Idle", {})
		done.emit(won)
		queue_free()

	func _paint() -> void:
		var sz: Vector2 = _pc.canvas
		var font: Font = UIStyle.SILK
		var w := 220.0
		var c := Vector2(sz.x * 0.5, sz.y * 0.72)
		_draw_c.draw_rect(Rect2(c - Vector2(w * 0.5 + 8, 40), Vector2(w + 16, 74)), UIStyle.BG_DARK)
		_draw_c.draw_string(font, c + Vector2(-w * 0.5, -26), "ARM WRESTLE  %.0f" % maxf(TIME - t, 0.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.TEXT)
		# the press: the band in the middle, the marker sweeping
		var bar := Rect2(c + Vector2(-w * 0.5, -14), Vector2(w, 10))
		_draw_c.draw_rect(bar, UIStyle.INK)
		_draw_c.draw_rect(Rect2(c + Vector2(-w * 0.5 * BAND, -14), Vector2(w * BAND, 10)), UIStyle.GOOD if flash <= 0.0 else UIStyle.SUN)
		_draw_c.draw_rect(Rect2(c + Vector2(sweep * w * 0.5 - 2, -17), Vector2(4, 16)), UIStyle.CREAM)
		# the arms: who's winning
		var tug := Rect2(c + Vector2(-w * 0.5, 6), Vector2(w, 8))
		_draw_c.draw_rect(tug, UIStyle.DANGER)
		_draw_c.draw_rect(Rect2(tug.position, Vector2(w * (arm + 1.0) * 0.5, 8)), UIStyle.TEAL_LIGHT)
		_draw_c.draw_string(font, c + Vector2(-w * 0.5, 28), "ATTACK IN THE GREEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.TEXT_DIM)
