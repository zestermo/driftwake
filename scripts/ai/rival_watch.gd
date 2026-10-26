class_name RivalWatch
extends Node
## Where rival crews turn up (docs/v1_19_plan.md: the first meeting placed, then rolled; nothing else guaranteed),
## the host's (a child of GameManager). On each chain arrival (arrived()) it decides whether a crew comes to this
## island; then, once the captain has been ashore a while, walked inland from the dock and isn't in a fight, the crew
## comes up from the dock (off their ship) and RivalEncounter takes it from there.
##   first meeting: the first chain island past Brinehollow, the Mudlark Brigade (rookies: the right first rivals)
##   then: once MIN_GAP islands have passed since the last, CHANCE an island (seeded by the island); never the capital;
##         the crews you haven't met first, never the same crew twice running
## Bounty hunters (a notorious captain: Bounty) may wait on an island no crew comes to (HUNTER_CHANCE).
## The plan lives in GameManager.rivals["_plan"] (saved with them).

const FIRST_CREW := "mudlark_brigade"
const MIN_GAP := 3
const CHANCE := 0.45
## Ashore this long, this far from the dock, and nothing hostile awake this close: they come.
const ASHORE_S := 20.0
const INLAND := 45.0
const QUIET_R := 25.0
const CHECK_EVERY := 0.5
## A named Admiralty hunter (RivalCrews.ADMIRALTY): from the crew's Infamous, this chance at an island, waiting at
## the harbour (they come as soon as the captain is ashore a moment); the officers in turn.
const OFFICER_FROM := 3
const OFFICER_CHANCE := 0.5
const OFFICER_ASHORE_S := 3.0
## Bounty hunters: from this bounty tier (Notorious), this chance an island with no crew, 2 hunters (+1 a tier above),
## after a longer while ashore and not so far in.
const HUNTERS_FROM := 2
const HUNTER_CHANCE := 0.35
const HUNTER_ASHORE_S := 40.0
const HUNTER_INLAND := 30.0

var _t := 0.0
var _ashore := 0.0


func _gm() -> Node:
	return get_parent()


func plan() -> Dictionary:
	var rv: Dictionary = _gm().rivals
	if not rv.has("_plan"):
		rv["_plan"] = {"since": 0, "pending": -1, "crew": "", "met_first": false, "last": ""}
	return rv["_plan"]


## Host: the crew came to chain island `id`: does a rival crew come here too?
func arrived(id: int) -> void:
	var c = _gm().chain()
	if c == null or id < 0:
		return
	decide(c.node(id), id)


## The decision for chain node `n` (its layer, role and seed), island `id`.
func decide(n: Dictionary, id: int) -> void:
	var pl := plan()
	pl["since"] = int(pl["since"]) + 1
	pl["pending"] = -1
	_ashore = 0.0
	if str(n.get("role", "")) == "capital":
		return
	# an infamous crew: a named Admiralty hunter waits at the harbour (before any crew or hunters)
	pl["officer"] = -1
	if Bounty.tier_of(EnemyShip.crew_bounty(get_tree())) >= OFFICER_FROM:
		var orng := RandomNumberGenerator.new()
		orng.seed = hash(["officer", int(n.get("seed", id))])
		if orng.randf() < OFFICER_CHANCE:
			var ids: Array = RivalCrews.ADMIRALTY.keys()
			pl["officer"] = id
			pl["officer_id"] = str(ids[int(pl.get("officers_met", 0)) % ids.size()])
			pl["hunters"] = -1
			return
	var come := false
	if not bool(pl["met_first"]):
		come = int(n.get("layer", 0)) >= 1
	elif int(pl["since"]) >= MIN_GAP:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["rivals", int(n.get("seed", id))])
		come = rng.randf() < CHANCE
	pl["hunters"] = -1
	if come:
		pl["pending"] = id
		pl["crew"] = FIRST_CREW if not bool(pl["met_first"]) else pick_crew(int(n.get("seed", id)))
		return
	# no crew here: bounty hunters try their luck on a notorious captain (Bounty)
	var p = _gm().player
	var tier := Bounty.tier_of(int(p.bounty)) if p and is_instance_valid(p) else 0
	if tier >= HUNTERS_FROM:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["hunters", int(n.get("seed", id))])
		if rng.randf() < HUNTER_CHANCE:
			pl["hunters"] = id
			pl["hunters_n"] = 2 + maxi(tier - HUNTERS_FROM, 0)


## The crew that comes: one not met yet if any, else any but the last.
func pick_crew(island_seed: int) -> String:
	var rv: Dictionary = _gm().rivals
	var unmet := RivalCrews.ids().filter(func(k): return not rv.has(k))
	var pool: Array = unmet if not unmet.is_empty() else RivalCrews.ids().filter(func(k): return k != str(plan()["last"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["rival_crew", island_seed])
	return str(pool[rng.randi() % pool.size()])


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < CHECK_EVERY:
		return
	var dt := _t
	_t = 0.0
	var net := get_node_or_null("/root/Net")
	if net and not net.is_host():
		return
	# (never in a test or render tool: they walk chain islands for their own reasons; RivalEncounter's own tests
	# start their encounters themselves)
	if Settings.tool_run():
		return
	var gm := _gm()
	var rv: Dictionary = gm.rivals
	if not rv.has("_plan"):
		return
	var crew_here := int(plan()["pending"]) >= 0 and int(plan()["pending"]) == int(gm.chain_at)
	var hunters_here := int(plan().get("hunters", -1)) >= 0 and int(plan().get("hunters", -1)) == int(gm.chain_at)
	var officer_here := int(plan().get("officer", -1)) >= 0 and int(plan().get("officer", -1)) == int(gm.chain_at)
	if not crew_here and not hunters_here and not officer_here:
		return
	var isl = _island(int(gm.chain_at))
	if isl == null:
		return
	var dock: Vector3 = isl.to_global(Vector3(isl.sites["dock_end"].x, 0.0, isl.sites["dock_end"].y))
	# the captain they come for: whoever's furthest inland, on foot (any captain in co-op, not only the host's).
	# Jumps, dodges and swings don't count as leaving the island; only boarding the ship or swimming does.
	var p: Player = null
	var flat := -1.0
	for c in Net.all_players():
		if not (c is Player) or not is_instance_valid(c) or not c.is_inside_tree():
			continue
		var cp := c as Player
		if cp.context != Player.Context.ON_FOOT or cp.is_swimming() or _aboard(cp) \
				or (cp.has_method("is_standing") and not cp.is_standing()):
			continue
		var d := Vector2(cp.global_position.x - dock.x, cp.global_position.z - dock.z).length()
		if d > flat:
			flat = d
			p = cp
	_ashore = _ashore + dt if p != null else 0.0
	if p == null:
		return
	if Cutscene.active or _hostile_near(p):
		return
	if officer_here:
		if _ashore < OFFICER_ASHORE_S:
			return
		# they've been waiting at the harbour: they come at you from the land side
		var inland := p.global_position - dock
		inland.y = 0.0
		var from := p.global_position + inland.normalized() * 10.0 if inland.length() > 2.0 else Vector3.INF
		if RivalEncounter.start(p, str(plan()["officer_id"]), from) != null:
			plan()["officer"] = -1
			plan()["officers_met"] = int(plan().get("officers_met", 0)) + 1
		return
	if hunters_here:
		if _ashore < HUNTER_ASHORE_S or flat < HUNTER_INLAND:
			return
		if RivalEncounter.start_ambush(p, int(plan().get("hunters_n", 2)), dock) != null:
			plan()["hunters"] = -1
		return
	if _ashore < ASHORE_S or flat < INLAND:
		return
	var crew := str(plan()["crew"])
	if RivalEncounter.start(p, crew, dock) == null:
		return
	var pl := plan()
	pl["pending"] = -1
	pl["since"] = 0
	pl["met_first"] = true
	pl["last"] = crew


func _island(id: int):
	var w := get_tree().get_first_node_in_group("world_gen")
	return w.chain_islands.get(id) if w and "chain_islands" in w else null


func _hostile_near(p: Player) -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and (e as Node3D).global_position.distance_to(p.global_position) < QUIET_R \
				and e.has_method("in_combat") and e.in_combat():
			return true
	return false


func _aboard(p: Player) -> bool:
	var ship := get_tree().get_first_node_in_group("ship")
	return ship != null and ship.has_method("aboard") and ship.aboard(p.global_position)
