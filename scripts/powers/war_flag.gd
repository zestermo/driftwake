class_name WarFlag
extends Node3D
## Captain's Will's Plant the Flag (WillArts): the captain's flag driven into the ground for SECS; every captain
## within REACH of it mends HEAL_PCT of their health a second. Built on every machine (Net._all_will "flag"); each
## machine mends its own captain. A ring of the captain's Will colour on the ground pulses now and then.

const SECS := 20.0
const REACH := 6.0
const HEAL_PCT := 0.03
const TICK := 0.5
const PULSE := 2.0
const MEND := Color(0.5, 1.0, 0.55)

var _left := SECS
var _tick := 0.0
var _pulse := 0.0
var _col := Color.WHITE


static func plant(at: Vector3, col: Color) -> WarFlag:
	var tree := Engine.get_main_loop() as SceneTree
	var f := WarFlag.new()
	f.name = "WarFlag"
	f._col = col
	tree.current_scene.add_child(f)
	f.global_position = at
	return f


func _ready() -> void:
	var pole := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.08, 2.6, 0.08)
	pole.mesh = pm
	pole.material_override = PSXMat.lit("planks_dark")
	pole.position = Vector3(0, 1.3, 0)
	var cloth := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.95, 0.6, 0.02)
	cloth.mesh = cm
	cloth.material_override = PSXMat.flat(Color(0.08, 0.06, 0.07))
	cloth.position = Vector3(0.5, 2.25, 0)
	var mark := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.26, 0.26, 0.03)
	mark.mesh = mm
	mark.material_override = PSXMat.flat(Color(0.92, 0.9, 0.84))
	mark.position = Vector3(0.5, 2.25, 0)
	for m in [pole, cloth, mark]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visibility_range_end = 70.0
		add_child(m)
	FX.dust_ring(global_position, 14, 0.8)
	FX.ring(global_position + Vector3(0, 0.1, 0), Vector3.UP, REACH, _col, 0.5, 0.12)


func _physics_process(delta: float) -> void:
	_left -= delta
	_tick -= delta
	_pulse -= delta
	if _pulse <= 0.0:
		_pulse = PULSE
		FX.ring(global_position + Vector3(0, 0.1, 0), Vector3.UP, REACH, Color(_col, 0.7), 0.6, 0.06)
	if _tick <= 0.0:
		_tick = TICK
		var me := get_tree().get_first_node_in_group("player") as Player
		if me and me.is_local and me.global_position.distance_to(global_position) <= REACH and me.health_component.current_health > 0.0:
			var hc := me.health_component
			if hc.current_health < hc.max_health:
				hc.heal(hc.max_health * HEAL_PCT * TICK)
				FX.sparkle(me.global_position + Vector3(0, 1.0, 0), 2, MEND)
	if _left <= 0.0:
		FX.dust(global_position, 6, 0.6)
		queue_free()
