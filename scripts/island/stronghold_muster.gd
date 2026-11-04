class_name StrongholdMuster
extends Node3D
## A stronghold district's muster point (1.27, docs/v1_27_raids_fruits_plan.md "Muster points"): a tall pole flying the
## Admiralty's banner. F cuts it down and raises the crew's ("sh_muster_<district>", a world flag, so it's every
## captain's); from then a captain who falls on the stronghold while the crew is still up gets back up at the nearest
## raised flag after RESPAWN_SECS (GameManager._respawn_player), not on the ship.

const RESPAWN_SECS := 20.0
## The districts that get one, and where in each (from the district's middle toward the landing side).
const AT := {"ward": Vector2(-30.0, 12.0), "arsenal": Vector2(62.0, 6.0), "prison": Vector2(-62.0, 6.0), "keep": Vector2(-30.0, -56.0)}
const POLE_H := 6.5

static var all: Array = []

var key := ""
var _admiralty: Node3D
var _crew: Node3D
var _use: Interactable
var _raised := false
var _check := 0.0


static func build(isl: Node3D, district: String, y: float) -> StrongholdMuster:
	var m := StrongholdMuster.new()
	m.key = district
	m.name = "Muster_" + district
	var q: Vector2 = AT[district]
	var g := StrongholdPlan.ground(q)
	m.position = isl.call("city_global", q, g if g > -INF else y) - (isl.get("city") as Node3D).global_position
	return m


func flag() -> String:
	return "sh_muster_" + key


func raised() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	return gm != null and gm.world_flags.has(flag())


func _ready() -> void:
	all.append(self)
	var pole := MeshBuilder.new()
	pole.add_cylinder(PSXMat.lit("planks", Color(0.42, 0.34, 0.26)), Transform3D(Basis(), Vector3(0, POLE_H * 0.5, 0)), 0.07, 0.05, POLE_H, 6, 1.0)
	pole.add_cylinder(PSXMat.lit("stone_brick", Color(0.5, 0.54, 0.58)), Transform3D(Basis(), Vector3(0, 0.2, 0)), 0.4, 0.32, 0.4, 8, 1.0)
	pole.add_box(PSXMat.lit("metal", Color(0.7, 0.66, 0.5)), Transform3D(Basis(), Vector3(0, POLE_H + 0.05, 0)), Vector3(0.14, 0.14, 0.14))
	add_child(pole.to_instance("Pole"))
	_admiralty = _banner(Color(0.88, 0.9, 0.95), Color(0.2, 0.32, 0.62), "Admiralty")
	_crew = _banner(Color(0.12, 0.1, 0.1), Color(0.8, 0.18, 0.14), "Crew")
	_use = Interactable.new()
	_use.name = "Use"
	_use.collision_layer = 512
	_use.collision_mask = 0
	_use.prompt_text = "Cut down the Admiralty's flag and raise your own"
	_use.gesture = "lever"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.8
	cs.shape = sph
	_use.add_child(cs)
	_use.position = Vector3(0, 1.2, 0)
	add_child(_use)
	_use.interacted.connect(_on_use)
	_show(raised())


func _exit_tree() -> void:
	all.erase(self)


## A banner on the pole: a field and a band across it (cards both ways so it reads from either side).
func _banner(field: Color, band: Color, nm: String) -> Node3D:
	var b := MeshBuilder.new()
	b.add_box(PSXMat.lit("canvas", field), Transform3D(Basis(), Vector3(0.62, POLE_H - 0.7, 0)), Vector3(1.15, 1.2, 0.03))
	b.add_box(PSXMat.lit("canvas", band), Transform3D(Basis(), Vector3(0.62, POLE_H - 0.7, 0)), Vector3(1.17, 0.28, 0.04))
	var n := b.to_instance("Banner" + nm)
	add_child(n)
	return n


func _on_use(player: Player) -> void:
	if raised():
		return
	Net.world_flag(flag())
	Net.fx("dust_ring", [global_position, 14, 1.0])
	Net.fx("sfx", ["wood_crack", global_position + Vector3.UP * 3.0, -2.0, 0.05])
	Net.fx("sfx", ["cheer", global_position, -6.0, 0.05])
	Net.banner("A flag raised", "%s: your crew musters here now." % key.capitalize())
	_show(true)


func _show(up: bool) -> void:
	_raised = up
	_admiralty.visible = not up
	_crew.visible = up
	_use.enabled = not up


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	if raised() != _raised:
		_show(raised())


## The nearest raised flag within `reach` of `at` (where to stand a fallen captain back up), or Vector3.INF.
static func nearest_raised(at: Vector3, reach: float = 400.0) -> Vector3:
	var best := Vector3.INF
	var bd := reach
	for m in all:
		if is_instance_valid(m) and (m as StrongholdMuster).raised():
			var d := (m as Node3D).global_position.distance_to(at)
			if d < bd:
				bd = d
				best = (m as Node3D).global_position + Vector3(1.5, 0.3, 1.5)
	return best
