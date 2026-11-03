class_name StrongholdBell
extends Node3D
## A stronghold district's alarm bell (1.30, docs/v1_30_plan.md round 3: "cut or guard alarm bells to slow
## reinforcements"). A bronze bell hung in an iron frame, its rope down to a cleat. When a district's garrison spots a
## captain, a marine runs for the nearest bell (StrongholdAlarm, FodderMarine.run_to_bell) and rings the alarm; cut down
## or held off, nobody rings it. F at the frame cuts the rope ("sh_bell_<district>_<i>", a world flag: every captain's):
## a district with every bell cut raises its alarm only when a fight runs long, and its reinforcements come slower.

const BELLS := {
	"landing": [Vector2(-48, 41)],
	"ward": [Vector2(-25, 17), Vector2(25, -12.5)],
	"arsenal": [Vector2(57, -43)],
	"prison": [Vector2(-100, -4)],
	"keep": [Vector2(-18, -51)],
}
const H := 3.4

static var all: Array = []

var district := ""
var index := 0
var _rope: Node3D
var _bell: Node3D
var _use: Interactable
var _cut := false
var _check := 0.0
var _swing := 0.0


static func build(_isl: Node3D, d: String, i: int) -> StrongholdBell:
	var b := StrongholdBell.new()
	b.district = d
	b.index = i
	b.name = "Bell_%s_%d" % [d, i]
	var q: Vector2 = BELLS[d][i]
	b.position = Vector3(q.x, StrongholdPlan.ground(q), q.y)
	return b


func flag() -> String:
	return "sh_bell_%s_%d" % [district, index]


func cut() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	return gm != null and gm.world_flags.has(flag())


## Where a runner stands to ring it (beside the cleat).
func ring_spot() -> Vector3:
	return global_position + global_basis * Vector3(0.0, 0.0, 1.0)


static func of(d: String) -> Array:
	return all.filter(func(b): return is_instance_valid(b) and (b as StrongholdBell).district == d)


static func working(d: String) -> Array:
	return of(d).filter(func(b): return not (b as StrongholdBell).cut())


func _ready() -> void:
	all.append(self)
	var iron := PSXMat.lit("metal", Color(0.3, 0.31, 0.34))
	var bronze := PSXMat.lit("metal", Color(0.72, 0.52, 0.26))
	var frame := MeshBuilder.new()
	for x: float in [-0.9, 0.9]:
		frame.add_box(iron, Transform3D(Basis(), Vector3(x, H * 0.5, 0)), Vector3(0.16, H, 0.16))
	frame.add_box(iron, Transform3D(Basis(), Vector3(0, H, 0)), Vector3(2.1, 0.18, 0.2))
	frame.add_box(PSXMat.lit("stone_brick", Color(0.5, 0.54, 0.58)), Transform3D(Basis(), Vector3(0, 0.12, 0)), Vector3(2.4, 0.24, 0.7))
	frame.add_box(PSXMat.lit("planks_dark"), Transform3D(Basis(), Vector3(0.9, 1.1, 0.12)), Vector3(0.1, 0.3, 0.1))
	var fm := frame.to_instance("Frame")
	fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fm.visibility_range_end = 180.0
	add_child(fm)
	_bell = Node3D.new()
	_bell.position = Vector3(0, H - 0.1, 0)
	add_child(_bell)
	var bm := MeshBuilder.new()
	bm.add_cylinder(bronze, Transform3D(Basis(), Vector3(0, -0.5, 0)), 0.55, 0.28, 0.9, 10, 1.0)
	bm.add_box(bronze, Transform3D(Basis(), Vector3(0, -0.02, 0)), Vector3(0.18, 0.12, 0.18))
	var bi := bm.to_instance("Bronze")
	bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bi.visibility_range_end = 180.0
	_bell.add_child(bi)
	var rm := MeshBuilder.new()
	rm.add_box(PSXMat.lit("canvas", Color(0.7, 0.62, 0.45)), Transform3D(Basis(), Vector3(0.45, -1.0, 0.0)), Vector3(0.05, 2.2, 0.05))
	_rope = rm.to_instance("Rope")
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bell.add_child(_rope)
	_use = Interactable.new()
	_use.name = "Use"
	_use.collision_layer = 512
	_use.collision_mask = 0
	_use.prompt_text = "Cut the bell's rope (no alarm from here)"
	_use.gesture = "lever"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	cs.shape = sph
	_use.add_child(cs)
	_use.position = Vector3(0, 1.2, 0.4)
	add_child(_use)
	_use.interacted.connect(_on_use)
	_show(cut())


func _exit_tree() -> void:
	all.erase(self)


func _on_use(_player: Player) -> void:
	if cut():
		return
	Net.world_flag(flag())
	Net.fx("sfx", ["rope", global_position + Vector3.UP * 2.0, -4.0, 0.05])
	Net.banner("A bell silenced", "%s: one bell fewer to call the alarm." % StrongholdAlarm.title(district))
	_show(true)


func _show(c: bool) -> void:
	_cut = c
	_rope.visible = not c
	_use.enabled = not c


## (every machine) The bell swings as it rings.
func ring() -> void:
	_swing = 2.4


func _process(delta: float) -> void:
	if _swing > 0.0:
		_swing -= delta
		_bell.rotation.x = sin(_swing * 9.0) * 0.45 * minf(_swing, 1.0)
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	if cut() != _cut:
		_show(cut())
