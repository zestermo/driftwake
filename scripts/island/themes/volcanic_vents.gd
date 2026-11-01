extends Node3D
## A vent field's bursts (VolcanicPlaces): every PERIOD s of the shared clock (Ocean.clock(), so every screen agrees
## without a message) one vent, picked from the field's seed and the slot, hisses with a red ring on its ground for
## TELL s, then bursts in steam and embers; the local captain standing in it is burned and thrown. Each screen draws
## its own (the same) and burns only its own captain. Asleep while the captain's far.

const PERIOD := 3.2
const TELL := 1.3
const R := 1.8
const DAMAGE := 18.0
const EAR := 60.0

var isl
var spots: Array = []
var seed_value := 0
var _slot := -1
var _burst := false


func _physics_process(_delta: float) -> void:
	if spots.is_empty():
		return
	var t: float = Ocean.clock()
	var slot := int(floor(t / PERIOD))
	var into := t - slot * PERIOD
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or p.global_position.distance_to(global_position) > EAR:
		_slot = slot
		return
	var q: Vector2 = spots[posmod(hash([seed_value, slot]), spots.size())]
	var at: Vector3 = isl.to_global(Vector3(q.x, isl.hv(q), q.y))
	if slot != _slot:
		_slot = slot
		_burst = false
		FX.telegraph(at, R, TELL, Color(1.0, 0.55, 0.15))
	if not _burst and into >= TELL:
		_burst = true
		FX.sfx("fire_burst", at, -6.0, 0.15, 0.8)
		FX.embers(at + Vector3.UP * 0.3, Vector3.UP, 16, Color(1.0, 0.5, 0.15), 7.0)
		FX.dust(at + Vector3.UP * 0.5, 8, 1.2)
		if p.is_local and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < R and p.global_position.y < at.y + 2.0:
			p.health_component.take_damage(DAMAGE)
			var out := Vector3(p.global_position.x - at.x, 0, p.global_position.z - at.z)
			p.velocity = (out.normalized() if out.length() > 0.1 else Vector3.FORWARD) * 6.0 + Vector3.UP * 10.0
