class_name Admiralty
extends Node3D
## The Admiralty at sea (docs/v1_23_plan.md, "Marines" and "Bounty as heat"): it answers big deeds and hunts wanted
## crews.
##
## * A deed (an island boss beaten: Net.bounty "boss"; the island arcs call `Admiralty.deed` when an arc finishes):
##   a blockade at the island's mouth (two ships holding station on the crew's way out, a boom of chained logs
##   between them: shoot it apart or ram it at speed), and once the crew's ship is out at sea a ring of warships
##   closes round her (RING_N by heat tier, RING_R off). Break out or fight through.
## * Heat: while the crew's ship is at sea with a captain aboard, patrols come for a wanted crew, more often and more
##   of them the higher the crew's heat tier (PATROL_EVERY, PATROL_KINDS). They come in from the edge of view along
##   her wake (the wake is a trail of points every WAKE_EVERY s; storms wash it out sooner) and chase her once they
##   see her; fog and storms shorten how far they can keep her in sight (`sight_k`). Lost, they turn away and are gone
##   once out of every captain's sight.
##
## The host decides everything; its ships are ordinary EnemyShips (pursuer = true) under this node, and every screen
## builds the same ones from the spawner list (net_gen: a late joiner gets them too). One node, "Admiralty", under
## the world scene (`ensure`: the fleets make it).

signal deed_answered(at: Vector3, what: String)
signal hunt_started
signal escaped

const CHECK := 1.0
## The ring: ships by heat tier, how far off, and how far from the deed's island before it closes.
const RING_N := [0, 2, 3, 4, 5]
## A blockade from this tier (Notorious); deeds closer together than DEED_EVERY (game s) are one answer.
const BLOCK_FROM := 2
const DEED_EVERY := 480.0
const RING_R := 135.0
## The blockade (1.26): BLOCK_N ships holding station on an arc BLOCK_R round the crew's ship where she lies (seaward,
## away from the island), BLOCK_ARC rad apart, booms between them and from each end ship
## BLOCK_WING rad on toward the shore, so there's no sailing round it. They fire from station; sink or cripple any one
## (or get past the line) and the booms tied to her part and the rest give chase.
const BLOCK_N := 3
const BLOCK_R := 95.0
const BLOCK_ARC := 0.75
const BLOCK_WING := 0.7
## A boom's ends stop this short of a ship's side.
const BLOCK_GAP := 9.0
## Patrols by heat tier: seconds at sea between them (0: none; 1.26: none while only Wanted), and what sails.
const PATROL_EVERY := [0.0, 0.0, 420.0, 300.0, 240.0]
## After a hunt ends (the patrol beaten or the crew escaped), no patrol for this long (game s).
const QUIET := 300.0
const PATROL_KINDS := [[], ["marine"], ["marine", "marine"], ["frigate", "marine"], ["frigate", "marine", "marine"]]
## They appear this far off, along the wake.
const SPAWN_R := 330.0
## Lost and this far from every captain: gone.
const DESPAWN := 480.0
const WAKE_EVERY := 4.0
## A wake point lasts this long (game seconds); a storm washes it out in half that.
const WAKE_LIFE := 150.0

## [world position, game clock] oldest first.
var wake: Array = []
## A deed waiting for the crew to put to sea: {at, what}.
var ring_due: Dictionary = {}
## The live ships' specs: name -> [kind, position, heading, seed, level, role].
var specs: Dictionary = {}
## Live booms: name -> [a, b].
var booms: Dictionary = {}
var clock: float = 0.0
var hunted: bool = false
var _t: float = 0.0
var _wake_t: float = 0.0
var _patrol_t: float = 0.0
var _n: int = 0
var _deed_t: float = -1.0
## No patrols before this (clock): QUIET after the last hunt ended.
var _quiet_until: float = 0.0
## (host) The blockade line: its ships' names, the circle's centre, and each boom's ships (boom name -> [names]).
var _line: Array = []
var _line_c := Vector3.ZERO
var _boom_ships: Dictionary = {}


static func of(tree: SceneTree) -> Admiralty:
	return tree.current_scene.get_node_or_null("Admiralty") as Admiralty


static func ensure(tree: SceneTree) -> Admiralty:
	var a := of(tree)
	if a == null:
		a = Admiralty.new()
		a.name = "Admiralty"
		tree.current_scene.add_child(a)
	return a


## (host) A big deed the Admiralty answers: an island boss beaten, an arc finished (`what`), at `at`.
static func deed(tree: SceneTree, at: Vector3, what: String = "boss") -> void:
	if tree.root.get_node("Net").is_client():
		return
	ensure(tree)._deed(at, what)


## How far the Admiralty can keep a ship at `at` in sight (x their usual): fog and storms hide her (the weather's, or
## a fog bank's or storm cell's out at sea).
static func sight_k(tree: SceneTree, at: Vector3) -> float:
	var wx := tree.root.get_node("Weather")
	var fog: float = wx.fog
	var storm: float = wx.storm
	var sf := tree.get_first_node_in_group("sea_features")
	if sf:
		var lw: Vector2 = sf.local_weather(at)
		storm = maxf(storm, lw.x)
		fog = maxf(fog, lw.y)
	return lerpf(1.0, 0.45, clampf(fog, 0.0, 1.0)) * lerpf(1.0, 0.6, clampf(storm, 0.0, 1.0))


func _ready() -> void:
	add_to_group("net_spawner")


func _deed(at: Vector3, what: String) -> void:
	if not ring_due.is_empty() or (_deed_t >= 0.0 and clock - _deed_t < DEED_EVERY):
		return
	_deed_t = clock
	ring_due = {"at": at, "what": what}
	deed_answered.emit(at, what)
	if _tier() >= BLOCK_FROM:
		_blockade(at)
		_say(["The Admiralty answers", "Warships close the island's mouth. Break out or fight through.", true])
	else:
		_say(["Word travels fast", "The Admiralty will be waiting when you put to sea.", false])


func _physics_process(delta: float) -> void:
	if Net.is_client():
		return
	clock += delta
	_t += delta
	if _t < CHECK:
		return
	_t = 0.0
	var ship := _crew_ship()
	var at_sea := ship != null and EnemyShip.huntable_at(ship.global_position)
	if at_sea:
		_wake_tick(ship)
		if not ring_due.is_empty() and _off_island(ship.global_position, ring_due["at"]):
			_close_ring(ship)
			ring_due = {}
		_patrol_tick(ship)
	_line_tick()
	var life := WAKE_LIFE * lerpf(1.0, 0.5, clampf(Weather.storm, 0.0, 1.0))
	while not wake.is_empty() and clock - float(wake[0][1]) > life:
		wake.pop_front()
	_tidy()
	_hunt_note()


## The crew's ship with a captain aboard (else null).
func _crew_ship() -> Ship:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship == null:
		return null
	for p in Net.all_players():
		if ship.aboard((p as Node3D).global_position):
			return ship
	return null


func _wake_tick(ship: Ship) -> void:
	_wake_t -= CHECK
	if _wake_t > 0.0:
		return
	_wake_t = WAKE_EVERY
	var p := Vector3(ship.global_position.x, 0.0, ship.global_position.z)
	if wake.is_empty() or (wake[-1][0] as Vector3).distance_to(p) > 8.0:
		wake.append([p, clock])


## The next wake point for a tracker at `from`: the one after the point nearest it (the ship herself past the last).
func trail_from(from: Vector3) -> Vector3:
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	if wake.is_empty():
		return Vector3.INF
	var best := 0
	var bd := INF
	for i in range(wake.size()):
		var d := from.distance_to(wake[i][0])
		if d < bd:
			bd = d
			best = i
	if best + 1 < wake.size():
		return wake[best + 1][0]
	return ship.global_position if ship else wake[-1][0]


func _off_island(p: Vector3, isle_at: Vector3) -> bool:
	return Vector2(p.x - isle_at.x, p.z - isle_at.z).length() > _isle_of(isle_at)[1] + EnemyShip.STANDOFF + 20.0


## The no-go circle (an island) nearest `at`: [centre (x, z), radius].
func _isle_of(at: Vector3) -> Array:
	var best: Array = [Vector2(at.x, at.z), 60.0]
	var bd := INF
	for z in EnemyShip.no_go:
		var d := Vector2(at.x, at.z).distance_to(z[0]) - float(z[1])
		if d < bd:
			bd = d
			best = z
	return best


func _tier() -> int:
	return EnemyShip.crew_heat_tier(get_tree())


func _level() -> int:
	var lv := 0
	for p in Net.all_players():
		lv = maxi(lv, int(p.progression.level))
	return lv


# --------------------------------------------------------------------------
# Deeds: the blockade and the ring
# --------------------------------------------------------------------------
func _blockade(at: Vector3) -> void:
	var isle := _isle_of(at)
	var c := Vector3((isle[0] as Vector2).x, 0.0, (isle[0] as Vector2).y)
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	var from: Vector3 = ship.global_position if ship else at
	var out := Vector3(from.x - c.x, 0.0, from.z - c.z)
	if out.length() < 1.0:
		out = Vector3.FORWARD
	out = out.normalized()
	# round her where she lies (seaward of her, away from the island)
	var centre := Vector3(from.x, 0.0, from.z) if ship else c + out * (float(isle[1]) + EnemyShip.STANDOFF)
	_line_c = centre
	var ang := atan2(out.z, out.x)
	var on_arc := func(a: float) -> Vector3: return centre + Vector3(cos(a), 0.0, sin(a)) * BLOCK_R
	var lv := _level()
	_line = []
	var spots: Array = []
	for i in range(BLOCK_N):
		var a := ang + (float(i) - (BLOCK_N - 1) * 0.5) * BLOCK_ARC
		var p: Vector3 = on_arc.call(a)
		var tangent := Vector3(-sin(a), 0.0, cos(a))
		# (broadside to her, the middle one the heavy ship once the crew's Infamous)
		var es := _spawn("frigate" if i == BLOCK_N / 2 and _tier() >= 3 else "marine", p, atan2(-tangent.x, -tangent.z), lv, "block")
		_line.append(String(es.name))
		spots.append(p)
	for i in range(BLOCK_N - 1):
		var d: Vector3 = (spots[i + 1] - spots[i]).normalized()
		_add_boom(spots[i] + d * BLOCK_GAP, spots[i + 1] - d * BLOCK_GAP, [_line[i], _line[i + 1]])
	# the wings: on from each end ship toward the shore
	var half := (BLOCK_N - 1) * 0.5 * BLOCK_ARC
	for s in [-1.0, 1.0]:
		var end: Vector3 = spots[0] if s < 0.0 else spots[-1]
		var tip: Vector3 = on_arc.call(ang + s * (half + BLOCK_WING))
		_add_boom(end + (tip - end).normalized() * BLOCK_GAP, tip, [_line[0] if s < 0.0 else _line[-1]])
	Net.spawned(self, net_gen())


func _add_boom(from: Vector3, to: Vector3, ships: Array) -> void:
	_n += 1
	var bname := "Boom_%d" % _n
	booms[bname] = [from, to]
	_boom_ships[bname] = ships
	_make_boom(bname)


## (host) The blockade line, each tick: a ship of it sunk, struck, fled or driven off station parts her booms and
## sends the rest after the crew; the crew's ship past the line sends them all.
func _line_tick() -> void:
	if _line.is_empty():
		return
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	var past := ship != null and Vector2(ship.global_position.x - _line_c.x, ship.global_position.z - _line_c.z).length() > BLOCK_R + 25.0
	var broken := past
	for nm in _line:
		var es := get_node_or_null(NodePath(str(nm))) as EnemyShip
		if es and not es.is_dead() and es.state == EnemyShip.S.BLOCK:
			continue
		broken = true
		for b in _boom_ships.keys():
			if nm in _boom_ships[b] and booms.has(b):
				var bn := get_node_or_null(NodePath(str(b))) as AdmiraltyBoom
				if bn and not bn.broken:
					bn._break()
	if not broken:
		return
	# (the ships leave station: nothing holds the rest of the chain either)
	for b in _boom_ships.keys():
		var bn := get_node_or_null(NodePath(str(b))) as AdmiraltyBoom
		if bn and not bn.broken:
			bn._break()
	for nm in _line:
		var es := get_node_or_null(NodePath(str(nm))) as EnemyShip
		if es and not es.is_dead() and es.state == EnemyShip.S.BLOCK:
			es.break_line()
	_line = []
	_say(["The line is broken!", "The blockade gives chase.", true])


func _close_ring(ship: Ship) -> void:
	var tier := _tier()
	var n: int = RING_N[tier]
	if n == 0:
		return
	var lv := _level()
	var a0 := ship.global_rotation.y
	for i in range(n):
		var a := a0 + TAU * i / n + PI / n
		var dir := Vector3(-sin(a), 0.0, -cos(a))
		var spot := ship.global_position + dir * RING_R
		for tries in range(6):
			if EnemyShip.huntable_at(spot):
				break
			a += 0.3
			dir = Vector3(-sin(a), 0.0, -cos(a))
			spot = ship.global_position + dir * RING_R
		if not EnemyShip.huntable_at(spot):
			continue
		# (side-on to her, guns run out)
		var tangent := Vector3.UP.cross(dir)
		_spawn("frigate" if tier >= 3 and i == 0 else "marine", spot, atan2(-tangent.x, -tangent.z), lv, "ring")
	Net.spawned(self, net_gen())
	_say(["Surrounded!", "An Admiralty ring closes in. Break out or fight through.", true])


# --------------------------------------------------------------------------
# Heat: patrols on the crew's wake
# --------------------------------------------------------------------------
func _patrol_tick(ship: Ship) -> void:
	var tier := _tier()
	var every: float = PATROL_EVERY[tier]
	if every <= 0.0 or _pursuers() > 0 or clock < _quiet_until:
		_patrol_t = 0.0 if every <= 0.0 else _patrol_t
		return
	_patrol_t += CHECK
	if _patrol_t < every:
		return
	_patrol_t = 0.0
	send_patrol(ship, tier)


## (host) A patrol for a crew of bounty `tier` (PATROL_KINDS), coming up the wake from the edge of view.
func send_patrol(ship: Ship, tier: int) -> void:
	var spot := _from_wake(ship)
	var to := ship.global_position - spot
	var heading := atan2(-to.x, -to.z)
	var across := Vector3.UP.cross(to.normalized())
	var kinds: Array = PATROL_KINDS[tier]
	var lv := _level()
	for i in range(kinds.size()):
		_spawn(kinds[i], spot + across * (float(i) - (kinds.size() - 1) * 0.5) * 40.0, heading, lv, "patrol")
	Net.spawned(self, net_gen())


## A spot SPAWN_R back along her wake (behind her if the wake's too short), in open water.
func _from_wake(ship: Ship) -> Vector3:
	var p := ship.global_position
	for i in range(wake.size() - 1, -1, -1):
		var w: Vector3 = wake[i][0]
		if w.distance_to(p) >= SPAWN_R:
			return p + (w - p).normalized() * SPAWN_R
	var back := -ship.hull_velocity().normalized() if ship.hull_velocity().length() > 1.0 else ship.global_basis.z
	var a := atan2(-back.x, -back.z)
	for tries in range(8):
		var d := Vector3(-sin(a), 0.0, -cos(a))
		if EnemyShip.huntable_at(p + d * SPAWN_R):
			return p + d * SPAWN_R
		a += 0.4 * (1.0 if tries % 2 == 0 else -1.0) * (tries + 1)
	return p + ship.global_basis.z * SPAWN_R


func _pursuers() -> int:
	var n := 0
	for s in get_children():
		if s is EnemyShip and not (s as EnemyShip).is_dead() and (s as EnemyShip).pursuing():
			n += 1
	return n


## Hunted / escaped: the word on every screen when the first pursuer starts after the crew and when the hunt ends:
## "Escaped" with ships still afloat that lost her, else they're beaten. Either way the sea goes quiet for QUIET s.
func _hunt_note() -> void:
	var now := _pursuers() > 0
	if now == hunted:
		return
	hunted = now
	if now:
		hunt_started.emit()
		_say(["The Admiralty!", "Warships on your wake. Lose them in fog, storm or distance.", false])
		return
	_quiet_until = clock + QUIET
	_patrol_t = 0.0
	var afloat := false
	for s in get_children():
		if s is EnemyShip and not (s as EnemyShip).is_dead() and (s as EnemyShip).state not in [EnemyShip.S.BLOCK, EnemyShip.S.PRIZE]:
			afloat = true
	if afloat:
		escaped.emit()
		_say(["Escaped", "The Admiralty has lost your wake.", false])
	else:
		_say(["The patrol is beaten", "The Admiralty's ships are done. The sea is quiet, for now.", false])


## A banner on every screen.
func _say(args: Array) -> void:
	net_event("banner", args)
	Net.event(self, "banner", args)


func net_event(what: String, args: Array) -> void:
	if what == "banner":
		get_tree().call_group("hud", "show_banner", str(args[0]), str(args[1]), bool(args[2]))


## (host) Lost and out of every captain's sight: gone.
func _tidy() -> void:
	var changed := false
	for s in get_children():
		if not (s is EnemyShip):
			continue
		var es := s as EnemyShip
		if es.is_dead() or es.pursuing() or es.state == EnemyShip.S.BLOCK:
			continue
		var near := false
		for p in Net.all_players():
			if (p as Node3D).global_position.distance_to(es.global_position) < DESPAWN:
				near = true
		if not near:
			es.queue_free()
			specs.erase(String(es.name))
			changed = true
	for k in specs.keys():
		if not has_node(NodePath(str(k))):
			specs.erase(k)
			changed = true
	if changed:
		Net.spawned(self, net_gen())


# --------------------------------------------------------------------------
# Building ships and booms (every screen, from the specs)
# --------------------------------------------------------------------------
func _spawn(kind: String, at: Vector3, heading: float, lv: int, role: String) -> EnemyShip:
	_n += 1
	var nm := "AS%d" % _n
	specs[nm] = [kind, Vector3(at.x, 0.0, at.z), heading, 9100 + _n, lv, role]
	return _make_ship(nm)


func _make_ship(nm: String) -> EnemyShip:
	var sp: Array = specs[nm]
	var at: Vector3 = sp[1]
	var s := EnemyShip.new()
	s.name = nm
	s.setup(at, 70.0, 0.0, int(sp[3]), str(sp[0]))
	s.level = int(sp[4])
	s.pursuer = true
	s.role = str(sp[5])
	add_child(s)
	s.global_transform = Transform3D(Basis(Vector3.UP, float(sp[2])), Vector3(at.x, HullBuilder.FREEBOARD, at.z))
	s._pos = at
	s._heading = float(sp[2])
	s.reset_physics_interpolation()
	s.start_role()
	return s


func _make_boom(nm: String) -> void:
	var b := AdmiraltyBoom.new()
	b.name = nm
	b.a = booms[nm][0]
	b.b = booms[nm][1]
	add_child(b)


func boom_broken(nm: String) -> void:
	booms.erase(nm)
	_boom_ships.erase(nm)
	Net.spawned(self, net_gen())


func net_gen():
	var live := {}
	for k in specs.keys():
		var s := get_node_or_null(NodePath(str(k))) as EnemyShip
		if s and not s.is_dead():
			live[k] = specs[k]
	return [live, booms.duplicate()]


## (not the host) Build what the host has that we don't; drop what it no longer has.
func net_set_gen(g) -> void:
	var live: Dictionary = g[0]
	var bm: Dictionary = g[1]
	for k in live.keys():
		if not has_node(NodePath(str(k))):
			specs[k] = live[k]
			_make_ship(str(k))
	for k in bm.keys():
		if not has_node(NodePath(str(k))):
			booms[k] = bm[k]
			_make_boom(str(k))
	for c in get_children():
		if c is EnemyShip and not live.has(String(c.name)) and not (c as EnemyShip).is_dead():
			c.queue_free()
		elif c is AdmiraltyBoom and not bm.has(String(c.name)):
			(c as AdmiraltyBoom).shatter()
