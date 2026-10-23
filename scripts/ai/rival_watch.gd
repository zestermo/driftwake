class_name RivalWatch
extends Node
## Where rival crews turn up (docs/v1_19_plan.md: the first meeting placed, then rolled; nothing else guaranteed),
## the host's (a child of GameManager). On each chain arrival (arrived()) it decides whether a crew comes to this
## island; then, once the captain has been ashore a while, walked inland from the dock and isn't in a fight, the crew
## comes up from the dock (off their ship) and RivalEncounter takes it from there.
##   first meeting: the first chain island past Brinehollow, the Mudlark Brigade (rookies: the right first rivals)
##   then: once MIN_GAP islands have passed since the last, CHANCE an island (seeded by the island); never the capital;
##         the crews you haven't met first, never the same crew twice running
## The plan lives in GameManager.rivals["_plan"] (saved with them).

const FIRST_CREW := "mudlark_brigade"
const MIN_GAP := 3
const CHANCE := 0.45
## Ashore this long, this far from the dock, and nothing hostile awake this close: they come.
const ASHORE_S := 20.0
const INLAND := 45.0
const QUIET_R := 25.0
const CHECK_EVERY := 0.5

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
	var come := false
	if not bool(pl["met_first"]):
		come = int(n.get("layer", 0)) >= 1
	elif int(pl["since"]) >= MIN_GAP:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["rivals", int(n.get("seed", id))])
		come = rng.randf() < CHANCE
	if come:
		pl["pending"] = id
		pl["crew"] = FIRST_CREW if not bool(pl["met_first"]) else pick_crew(int(n.get("seed", id)))


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
	var gm := _gm()
	var rv: Dictionary = gm.rivals
	if not rv.has("_plan") or int(plan()["pending"]) < 0 or int(plan()["pending"]) != int(gm.chain_at):
		return
	var p: Player = gm.player
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		return
	var isl = _island(int(gm.chain_at))
	if isl == null:
		return
	var dock: Vector3 = isl.to_global(Vector3(isl.sites["dock_end"].x, 0.0, isl.sites["dock_end"].y))
	var ashore: bool = p.context == Player.Context.ON_FOOT and p.is_on_floor() and not p.is_swimming() \
		and not _aboard(p)
	_ashore = _ashore + dt if ashore else 0.0
	var flat := Vector2(p.global_position.x - dock.x, p.global_position.z - dock.z).length()
	if _ashore < ASHORE_S or flat < INLAND or Cutscene.active or _hostile_near(p):
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
