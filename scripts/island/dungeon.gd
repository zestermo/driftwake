class_name Dungeon
extends Node3D
## A cave, small dungeon or the ruined temple on a generated island, built by
## KitDungeons / KitTemple from its plan (`info`, which is also the island's POI
## data). What it runs: a banner at the mouth; its enemies and lights asleep while
## no captain is near; the end's boss (the brood mother's fight runs like the brood
## cave's, a captain's like the camps'; either way a top boss bar, a banner and the
## Dialogue flag info["flag"] when it falls); the temple's levers and sanctum gate.
## Co-op: the host decides (boss waves, the gate); net_spawner tells the guests.
## The origin: over the cave's middle at sea level, or the temple's hall floor.

const WAKE := 70.0
const RESET_AFTER := 6.0
const RESPAWN := 900.0

var isl: GenIsland
var info: Dictionary
var enemies: Node3D
var lights: Array = []
var queen: BroodQueen
var brood: ScuttlebugNest
var boss_camp: GruntCamp
var boss_nest: ScuttlebugNest
var boss_gen: int = 0
var gate_mask: int = 0
var levers: Array = []
var gate: Node3D
var gate_col: CollisionShape3D
var _gate_open := false
var _awake := true
var _check := 0.0
var _arrived := false
var _boss_ui := false
var _seen_alive := false
var _empty_t := 0.0
var _dead_t := 0.0
var _camp_gen := 0


func _ready() -> void:
	add_to_group("net_spawner")


# --------------------------------------------------------------------------
# Where things are in a cave (its own space)
# --------------------------------------------------------------------------
static func _door_away(e: Dictionary, room: Dictionary) -> Vector3:
	var c := KitDungeons.loc(e, room["c"], room["y"])
	var dp := KitDungeons.loc(e, room["doors"][0], room["y"])
	return Vector3(c.x - dp.x, 0.0, c.z - dp.z).normalized()


## The end room's far side, away from its door: the chest (or the brood mother's nest).
static func reward_point(e: Dictionary, room: Dictionary) -> Vector3:
	return KitDungeons.loc(e, room["c"], room["y"]) + _door_away(e, room) * float(room["r"]) * 0.55


static func nest_point(e: Dictionary, room: Dictionary) -> Vector3:
	return KitDungeons.loc(e, room["c"], room["y"]) + _door_away(e, room) * float(room["r"]) * 0.45


static func fire_point(e: Dictionary, room: Dictionary) -> Vector3:
	return KitDungeons.loc(e, room["c"], room["y"]) + _door_away(e, room) * float(room["r"]) * 0.2


func end_room() -> Dictionary:
	return KitDungeons.room_of(info, "end") if info["kind"] != "temple" else info["rooms"][info["rooms"].size() - 1]


## In the end room, the boss's (standing on its floor).
func inside(p: Vector3) -> bool:
	var r := end_room()
	var l := to_local(p)
	var c := KitDungeons.loc(info, r["c"], r["y"]) if info["kind"] != "temple" else KitTemple.local(r)
	return Vector2(l.x - c.x, l.z - c.z).length() < float(r["r"]) - 0.5 and l.y > c.y - 1.0 and l.y < c.y + float(r["h"])


func _mouth_global() -> Vector3:
	if info["kind"] == "temple":
		return to_global(KitTemple.door_local())
	return to_global(KitDungeons.loc(info, info["mouth"], info["mouth_y"]))


# --------------------------------------------------------------------------
# Bosses
# --------------------------------------------------------------------------
func setup_queen(nest: ScuttlebugNest) -> void:
	brood = nest
	_spawn_queen()


func setup_captain(camp: GruntCamp) -> void:
	boss_camp = camp


func setup_nest(nest: ScuttlebugNest) -> void:
	boss_nest = nest


func _spawn_queen() -> void:
	if queen and is_instance_valid(queen) and queen.state != Scuttlebug.S.DEAD:
		queen.queue_free()
	var nest := to_global(nest_point(info, end_room()))
	queen = BroodQueen.new().queen(nest)
	queen.name = "Queen_%d" % boss_gen
	queen.cave = self
	queen.level = int(info["level"])
	enemies.add_child(queen)
	queen.global_position = nest + Vector3.UP * 0.4
	queen.reset_physics_interpolation()
	_dead_t = 0.0


func call_brood() -> void:
	brood.call_out()


func brood_alive() -> int:
	return brood.alive_count()


func _captain() -> PirateGrunt:
	if boss_camp == null:
		return null
	for g in boss_camp.grunts:
		if is_instance_valid(g) and (g as PirateGrunt).captain:
			return g
	return null


func boss_name() -> String:
	if queen:
		return "The Brood Mother"
	if boss_nest:
		return "The nest"
	var cap := _captain()
	return str(cap.title) if cap else ""


func boss_alive() -> bool:
	if queen:
		return is_instance_valid(queen) and queen.state != Scuttlebug.S.DEAD
	if boss_nest:
		return boss_nest.alive_count() > 0
	var cap := _captain()
	return cap != null and cap.state != PirateGrunt.S.DEAD


func _boss_fighting() -> bool:
	if queen:
		return queen.in_combat()
	if boss_nest:
		return false
	var cap := _captain()
	return cap != null and cap.in_combat()


func _boss_frac() -> float:
	if queen:
		return queen.health_frac()
	var cap := _captain()
	return cap.health.current_health / maxf(cap.health.max_health, 1.0)


# --------------------------------------------------------------------------
# Each frame
# --------------------------------------------------------------------------
func _process(delta: float) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me and not _arrived and me.global_position.distance_to(_mouth_global()) < 16.0:
		_arrived = true
		get_tree().call_group("hud", "show_banner", info["title"], info["subtitle"], true)
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_sleep_check()
	if enemies == null:
		return
	if boss_camp and boss_camp.gen != _camp_gen:
		_camp_gen = boss_camp.gen
		if not Net.is_client() and gate and gate_mask != 0:
			gate_mask = 0
			_apply_gate(false)
			Net.spawned(self, net_gen())
	var alive := boss_alive()
	_boss_hud(me, alive)
	# (a boss that was never seen alive here, a crew still mustering, isn't a victory)
	if alive:
		_seen_alive = true
	elif _seen_alive:
		_seen_alive = false
		_victory(me)
	if queen:
		_queen_tick(delta, alive)


## Enemies and lights asleep while no captain is near (once the crews have mustered).
func _sleep_check() -> void:
	var near := false
	var flat := Vector2(global_position.x, global_position.z)
	for p in Net.all_players():
		var pp := p as Node3D
		if Vector2(pp.global_position.x, pp.global_position.z).distance_to(flat) < float(info["radius"]) + WAKE:
			near = true
	if near == _awake or enemies == null:
		return
	if not near:
		for camp in enemies.get_children():
			if camp is GruntCamp and not (camp as GruntCamp)._warming.is_empty():
				return
			# (a nest hatching a bug a frame on a building island: asleep mid-way, its last spots stayed empty here
			# while the other machine's filled, and a co-op guest was missing the host's bugs)
			if camp is ScuttlebugNest and (camp as ScuttlebugNest)._hatching:
				return
	_awake = near
	enemies.process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED
	for l in lights:
		(l as Light3D).visible = near


func _queen_tick(delta: float, alive: bool) -> void:
	if Net.is_client():
		return
	if alive:
		var any_in := false
		for p in Net.all_players():
			if inside((p as Node3D).global_position) and p.has_method("is_standing") and p.is_standing():
				any_in = true
		if any_in:
			_empty_t = 0.0
			queen.wake()
		elif queen.in_combat():
			_empty_t += delta
			if _empty_t > RESET_AFTER:
				_empty_t = 0.0
				queen.reset_fight()
	else:
		_dead_t += delta
		if _dead_t > RESPAWN:
			for p in Net.all_players():
				if (p as Node3D).global_position.distance_to(global_position) < float(info["radius"]) + 50.0:
					return
			boss_gen += 1
			_spawn_queen()
			Net.spawned(self, net_gen())


func _boss_hud(me: Node3D, alive: bool) -> void:
	var show := me != null and alive and _boss_fighting() and inside(me.global_position)
	if show:
		get_tree().call_group("hud", "show_boss", boss_name(), _boss_frac(), queen.phase if queen else 1)
		_boss_ui = true
	elif _boss_ui:
		_boss_ui = false
		get_tree().call_group("hud", "hide_boss")


## The end's boss beaten: the flag, a banner and the fanfare for whoever's here,
## and the brood mother's hoard once per character (the others' chests are there all along).
func _victory(me: Node3D) -> void:
	Dialogue.set_flag(str(info["flag"]))
	if me and me.global_position.distance_to(global_position) < float(info["radius"]) + 20.0:
		var head := "%s falls!" % boss_name() if queen else ("The nest is cleared!" if boss_nest else "The boss falls!")
		get_tree().call_group("hud", "show_banner", head, "Whatever was guarded here is yours", true)
		var music := get_node_or_null("/root/Music")
		if music:
			music.victory()
	if queen == null or GameManager.opened.has(str(info["reward"])) or get_node_or_null("Hoard"):
		return
	var t := Levels.tier(int(info["level"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(info["seed"]) + 31
	var bag := KitDungeons._chest(isl, self, info, nest_point(info, end_room()), 0.0, [
		["gold", 50 + t * 15], ["treasure", 4 + t], ["rum", 2],
		[ItemDB.tiered(IslandContent.LOOT_WEAPONS[rng.randi() % IslandContent.LOOT_WEAPONS.size()], mini(t + 1, 5)), 1],
		[Gear.make("accessory", "pauldron", {"pauldron": true}, "Broodshell Pauldron", t), 1]])
	FX.sparkle(bag.global_position + Vector3(0, 0.8, 0), 24, Color(0.7, 1.0, 0.45))


# --------------------------------------------------------------------------
# The temple's levers and gate
# --------------------------------------------------------------------------
## A lever pulled (by anyone; a guest asks the host).
func net_pull(i: int) -> void:
	if Net.forward(self, "net_pull", [i]):
		return
	if gate_mask & (1 << i):
		return
	gate_mask |= 1 << i
	_apply_gate(true)
	Net.spawned(self, net_gen())


func _apply_gate(animate: bool) -> void:
	for i in range(levers.size()):
		var lv: Node3D = levers[i]
		var on := gate_mask & (1 << i) != 0
		var handle := lv.get_node("Handle") as Node3D
		var to := 0.6 if on else -0.6
		if animate and is_inside_tree():
			create_tween().tween_property(handle, "rotation:x", to, 0.4)
		else:
			handle.rotation.x = to
		(lv.get_node("Lever") as Interactable).enabled = not on
	var all := gate_mask == (1 << levers.size()) - 1
	if all == _gate_open:
		if animate and not all and is_inside_tree():
			_lever_note()
		return
	_gate_open = all
	gate_col.disabled = all
	var y := -KitTemple.GATE_SINK if all else 0.0
	if animate and is_inside_tree():
		create_tween().tween_property(gate, "position:y", y, 2.2).set_trans(Tween.TRANS_SINE)
		Net.fx("sfx", ["thud", gate.global_position, 4.0, 0.05, 0.5])
		var me := get_tree().get_first_node_in_group("player") as Node3D
		if me and me.global_position.distance_to(gate.global_position) < 40.0:
			get_tree().call_group("hud", "show_banner", "The sanctum gate grinds open", "Something waits beyond", true)
	else:
		gate.position.y = y


func _lever_note() -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me and me.global_position.distance_to(global_position) < 40.0:
		var n := 0
		for i in range(levers.size()):
			if gate_mask & (1 << i):
				n += 1
		get_tree().call_group("hud", "show_banner", "A lever clunks into place", "%d of %d: stone grinds somewhere deeper in" % [n, levers.size()], false)


func net_gen():
	return [boss_gen, gate_mask]


func net_set_gen(g) -> void:
	var arr: Array = g
	if gate and int(arr[1]) != gate_mask:
		gate_mask = int(arr[1])
		_apply_gate(is_inside_tree())
	if queen and int(arr[0]) != boss_gen:
		boss_gen = int(arr[0])
		_spawn_queen()
