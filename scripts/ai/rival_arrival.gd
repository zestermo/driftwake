class_name RivalArrival
extends Node
## (1.30, docs/v1_30_plan.md "Rival crews") A rival crew comes to the island you're on, seen, run by the host
## (RivalWatch starts it): their ship sails in from the horizon and anchors off the harbour (RivalShip, on every
## screen), they row ashore, and then the meeting (RivalEncounter) from the dock. When it's over she sails away.

signal met(e: RivalEncounter)

## After she anchors, this long rowing ashore before they're on the pier.
const ROW_S := 4.0
## She weighs anchor this long after the visit ends (the crew back aboard).
const SAIL_OFF_S := 4.0
const CHECK_EVERY := 0.25

var crew_id := ""
var dock := Vector3.ZERO
## sail (she's on her way in), row (anchored, the crew coming ashore), meet (the encounter's on), done
var phase := "sail"
## The captain they come for (a Callable -> Player or null: on foot, ashore, not in a fight), asked each check.
var pick: Callable
var encounter: RivalEncounter
## What their captain called out on anchoring.
var callout := ""
var _t := 0.0
var _row := 0.0


## Host: crew `crew` comes in to the dock at `dock` (its sea along `out`); null if one's already coming or here.
static func start(tree: SceneTree, crew: String, at_dock: Vector3, out: Vector3, picker: Callable) -> RivalArrival:
	if tree.get_first_node_in_group("rival_arrival") or tree.get_first_node_in_group("rival_encounter"):
		return null
	var a := RivalArrival.new()
	a.name = "RivalArrival"
	a.crew_id = crew
	a.dock = at_dock
	a.pick = picker
	tree.current_scene.add_child(a)
	a._sail_in(out)
	return a


func _sail_in(out: Vector3) -> void:
	var l := RivalShip.lane(dock, out)
	Net.everyone("_all_rival_ship", [crew_id, l[0], l[1], l[2], Ocean.clock()])
	var c: Dictionary = RivalCrews.crew(crew_id)
	Net.banner("A sail on the horizon", "Flying the colours of %s, making for the harbour." % str(c["name"]), false)


static func of(tree: SceneTree) -> RivalArrival:
	return tree.get_first_node_in_group("rival_arrival") as RivalArrival


func _ready() -> void:
	add_to_group("rival_arrival")


## Host: called off (the captains sailed on): she turns and goes.
func cancel() -> void:
	if phase != "meet":
		_sail_off()


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < CHECK_EVERY:
		return
	var dt := _t
	_t = 0.0
	match phase:
		"sail":
			var s := RivalShip.of(get_tree())
			if s == null:
				_sail_off()
			elif s.anchored() and not Cutscene.active:
				var p = pick.call()
				if p == null:
					return
				_announce(p)
				phase = "row"
				_row = 0.0
		"row":
			_row += dt
			if _row < ROW_S or Cutscene.active:
				return
			var p = pick.call()
			if p == null:
				return
			var e := RivalEncounter.start(p, crew_id, dock)
			if e == null:
				return
			phase = "meet"
			encounter = e
			e.ended.connect(func(_r): _sail_off())
			# (their captain, up on the pier, calls again: the one they came for, by name)
			e._say(e.rivals[-1], RivalCrews.line(crew_id, "callout", e.rng).replace("{name}", (p as Player).display_name()))
			met.emit(e)


## Their ship's anchored: the named banner, the music's call and their captain calling `p` out by name, everywhere; the
## crew's arrival in the log.
func _announce(p: Player) -> void:
	var c: Dictionary = RivalCrews.crew(crew_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([crew_id, int(GameManager.chain_seed), int(GameManager.rivals.get(crew_id, {}).get("met", 0))])
	callout = RivalCrews.line(crew_id, "callout", rng).replace("{name}", p.display_name())
	Net.everyone("_all_rival_arrive", [crew_id, callout])
	Journal.announce("rival", "%s dropped anchor" % str(c["name"]).capitalize(),
		"Captain %s, %s, called %s out." % [c["captain"], c["title"], p.display_name()], true)


func _sail_off() -> void:
	if phase == "done":
		return
	phase = "done"
	Net.everyone("_all_rival_ship_leave", [Ocean.clock() + SAIL_OFF_S])
	queue_free()
