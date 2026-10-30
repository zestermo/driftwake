class_name StrongholdOfficers
extends Node3D
## The stronghold's officers in the crowds (1.27, Zach: player-AI Admiralty officers sprinkled among the grunts, a
## little detuned, at most CAP standing at once, spread over the raid's space and time). Captain-style AIs
## (RivalDuel.build through Net._all_spawn_rival, so every machine has the body), each district fielding its first
## when a captain comes within MEET m of its squad, then a CHANCE roll each time that squad (or a sealed room's wave)
## musters again. Detuned: SKILL (fewer skills, slower to use them) and HEALTH of a rival captain's. The host decides;
## a beaten officer stays down for good (Player.defeated).

const CAP := 5
const MEET := 30.0
const CHANCE := 0.35
const SKILL := 0.35
const HEALTH := 0.8
const WEAPONS := ["cutlass", "katana", "greatsword", "dagger"]
const CHECK := 1.0

var isl: Node3D
## The camps it watches (the garrison's squads and sealed rooms), the wave each was last rolled for, and whether its
## district's first officer has come.
var camps: Array = []
var _rolled := {}
var _met := {}
var _n := 0
var _check := 0.0


func setup(island: Node3D, watched: Array) -> StrongholdOfficers:
	isl = island
	camps = watched
	name = "Officers"
	return self


## The officers standing now (spawned by this node, not beaten).
func standing() -> Array:
	var out: Array = []
	for c in isl.city.get_children():
		if str(c.name).begins_with("Officer_") and c is Player and (c as Player).health_component.current_health > 0.0:
			out.append(c)
	return out


func _process(delta: float) -> void:
	if not get_node("/root/Net").is_host():
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK
	for camp in camps:
		if not is_instance_valid(camp):
			continue
		var key := str(camp.name)
		if not _met.get(key, false):
			if camp is StrongholdEncounter or not _captain_near(camp.global_position, MEET):
				continue
			_met[key] = true
			_rolled[key] = int(camp.gen)
			spawn_near(camp)
			continue
		if int(camp.gen) != int(_rolled.get(key, -1)):
			_rolled[key] = int(camp.gen)
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([key, int(camp.gen), int(isl.node["seed"])])
			if int(camp.gen) >= 1 and rng.randf() < CHANCE:
				spawn_near(camp)


func _captain_near(at: Vector3, r: float) -> bool:
	for p in get_node("/root/Net").all_players():
		if (p as Node3D).global_position.distance_to(at) < r:
			return true
	return false


## An officer by this camp (under the cap): an Admiralty officer's look, a blade from WEAPONS, detuned; then on the
## captains.
func spawn_near(camp: Node3D) -> Player:
	if standing().size() >= CAP:
		return null
	_n += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["officer", str(camp.name), _n, int(isl.node["seed"])])
	var lk := PirateGrunt.crew_look(rng)
	EnemyShip.marine_look(lk, rng, true)
	lk["name"] = "Admiralty officer"
	var a := rng.randf() * TAU
	var at: Vector3 = camp.global_position + Vector3(cos(a), 0.0, sin(a)) * 3.0 + Vector3.UP * 0.5
	var oname := "Officer_%d" % _n
	var net := get_node("/root/Net")
	net.everyone("_all_spawn_rival", [net.key_of(isl.city), oname, lk, WEAPONS[rng.randi() % WEAPONS.size()], at, a + PI, SKILL])
	var r := isl.city.get_node_or_null(oname) as Player
	if r == null:
		return null
	# (health from hp_k, as the rivals': the stats recalc would undo a max_health set by hand)
	r.hp_k = HEALTH
	r._recalc_stats()
	r.health_component.current_health = r.health_component.max_health
	var brain := r.get_node_or_null("Brain")
	if brain:
		brain.order = "fight"
	return r
